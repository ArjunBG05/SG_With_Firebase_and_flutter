import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/health_card.dart';
import 'help_screen.dart';
import 'login_screen.dart';
import 'patient_location_screen.dart';

/// Vitals for a single patient.
class _PatientVitals {
  final String heartRate;
  final String spo2;
  final String temperature;
  final String deviceStatus;
  final bool hasActiveAlert;

  const _PatientVitals({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.deviceStatus,
    this.hasActiveAlert = false,
  });
}

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  // Readings arrive every ~5 s; older than this = stale.
  static const int _staleAfterSeconds = 20;

  // TODO: replace the demo entries with real linked patients later.
  static const Map<String, _PatientVitals> _demoVitals = {
    'Uncle Rohan': _PatientVitals(
      heartRate: '91 BPM',
      spo2: '95%',
      temperature: '37.4°C',
      deviceStatus: 'Connected',
      hasActiveAlert: true,
    ),
  };

  // Name of the real (live) patient, loaded from Firestore.
  String _livePatient = 'Loading...';
  late String _selectedPatient = _livePatient;
  List<String> get _patients => [_livePatient, ..._demoVitals.keys];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _ticker;

  String? _setupError; // problem finding/reading the linked patient
  String? _patientUid; // the linked patient's UID, used by the map screen
  bool _streamLoaded = false;
  DateTime? _lastTime;
  num? _bpm;
  num? _spo2;
  num? _temp;

  @override
  void initState() {
    super.initState();
    _loadLinkedPatient();
    // Re-check data age every second so "stale" appears on its own.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadLinkedPatient() async {
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) throw 'Not logged in';

      final db = FirebaseFirestore.instance;
      final me = await db.collection('users').doc(myUid).get();
      final patientUid = me.data()?['linkedPatientId'] as String?;
      if (patientUid == null || patientUid.isEmpty) {
        if (!mounted) return;
        setState(() {
          _livePatient = 'No patient linked';
          _selectedPatient = _livePatient;
          _setupError = 'No patient is linked to this guardian account yet.';
        });
        return;
      }

      _patientUid = patientUid;

      final p = await db.collection('users').doc(patientUid).get();
      final name = (p.data()?['name'] as String?) ?? 'Patient';

      if (!mounted) return;
      setState(() {
        final wasLive = _selectedPatient == _livePatient;
        _livePatient = name;
        if (wasLive) _selectedPatient = name;
      });

      _sub = db
          .collection('sensor_data')
          .where('patientId', isEqualTo: patientUid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(_onSnapshot, onError: _onError);
    } catch (e) {
      debugPrint('Guardian load failed: $e');
      if (!mounted) return;
      setState(() {
        _livePatient = 'Patient';
        _selectedPatient = _livePatient;
        _setupError = 'Could not load the patient. Check the debug console.';
      });
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _streamLoaded = true;
      _setupError = null;
      if (snap.docs.isEmpty) {
        _lastTime = null;
        _bpm = _spo2 = _temp = null;
        return;
      }
      final d = snap.docs.first.data();
      _lastTime = (d['timestamp'] as Timestamp?)?.toDate();
      _bpm = d['heartRate'] as num?;
      _spo2 = d['spo2'] as num?;
      _temp = d['temperature'] as num?;
    });
  }

  void _onError(Object e) {
    debugPrint('Guardian Firestore stream error: $e');
    if (!mounted) return;
    setState(() => _setupError = 'Could not load readings. Check the debug console.');
  }

  bool _isLive(String name) => name == _livePatient;

  int? get _ageSeconds => _lastTime == null
      ? null
      : DateTime.now().difference(_lastTime!).inSeconds;

  bool get _fresh =>
      _setupError == null &&
      _ageSeconds != null &&
      _ageSeconds! <= _staleAfterSeconds;

  /// Vitals for a patient. The live patient is built from Firestore data.
  /// No alert is raised from prototype sensor values.
  _PatientVitals _vitalsFor(String name) {
    if (!_isLive(name)) return _demoVitals[name]!;

    final bpm = _fresh ? _bpm : null;
    final spo2 = _fresh ? _spo2 : null;
    final temp = _fresh ? _temp : null;

    final String status;
    if (_setupError != null) {
      status = 'Error';
    } else if (!_streamLoaded) {
      status = 'Loading...';
    } else if (_lastTime == null) {
      status = 'No data';
    } else {
      status = _fresh ? 'Connected' : 'Stale';
    }

    return _PatientVitals(
      heartRate: bpm == null ? '-- BPM' : '${bpm.round()} BPM',
      spo2: spo2 == null ? '-- %' : '${spo2.round()}%',
      temperature: temp == null ? '--' : '${temp.toStringAsFixed(1)}°C',
      deviceStatus: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vitals = _vitalsFor(_selectedPatient);
    final live = _isLive(_selectedPatient);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch patient',
            onPressed: () => _showSwitchPatientSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _showSwitchPatientSheet(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monitoring: $_selectedPatient',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.unfold_more, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildStatusBanner(vitals, live),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Patient vitals',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  live ? 'Live data' : 'Demo data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: live ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                HealthCard(
                  label: live ? 'Heart Rate (prototype)' : 'Heart Rate',
                  value: vitals.heartRate,
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
                HealthCard(
                  label: live ? 'SpO₂ (prototype)' : 'SpO₂',
                  value: vitals.spo2,
                  icon: Icons.air,
                  color: Colors.blue,
                ),
                HealthCard(
                  label: 'Temperature',
                  value: vitals.temperature,
                  icon: Icons.thermostat,
                  color: Colors.orange,
                ),
                HealthCard(
                  label: 'Device',
                  value: vitals.deviceStatus,
                  icon: Icons.watch,
                  color: vitals.deviceStatus == 'Connected'
                      ? Colors.green
                      : Colors.grey,
                ),
              ],
            ),

            if (live) ...[
              const SizedBox(height: 8),
              Text(
                'Heart rate and SpO₂ are prototype readings and are not '
                'medically validated.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 28),

            Text('Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final uid = _patientUid;
                if (!live || uid == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Location is only available for the live patient.'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientLocationScreen(
                      patientUid: uid,
                      patientName: _selectedPatient,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.location_on_outlined),
              label: Text('View $_selectedPatient\'s Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: open a history/chart screen
              },
              icon: const Icon(Icons.history),
              label: Text('View $_selectedPatient\'s History'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: launch a call with url_launcher
              },
              icon: const Icon(Icons.phone_outlined),
              label: Text('Call $_selectedPatient'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(_PatientVitals vitals, bool live) {
    final bool offline = live && !_fresh;

    final Color color;
    final IconData icon;
    final String message;

    if (offline) {
      color = Colors.grey;
      icon = Icons.sensors_off;
      message = _setupError ??
          (_lastTime == null
              ? 'No readings from $_selectedPatient\'s device yet.'
              : 'No live data from $_selectedPatient\'s device right now.');
    } else if (vitals.hasActiveAlert) {
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
      message =
          '$_selectedPatient has an abnormal reading — check vitals below.';
    } else {
      color = Colors.green;
      icon = Icons.check_circle;
      message = live
          ? 'Receiving live readings from $_selectedPatient\'s device.'
          : '$_selectedPatient is stable. No active emergencies.';
    }

    return Card(
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSwitchPatientSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Switch patient',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ..._patients.map((name) {
                final isSelected = name == _selectedPatient;
                final hasAlert = _vitalsFor(name).hasActiveAlert;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(name),
                  subtitle: Text(_isLive(name) ? 'Live device' : 'Demo data'),
                  trailing: hasAlert
                      ? const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedPatient = name);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
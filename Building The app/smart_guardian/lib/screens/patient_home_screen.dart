import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/health_card.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  // Readings arrive every ~5 s; treat anything older than this as stale.
  static const int _staleAfterSeconds = 20;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _ticker;

  bool _loaded = false; // first snapshot received
  String? _error;
  DateTime? _lastTime;
  num? _bpm;
  num? _spo2;
  num? _temp;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _error = 'Not logged in';
    } else {
      _sub = FirebaseFirestore.instance
          .collection('sensor_data')
          .where('patientId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(_onSnapshot, onError: _onError);
    }

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

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _error = null;
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
    // If this is a missing-index error, the debug console shows a link.
    debugPrint('Firestore stream error: $e');
    if (!mounted) return;
    setState(() => _error = e.toString());
  }

  int? get _ageSeconds => _lastTime == null
      ? null
      : DateTime.now().difference(_lastTime!).inSeconds;

  bool get _live =>
      _error == null &&
      _ageSeconds != null &&
      _ageSeconds! <= _staleAfterSeconds;

  String get _statusText {
    if (_error != null) return 'Error';
    if (!_loaded) return 'Loading...';
    if (_lastTime == null) return 'No data';
    return _live ? 'Connected' : 'Stale';
  }

  String get _updatedText {
    if (_error != null) return 'Could not load readings. Check the debug console.';
    if (!_loaded) return 'Waiting for data...';
    final age = _ageSeconds;
    if (age == null) return 'No readings received yet.';
    final String ago;
    if (age < 60) {
      ago = '${age < 0 ? 0 : age} s ago';
    } else if (age < 3600) {
      ago = '${age ~/ 60} min ago';
    } else {
      ago = '${age ~/ 3600} h ago';
    }
    final t = _lastTime!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return _live
        ? 'Last updated: $hh:$mm:$ss ($ago)'
        : 'Data is old. Last reading: $hh:$mm:$ss ($ago)';
  }

  @override
  Widget build(BuildContext context) {
    // Don't show old values as if they were current.
    final bpm = _live ? _bpm : null;
    final spo2 = _live ? _spo2 : null;
    final temp = _live ? _temp : null;
    final noFinger = _live && (_bpm == null || _spo2 == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HelpScreen(),
              ),
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
            Text(
              'Your vitals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _updatedText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _live ? null : Colors.orange.shade800,
                  ),
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
                  label: 'Heart Rate (prototype)',
                  value: bpm == null ? '-- BPM' : '${bpm.round()} BPM',
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
                HealthCard(
                  label: 'SpO₂ (prototype)',
                  value: spo2 == null ? '-- %' : '${spo2.round()}%',
                  icon: Icons.air,
                  color: Colors.blue,
                ),
                HealthCard(
                  label: 'Temperature',
                  value: temp == null
                      ? '--'
                      : '${temp.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat,
                  color: Colors.orange,
                ),
                HealthCard(
                  label: 'Device',
                  value: _statusText,
                  icon: Icons.watch,
                  color: _live ? Colors.green : Colors.grey,
                ),
              ],
            ),

            if (noFinger) ...[
              const SizedBox(height: 8),
              Text(
                'No finger detected: place a finger on the sensor to get '
                'heart rate and SpO₂.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Heart rate and SpO₂ are prototype readings and are not '
              'medically validated.',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 28),

            Text(
              'Emergency',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () => _confirmSOS(context),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('SOS — I need help'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                // TODO: Add url_launcher to call the doctor.
              },
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('Call Family Doctor'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send SOS?'),
        content: const Text(
          'This will alert your guardians and share '
          'your current location immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);

              // TODO: Call your backend's POST /emergency endpoint.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS sent to your guardians'),
                ),
              );
            },
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to log in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AuthProvider>().logout();

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
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
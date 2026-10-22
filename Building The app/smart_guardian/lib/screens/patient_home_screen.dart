import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/health_card.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  Timer? _timer;
  SensorReadings? _readings;
  bool _connected = false;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetch(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;

    try {
      final r = await ApiService.fetchReadings();

      // Debug only: remove once testing is finished.
      debugPrint(
        'readings: age=${r.ageSeconds} '
        'bpm=${r.bpm} spo2=${r.spo2} '
        'temp=${r.temperatureC}',
      );

      if (!mounted) return;

      setState(() {
        _readings = r;
        _connected = r.ageSeconds != null && r.ageSeconds! < 5;
      });
    } catch (e) {
      debugPrint('fetchReadings failed: $e');

      if (!mounted) return;

      setState(() => _connected = false);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the device is disconnected, don't show stale values.
    final bpm = _connected ? _readings?.bpm : null;
    final spo2 = _connected ? _readings?.spo2 : null;
    final temp = _connected ? _readings?.temperatureC : null;

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
                  value: _connected ? 'Connected' : 'Disconnected',
                  icon: Icons.watch,
                  color: _connected ? Colors.green : Colors.grey,
                ),
              ],
            ),

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
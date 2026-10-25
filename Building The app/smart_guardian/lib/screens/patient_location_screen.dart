import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PatientLocationScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const PatientLocationScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<PatientLocationScreen> createState() => _PatientLocationScreenState();
}

class _PatientLocationScreenState extends State<PatientLocationScreen> {
  // A fix older than this is shown as "last known", not live.
  static const int _liveWithinSeconds = 60;

  final MapController _map = MapController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _ticker;

  bool _mapReady = false;
  bool _loaded = false;
  String? _error;
  LatLng? _pos;
  DateTime? _fixTime;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('sensor_data')
        .where('patientId', isEqualTo: widget.patientUid)
        .orderBy('timestamp', descending: true)
        .limit(60)
        .snapshots()
        .listen(_onSnapshot, onError: (e) {
      debugPrint('Location stream error: $e');
      if (mounted) setState(() => _error = 'Could not load the location.');
    });
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
    LatLng? found;
    DateTime? time;
    // Newest first: take the first reading that has a valid fix.
    for (final doc in snap.docs) {
      final d = doc.data();
      final lat = d['latitude'];
      final lng = d['longitude'];
      if (lat is num && lng is num) {
        final la = lat.toDouble();
        final lo = lng.toDouble();
        final valid = la.abs() <= 90 && lo.abs() <= 180 && !(la == 0 && lo == 0);
        if (valid) {
          found = LatLng(la, lo);
          time = (d['timestamp'] as Timestamp?)?.toDate();
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _error = null;
      _pos = found;
      _fixTime = time;
    });
    if (found != null && _mapReady) {
      _map.move(found, _map.camera.zoom);
    }
  }

  String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return '${s < 0 ? 0 : s} s ago';
    if (s < 3600) return '${s ~/ 60} min ago';
    if (s < 86400) return '${s ~/ 3600} h ago';
    return '${s ~/ 86400} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.patientName}\'s location')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center),
      ));
    }
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final pos = _pos;
    if (pos == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No GPS fix received yet.\n\nThe patient\'s device needs a clear '
          'view of the sky to find its location.',
          textAlign: TextAlign.center,
        ),
      ));
    }

    final t = _fixTime;
    final age = t == null ? null : DateTime.now().difference(t).inSeconds;
    final live = age != null && age <= _liveWithinSeconds;

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: pos,
              initialZoom: 16,
              onMapReady: () => _mapReady = true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_guardian',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pos,
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.location_pin,
                      size: 48,
                      color: live ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                live ? 'Live location' : 'Last known location (not live)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: live ? Colors.green : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pos.latitude.toStringAsFixed(5)}, '
                '${pos.longitude.toStringAsFixed(5)}'
                '${t == null ? '' : '   •   ${_ago(t)}'}',
              ),
              const SizedBox(height: 4),
              Text(
                'GPS accuracy is typically a few metres and can be worse '
                'near buildings.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
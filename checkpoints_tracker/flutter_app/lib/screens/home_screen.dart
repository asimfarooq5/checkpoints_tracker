import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/checkpoint.dart';
import '../providers/auth_provider.dart';
import '../providers/checkpoint_provider.dart';
import '../services/foreground_service.dart';
import '../widgets/checkpoint_card.dart';

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationOn = true;
  StreamSubscription<ServiceStatus>? _locSub;
  Timer? _speedTimer;

  double _speed = 0; // m/s
  double _nearestDist = 0; // meters
  String _nearestLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cp = context.read<CheckpointProvider>();
      await cp.loadCheckpoints();

      final running = await isServiceRunning();
      if (!running) await initForegroundService();
    });

    _checkLocation();
    _locSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      setState(() => _locationOn = status == ServiceStatus.enabled);
      if (status == ServiceStatus.disabled) _showLocationOffDialog();
    });

    _speedTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateSpeed());
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _speedTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocation() async {
    final on = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationOn = on);
  }

  Future<void> _updateSpeed() async {
    if (!_locationOn) return;
    final cp = context.read<CheckpointProvider>();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );
      final speed = pos.speed;
      final pending = cp.pendingCheckpoints;
      Checkpoint? nearest;
      double minDist = double.infinity;

      for (final c in pending) {
        final d = _haversine(pos.latitude, pos.longitude, c.latitude, c.longitude);
        if (d < minDist) { minDist = d; nearest = c; }
      }

      if (!mounted) return;
      setState(() {
        _speed = speed;
        _nearestDist = minDist;
        _nearestLabel = nearest?.label ?? '';
      });
    } catch (_) {}
  }

  Future<void> _showLocationOffDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text('Location services are turned off. Please enable location in Settings.'),
        actions: [
          TextButton(onPressed: () => Geolocator.openLocationSettings(), child: const Text('Open Settings')),
        ],
      ),
    );
  }

  Future<void> _refresh() async => context.read<CheckpointProvider>().loadCheckpoints();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cp = context.watch<CheckpointProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Checkpoints'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(auth.user?.displayName ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70))),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await auth.logout();
            if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
          }),
        ],
      ),
      body: Column(
        children: [
          if (!_locationOn)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.red[50],
              leading: const Icon(Icons.location_off, color: Colors.red),
              content: const Text('Location is OFF. Tracking paused.', style: TextStyle(color: Colors.red)),
              actions: [
                TextButton(onPressed: () => Geolocator.openLocationSettings(), child: const Text('Enable')),
              ],
            ),

          // Speed & ETA dashboard
          if (_locationOn && cp.pendingCheckpoints.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.03),
              child: Row(
                children: [
                  _infoTile(Icons.speed, (_speed * 3.6).toStringAsFixed(0), 'km/h'),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  const SizedBox(width: 12),
                  _infoTile(Icons.location_on, _nearestDist < 1000 ? '${_nearestDist.toStringAsFixed(0)}m' : '${(_nearestDist / 1000).toStringAsFixed(1)}km', _nearestLabel.isNotEmpty ? _nearestLabel : 'nearest'),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  const SizedBox(width: 12),
                  _infoTile(
                    Icons.timer,
                    _speed > 0.5 ? '${(_nearestDist / _speed).toStringAsFixed(0)}s' : '—',
                    'ETA',
                  ),
                ],
              ),
            ),

          Expanded(
            child: cp.isLoading && cp.checkpoints.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : cp.error != null && cp.checkpoints.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(cp.error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  _statBadge('Total', cp.checkpoints.length, Colors.blue),
                                  const SizedBox(width: 8),
                                  _statBadge('Pending', cp.pendingCheckpoints.length, Colors.orange),
                                  const SizedBox(width: 8),
                                  _statBadge('Completed', cp.completedCheckpoints.length, Colors.green),
                                ],
                              ),
                            ),
                            Expanded(
                              child: cp.checkpoints.isEmpty
                                  ? const Center(child: Text('No checkpoints assigned yet.', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: cp.checkpoints.length,
                                      itemBuilder: (_, i) => CheckpointCard(
                                        checkpoint: cp.checkpoints[i],
                                        onTap: () => Navigator.of(context).pushNamed('/checkpoint-detail', arguments: cp.checkpoints[i]),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/checkpoint_provider.dart';
import '../services/foreground_service.dart';
import '../widgets/checkpoint_card.dart';
import '../widgets/tracking_status_panel.dart';

double _distance(double lat1, double lon1, double lat2, double lon2) {
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
  int? _selectedId;
  double _speed = 0;
  double _userLat = 0;
  double _userLng = 0;
  bool _hasPosition = false;
  StreamSubscription<ServiceStatus>? _locSub;
  Timer? _posTimer;

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
    _posTimer = Timer.periodic(const Duration(seconds: 5), _updatePosition);
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _posTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocation() async {
    final on = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationOn = on);
  }

  Future<void> _updatePosition(Timer t) async {
    if (!_locationOn) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );
      if (!mounted) return;
      setState(() { _speed = pos.speed; _userLat = pos.latitude; _userLng = pos.longitude; _hasPosition = true; });
    } catch (_) {}
  }

  double? _getDist(double lat, double lng) =>
      _hasPosition ? _distance(_userLat, _userLng, lat, lng) : null;

  Future<void> _showLocationOffDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text('Please enable location in Settings.'),
        actions: [TextButton(onPressed: () => Geolocator.openLocationSettings(), child: const Text('Open Settings'))],
      ),
    );
  }

  Future<void> _refresh() async => context.read<CheckpointProvider>().loadCheckpoints();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cp = context.watch<CheckpointProvider>();
    final pending = cp.pendingCheckpoints;

    // Target info for speed bar
    final target = pending.where((c) => c.id == _selectedId).firstOrNull;
    final targetDist = target != null && _hasPosition ? _getDist(target.latitude, target.longitude)! : 0.0;

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
          TrackingStatusPanel(alarmEnabled: auth.user?.alarmEnabled ?? false),
          if (!_locationOn)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.red[50],
              leading: const Icon(Icons.location_off, color: Colors.red),
              content: const Text('Location is OFF. Tracking paused.', style: TextStyle(color: Colors.red)),
              actions: [TextButton(onPressed: () => Geolocator.openLocationSettings(), child: const Text('Enable'))],
            ),
          if (_locationOn && _hasPosition)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.03),
              child: Row(
                children: [
                  _infoTile(Icons.speed, (_speed * 3.6).toStringAsFixed(0), 'km/h'),
                  Container(width: 1, height: 36, color: Colors.grey[300]),
                  const SizedBox(width: 12),
                  _infoTile(Icons.flag, target != null
                      ? (targetDist < 1000 ? '${targetDist.toStringAsFixed(0)}m' : '${(targetDist / 1000).toStringAsFixed(1)}km')
                      : '—', target != null ? target.label : 'no target'),
                  Container(width: 1, height: 36, color: Colors.grey[300]),
                  const SizedBox(width: 12),
                  _infoTile(Icons.timer, _speed > 0.5 && target != null ? '${(targetDist / _speed).toStringAsFixed(0)}s' : '—', 'ETA'),
                ],
              ),
            ),
          if (_selectedId != null && target == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Target completed!', style: TextStyle(fontSize: 13, color: Colors.green[700]))),
                  TextButton(onPressed: () => setState(() => _selectedId = null), child: const Text('Clear')),
                ],
              ),
            ),
          Expanded(
            child: cp.isLoading && cp.checkpoints.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : cp.checkpoints.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No checkpoints assigned yet.', style: TextStyle(color: Colors.grey))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          itemCount: cp.checkpoints.length,
                          itemBuilder: (_, i) {
                            final c = cp.checkpoints[i];
                            return CheckpointCard(
                              checkpoint: c,
                              distance: _getDist(c.latitude, c.longitude),
                              isSelected: _selectedId == c.id,
                              onTap: () {
                                if (c.isCompleted) return;
                                setState(() => _selectedId = _selectedId == c.id ? null : c.id);
                              },
                            );
                          },
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
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

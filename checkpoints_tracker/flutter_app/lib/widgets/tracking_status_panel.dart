import 'dart:async';
import 'package:flutter/material.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import '../services/foreground_service.dart';
import '../services/offline_queue.dart';

class TrackingStatusPanel extends StatefulWidget {
  final bool alarmEnabled;

  const TrackingStatusPanel({super.key, required this.alarmEnabled});

  @override
  State<TrackingStatusPanel> createState() => _TrackingStatusPanelState();
}

class _TrackingStatusPanelState extends State<TrackingStatusPanel> {
  bool _serviceRunning = false;
  DateTime? _lastSyncAt;
  int _queueCount = 0;
  bool _batteryOptDisabled = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final running = await isServiceRunning();
    final lastSync = await getLastSyncAt();
    final queueCount = await OfflineQueue.count();
    bool batteryOk = true;
    try {
      batteryOk = await DisableBatteryOptimization.isAllBatteryOptimizationDisabled ?? true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _serviceRunning = running;
      _lastSyncAt = lastSync;
      _queueCount = queueCount;
      _batteryOptDisabled = batteryOk;
    });
  }

  String _relativeSync() {
    final t = _lastSyncAt;
    if (t == null) return 'never';
    final age = DateTime.now().difference(t);
    if (age.inSeconds < 60) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    return '${age.inHours}h ago';
  }

  Future<void> _fixBatteryOptimization() async {
    try {
      await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
        'Allow Auto-Start',
        'This lets Checkpoints Tracker restart itself if the system kills it in the background.',
        'Disable Battery Optimization',
        'This stops the phone from freezing location tracking to save battery.',
      );
    } catch (_) {}
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                _serviceRunning ? Icons.check_circle : Icons.error,
                _serviceRunning ? 'Service running' : 'Service stopped',
                _serviceRunning ? Colors.green : Colors.red,
              ),
              _chip(Icons.sync, 'Last sync: ${_relativeSync()}', Colors.blueGrey),
              if (_queueCount > 0) _chip(Icons.cloud_off, '$_queueCount queued offline', Colors.orange),
              _chip(
                widget.alarmEnabled ? Icons.notifications_active : Icons.notifications_off,
                widget.alarmEnabled ? 'Alarm on' : 'Alarm off',
                widget.alarmEnabled ? Colors.deepPurple : Colors.grey,
              ),
            ],
          ),
          if (!_batteryOptDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: _fixBatteryOptimization,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange[800]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Background restrictions may stop tracking. Tap to fix.',
                        style: TextStyle(fontSize: 11, color: Colors.orange[800], decoration: TextDecoration.underline),
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

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

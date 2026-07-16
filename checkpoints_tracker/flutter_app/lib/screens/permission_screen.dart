import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import '../services/foreground_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _locationGranted = false;
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _notificationsGranted = false;
  bool _batteryOptGranted = false;
  StreamSubscription<ServiceStatus>? _locSub;

  @override
  void initState() {
    super.initState();
    _checkAll();
    _locSub = Geolocator.getServiceStatusStream().listen((_) {
      if (mounted) _onReturnFromSettings();
    });
  }

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAll() async {
    final loc = await Geolocator.checkPermission();
    final notif = await Permission.notification.status;
    final batteryOpt = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    final notificationsGranted = notif.isGranted;
    setState(() {
      _locationPermission = loc;
      _locationGranted = loc == LocationPermission.always || loc == LocationPermission.whileInUse;
      _notificationsGranted = notificationsGranted;
      _batteryOptGranted = batteryOpt.isGranted;
    });
    // Background tracking needs "Always" specifically, not just "While in use".
    if (loc == LocationPermission.always && notificationsGranted) {
      await _startAndGo();
    }
  }

  Future<void> _onReturnFromSettings() async {
    await _checkAll();
    if (!mounted) return;
    final loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.always && _notificationsGranted) {
      await _startAndGo();
    }
  }

  Future<void> _startAndGo() async {
    await initForegroundService();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _requestAll() async {
    var loc = await Geolocator.requestPermission();

    // If user picked whileInUse, guide to Settings
    if (loc == LocationPermission.whileInUse) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Always-On Location Required'),
          content: const Text(
            'For background tracking to work, you must select\n'
            '"Allow all the time" in location permissions.\n\n'
            'Tap "Go to Settings" and change Location to "All the time".\n'
            'Then come back here and tap "I granted it".',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
      // Check after returning from settings
      loc = await Geolocator.checkPermission();
    }

    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();

    // Many OEMs (Xiaomi, Huawei, Oppo, Vivo, Samsung) kill background services
    // via their own "autostart"/"protected apps" lists, separate from stock
    // Android's battery optimization API. Prompt for those too, best-effort.
    try {
      await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
        'Allow Auto-Start',
        'This lets Checkpoints Tracker restart itself if the system kills it in the background.',
        'Disable Battery Optimization',
        'This stops the phone from freezing location tracking to save battery.',
      );
    } catch (_) {}

    await _checkAll();

    // If all granted now, proceed
    final locNow = await Geolocator.checkPermission();
    final notifNow = await Permission.notification.status;
    if (locNow == LocationPermission.always && notifNow.isGranted) {
      await _startAndGo();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locationPermission == LocationPermission.always && _notificationsGranted) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text('Starting service...', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 56, color: Color(0xFF2563EB)),
                  const SizedBox(height: 16),
                  const Text('Always-On Tracking Required',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Checkpoints Tracker runs continuously in the background. '
                      'These permissions ensure it never stops:',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),
                  _row(Icons.location_on, 'Location (Always)', 'Track position even when app is closed', _locationGranted),
                  const SizedBox(height: 10),
                  _row(Icons.notifications, 'Persistent Notification', 'Keeps service alive — cannot be dismissed', _notificationsGranted),
                  const SizedBox(height: 10),
                  _row(Icons.battery_full, 'Battery Optimization Off', 'Prevents Android from killing app', _batteryOptGranted),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _requestAll,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      child: const Text('Grant & Start Tracking'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String title, String subtitle, bool granted) {
    return Row(
      children: [
        Icon(icon, size: 28, color: granted ? Colors.green : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Icon(granted ? Icons.check_circle : Icons.cancel, color: granted ? Colors.green : Colors.red, size: 22),
      ],
    );
  }
}

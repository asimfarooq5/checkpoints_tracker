import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/foreground_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    final loc = await Geolocator.checkPermission();
    final notif = await Permission.notification.status;

    if (!mounted) return;
    setState(() {
      _locationGranted = loc == LocationPermission.always || loc == LocationPermission.whileInUse;
      _notificationsGranted = notif.isGranted;
      _checking = false;
    });

    if (_allGranted) {
      await _startAndGo();
    }
  }

  bool get _allGranted => _locationGranted && _notificationsGranted;

  Future<void> _startAndGo() async {
    await initForegroundService();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _requestAll() async {
    // Request location — first attempt
    var loc = await Geolocator.requestPermission();

    // If user picked whileInUse, guide them to Settings to pick "All the time"
    if (loc == LocationPermission.whileInUse) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Always-On Location Required'),
            content: const Text(
              'For background tracking to work, you must select '
              '"Allow all the time" in location permissions.\n\n'
              'Tap "Open Settings" and change Location to "All the time".',
            ),
            actions: [
              TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      // Check again after returning from settings
      loc = await Geolocator.checkPermission();
    }

    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();

    await _checkAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()), backgroundColor: Color(0xFF1A1A2E));
    }
    if (_allGranted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()), backgroundColor: Color(0xFF1A1A2E));
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
                  _row(Icons.location_on, 'Location (Always)', 'Track your position even when app is closed', _locationGranted),
                  const SizedBox(height: 10),
                  _row(Icons.notifications, 'Persistent Notification', 'Keeps the service alive — cannot be dismissed', _notificationsGranted),
                  const SizedBox(height: 10),
                  _row(Icons.battery_full, 'Battery Optimization Off', 'Prevents Android from killing the app in sleep mode', false),
                  const SizedBox(height: 24),
                  const Text(
                    'After granting, the service will auto-track checkpoints. '
                    'You cannot manually complete checkpoints — only the app can when you reach the location.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _requestAll,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      child: const Text('Grant All & Start Tracking'),
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

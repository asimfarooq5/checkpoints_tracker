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
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final loc = await Geolocator.checkPermission();
    final notif = await Permission.notification.status;

    if (!mounted) return;
    setState(() {
      _locationGranted = loc == LocationPermission.always || loc == LocationPermission.whileInUse;
      _notificationsGranted = notif.isGranted;
      _checking = false;
    });

    // If already granted, skip straight to home
    if (_locationGranted && _notificationsGranted) {
      await _startServiceAndGoHome();
    }
  }

  Future<void> _startServiceAndGoHome() async {
    await initForegroundService();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _requestAll() async {
    await Geolocator.requestPermission();
    await Permission.notification.request();

    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allGranted = _locationGranted && _notificationsGranted;

    if (allGranted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
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
                  const Text(
                    'Background Access Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Guard Tracker needs these permissions to track your checkpoints in the background:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  _permissionRow(Icons.location_on, 'Location', 'Send position during check-ins', _locationGranted),
                  const SizedBox(height: 10),
                  _permissionRow(Icons.notifications, 'Notifications', 'Keep the service running persistently', _notificationsGranted),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _requestAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Grant Permissions & Continue'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _startServiceAndGoHome,
                    child: const Text('Skip (limited functionality)', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionRow(IconData icon, String title, String subtitle, bool granted) {
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

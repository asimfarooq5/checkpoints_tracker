import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/checkpoint_provider.dart';
import '../services/foreground_service.dart';
import '../widgets/checkpoint_card.dart';
import 'dart:async' show StreamSubscription;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationOn = true;
  StreamSubscription<ServiceStatus>? _locSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cp = context.read<CheckpointProvider>();
      await cp.loadCheckpoints();

      // Restart foreground service if it died
      final running = await isServiceRunning();
      if (!running) {
        await initForegroundService();
      }
    });

    _checkLocation();
    _locSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      setState(() => _locationOn = status == ServiceStatus.enabled);
      if (status == ServiceStatus.disabled) {
        _showLocationOffDialog();
      }
    });
  }

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _checkLocation() async {
    final on = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationOn = on);
  }

  Future<void> _showLocationOffDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
          'Location services are turned off. '
          'Checkpoints Tracker needs location to track your checkpoints.\n\n'
          'Please enable location in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await context.read<CheckpointProvider>().loadCheckpoints();
  }

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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Location off banner
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
          // Main content
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/checkpoint_provider.dart';
import '../widgets/checkpoint_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckpointProvider>().loadCheckpoints();
    });
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
            child: Center(
              child: Text(
                auth.user?.displayName ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: cp.isLoading && cp.checkpoints.isEmpty
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
                      // Stats bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            _statBadge('Total', cp.checkpoints.length, Colors.blue),
                            const SizedBox(width: 8),
                            _statBadge('Pending', cp.pendingCheckpoints.length, Colors.orange),
                            const SizedBox(width: 8),
                            _statBadge('Completed', cp.completedCheckpoints.length, Colors.green),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.my_location, size: 20),
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Checking in to all pending...')),
                                );
                                await cp.checkInAllPending();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Check-in complete')),
                                  );
                                }
                              },
                              tooltip: 'Check in to all pending',
                            ),
                          ],
                        ),
                      ),
                      if (cp.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(cp.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      Expanded(
                        child: cp.checkpoints.isEmpty
                            ? const Center(
                                child: Text('No checkpoints assigned yet.',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: cp.checkpoints.length,
                                itemBuilder: (_, i) => CheckpointCard(
                                  checkpoint: cp.checkpoints[i],
                                  onMarkCompleted: cp.checkpoints[i].isCompleted
                                      ? null
                                      : () async {
                                          final success = await cp.markCompleted(cp.checkpoints[i].id);
                                          if (context.mounted && success) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${cp.checkpoints[i].label} completed!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      '/checkpoint-detail',
                                      arguments: cp.checkpoints[i],
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
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

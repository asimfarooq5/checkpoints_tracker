import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkpoint.dart';
import '../providers/checkpoint_provider.dart';

class CheckpointDetailScreen extends StatelessWidget {
  const CheckpointDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checkpoint = ModalRoute.of(context)!.settings.arguments as Checkpoint;
    final cp = context.watch<CheckpointProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(checkpoint.label)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: checkpoint.isCompleted
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  checkpoint.isCompleted ? '✓ Completed' : '● Pending',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: checkpoint.isCompleted
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Coordinates
            _infoRow(Icons.location_on, 'Latitude', checkpoint.latitude.toStringAsFixed(6)),
            _infoRow(Icons.location_on, 'Longitude', checkpoint.longitude.toStringAsFixed(6)),
            const Divider(height: 24),

            // Timing
            _infoRow(Icons.calendar_today, 'Assigned', _formatDate(checkpoint.assignedAt)),
            if (checkpoint.completedAt != null)
              _infoRow(Icons.check_circle_outline, 'Completed', _formatDate(checkpoint.completedAt!)),
            if (checkpoint.lastCheckedAt != null)
              _infoRow(Icons.update, 'Last Check-in', _formatDate(checkpoint.lastCheckedAt!)),
            const Divider(height: 24),

            // Last known location if available
            if (checkpoint.lastLatitude != null && checkpoint.lastLongitude != null) ...[
              _infoRow(Icons.gps_fixed, 'Last Lat', checkpoint.lastLatitude!.toStringAsFixed(6)),
              _infoRow(Icons.gps_fixed, 'Last Lng', checkpoint.lastLongitude!.toStringAsFixed(6)),
              const SizedBox(height: 8),
            ],

            const Spacer(),

            // Action buttons
            if (!checkpoint.isCompleted) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _markCompleted(context, checkpoint, cp),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark as Completed', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _checkIn(context, checkpoint, cp),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Send Current Location'),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _markCompleted(BuildContext context, Checkpoint checkpoint, CheckpointProvider cp) async {
    final success = await cp.markCompleted(checkpoint.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cp.error ?? 'Failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _checkIn(BuildContext context, Checkpoint checkpoint, CheckpointProvider cp) async {
    final success = await cp.checkIn(checkpoint.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Location sent!' : cp.error ?? 'Check-in failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

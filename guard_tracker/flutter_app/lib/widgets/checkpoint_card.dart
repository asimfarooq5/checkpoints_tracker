import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import 'status_badge.dart';

class CheckpointCard extends StatelessWidget {
  final Checkpoint checkpoint;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onTap;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    this.onMarkCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                checkpoint.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: checkpoint.isCompleted ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (checkpoint.lastCheckedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last check-in: ${_formatDate(checkpoint.lastCheckedAt!)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  StatusBadge(isCompleted: checkpoint.isCompleted),
                  if (!checkpoint.isCompleted && onMarkCompleted != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: onMarkCompleted,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('Complete'),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

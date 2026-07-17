import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../utils/server_time.dart';
import 'status_badge.dart';

class CheckpointCard extends StatelessWidget {
  final Checkpoint checkpoint;
  final VoidCallback? onTap;
  final double? distance;
  final bool isSelected;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    this.onTap,
    this.distance,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: Color(0xFF2563EB), width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? const Color(0xFFEFF6FF) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                checkpoint.isCompleted
                    ? Icons.check_circle
                    : isSelected
                        ? Icons.navigation
                        : Icons.radio_button_unchecked,
                color: checkpoint.isCompleted
                    ? Colors.green
                    : isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(checkpoint.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 15,
                                  color: isSelected ? const Color(0xFF1E40AF) : null)),
                        ),
                        if (distance != null && !checkpoint.isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: distance! < 150
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              distance! < 1000
                                  ? '${distance!.toStringAsFixed(0)}m'
                                  : '${(distance! / 1000).toStringAsFixed(1)}km',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: distance! < 150
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      checkpoint.isCompleted
                          ? '✓ Completed ${checkpoint.completedAt != null ? _formatDate(checkpoint.completedAt!) : ""}'
                          : isSelected
                              ? '● Current target — auto-completes on arrival'
                              : 'Tap to set as target',
                      style: TextStyle(
                        fontSize: 11,
                        color: checkpoint.isCompleted
                            ? Colors.green
                            : isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey[500],
                        fontStyle: isSelected ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(isCompleted: checkpoint.isCompleted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = parseServerTime(dateStr)?.toLocal();
    if (dt == null) return dateStr;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

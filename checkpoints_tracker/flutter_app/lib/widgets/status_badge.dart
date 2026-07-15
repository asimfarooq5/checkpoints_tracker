import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final bool isCompleted;

  const StatusBadge({super.key, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'Pending',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF92400E),
        ),
      ),
    );
  }
}

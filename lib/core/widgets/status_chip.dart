import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color _colorFor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'completed':
      case 'approved':
        return AppColors.statusCompleted;
      case 'blocked':
      case 'rejected':
        return AppColors.statusBlocked;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class DueDateBadge extends StatelessWidget {
  final String status;
  final String dueDate;

  const DueDateBadge({
    super.key,
    required this.status,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'overdue':
        bg = AppTheme.expenseRed.withOpacity(0.12);
        fg = AppTheme.expenseRed;
        label = 'Lewat Tempo ($dueDate)';
        icon = Icons.error_outline_rounded;
        break;
      case 'due_soon':
        bg = AppTheme.warningAmber.withOpacity(0.15);
        fg = const Color(0xFFB45309);
        label = 'Segera ($dueDate)';
        icon = Icons.alarm_rounded;
        break;
      case 'paid':
        bg = AppTheme.incomeGreen.withOpacity(0.12);
        fg = AppTheme.incomeGreen;
        label = 'Lunas';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'partially_paid':
        bg = AppTheme.savingBlue.withOpacity(0.12);
        fg = AppTheme.savingBlue;
        label = 'Dicicil ($dueDate)';
        icon = Icons.timelapse_rounded;
        break;
      default:
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.black87;
        label = 'Tempo: $dueDate';
        icon = Icons.calendar_today_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

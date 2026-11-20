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
        bg = AppTheme.expenseRed.withValues(alpha: 0.12);
        fg = AppTheme.expenseRed;
        label = 'Lewat Tempo ($dueDate)';
        icon = Icons.error_rounded;
        break;
      case 'due_soon':
        bg = AppTheme.warningOrange.withValues(alpha: 0.15);
        fg = AppTheme.warningOrange;
        label = 'Segera ($dueDate)';
        icon = Icons.alarm_rounded;
        break;
      case 'paid':
        bg = AppTheme.incomeGreen.withValues(alpha: 0.12);
        fg = AppTheme.incomeGreen;
        label = 'Lunas';
        icon = Icons.check_circle_rounded;
        break;
      case 'partially_paid':
        bg = AppTheme.iosBlue.withValues(alpha: 0.12);
        fg = AppTheme.iosBlue;
        label = 'Dicicil ($dueDate)';
        icon = Icons.pie_chart_rounded;
        break;
      default:
        bg = const Color(0xFFF2F2F7);
        fg = AppTheme.textSecondary;
        label = 'Tempo: $dueDate';
        icon = Icons.calendar_today_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

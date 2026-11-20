import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';

class BalanceCard extends StatelessWidget {
  final String title;
  final int amount;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const BalanceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatRupiah(amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

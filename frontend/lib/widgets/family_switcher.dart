import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../core/theme/app_theme.dart';

class FamilySwitcher extends StatelessWidget {
  const FamilySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isFamily = finance.isFamilyView;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pribadi Tab
          GestureDetector(
            onTap: () {
              if (isFamily) {
                HapticFeedback.lightImpact();
                finance.toggleFamilyView(false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: !isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !isFamily
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: !isFamily ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Pribadi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !isFamily ? FontWeight.w600 : FontWeight.w500,
                      color: !isFamily ? AppTheme.textPrimary : AppTheme.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Keluarga Tab
          GestureDetector(
            onTap: () {
              if (!isFamily) {
                HapticFeedback.lightImpact();
                finance.toggleFamilyView(true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isFamily
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.group_rounded,
                    size: 14,
                    color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Keluarga',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFamily ? FontWeight.w600 : FontWeight.w500,
                      color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                      letterSpacing: -0.2,
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
}

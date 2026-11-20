import 'package:flutter/material.dart';
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
        color: AppTheme.slateBorder.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => finance.toggleFamilyView(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: !isFamily ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 15, color: !isFamily ? AppTheme.slateDark : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Pribadi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !isFamily ? FontWeight.bold : FontWeight.normal,
                      color: !isFamily ? AppTheme.slateDark : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => finance.toggleFamilyView(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isFamily ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 15, color: isFamily ? AppTheme.savingBlue : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Keluarga',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isFamily ? FontWeight.bold : FontWeight.normal,
                      color: isFamily ? AppTheme.savingBlue : Colors.grey,
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

import 'package:flutter/material.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_cart_outlined),
          activeIcon: const Icon(Icons.shopping_cart),
          label: l10n.cartTab,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.inventory_2_outlined),
          activeIcon: const Icon(Icons.inventory_2),
          label: l10n.productsTab,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.bar_chart_outlined),
          activeIcon: const Icon(Icons.bar_chart),
          label: l10n.reportTab,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/core/theme/app_theme.dart';
import 'package:ludo_pay_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:ludo_pay_app/features/printer/presentation/screens/printer_screen.dart';
import 'package:ludo_pay_app/features/products/presentation/screens/products_screen.dart';
import 'package:ludo_pay_app/features/report/presentation/screens/report_screen.dart';
import 'package:ludo_pay_app/features/report/providers/report_provider.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';
import 'package:ludo_pay_app/shared/widgets/app_bottom_nav.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  static const _screens = [
    CartScreen(),
    ProductsScreen(),
    ReportScreen(),
  ];

  static const _reportTabIndex = 2;

  void _onTabTap(int index) {
    // Reload report data each time the user opens the Report tab.
    if (index == _reportTabIndex) {
      ref.invalidate(reportProvider);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titles = [l10n.cartTab, l10n.productsTab, l10n.reportTab];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: l10n.printerTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

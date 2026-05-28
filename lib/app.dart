import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/core/theme/app_theme.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:festi_buvette_app/features/printer/presentation/screens/printer_screen.dart';
import 'package:festi_buvette_app/features/products/presentation/screens/products_screen.dart';
import 'package:festi_buvette_app/features/report/presentation/screens/report_screen.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';
import 'package:festi_buvette_app/shared/widgets/app_bottom_nav.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(settingsProvider).valueOrNull?.locale;
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeCode != null ? Locale(localeCode) : null,
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
    final businessName = ref
            .watch(settingsProvider)
            .valueOrNull
            ?.appName ??
        AppConstants.appName;
    // Cart tab shows the configured business name; other tabs show their own name.
    final titles = [businessName, l10n.productsTab, l10n.reportTab];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
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

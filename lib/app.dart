import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/core/theme/app_theme.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:festi_buvette_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:festi_buvette_app/features/products/presentation/screens/products_screen.dart';
import 'package:festi_buvette_app/features/report/presentation/screens/report_screen.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/features/sync/presentation/widgets/connection_status_icon.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';
import 'package:festi_buvette_app/shared/widgets/app_bottom_nav.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final localeCode = settings?.locale;
    final appBarColor =
        settings?.appBarColor ?? AppConstants.defaultAppBarColor;
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.buildLight(appBarColor),
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
  late final PageController _pageController;
  int _currentIndex = 0;

  static const _reportTabIndex = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (index == _reportTabIndex) {
      ref.invalidate(reportProvider);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final businessName =
        ref.watch(settingsProvider).valueOrNull?.appName ??
        AppConstants.appName;
    final titles = [businessName, l10n.productsTab, l10n.reportTab];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          const ConnectionStatusIcon(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const SettingsScreen(),
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                transitionsBuilder: (_, animation, _, child) => SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          _KeepAlive(child: CartScreen()),
          _KeepAlive(child: ProductsScreen()),
          _KeepAlive(child: ReportScreen()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// Keeps each PageView page alive so local widget state survives tab switches.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

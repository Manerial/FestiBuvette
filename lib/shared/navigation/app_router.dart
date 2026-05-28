import 'package:flutter/material.dart';
import 'package:festi_buvette_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:festi_buvette_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:festi_buvette_app/features/products/presentation/screens/products_screen.dart';
import 'package:festi_buvette_app/features/report/presentation/screens/report_screen.dart';

class AppRouter {
  static const String cart = '/';
  static const String products = '/products';
  static const String report = '/report';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings route) {
    switch (route.name) {
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case products:
        return MaterialPageRoute(builder: (_) => const ProductsScreen());
      case report:
        return MaterialPageRoute(builder: (_) => const ReportScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const CartScreen());
    }
  }
}

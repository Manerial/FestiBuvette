import 'package:flutter/material.dart';
import 'package:ludo_pay_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:ludo_pay_app/features/printer/presentation/screens/printer_screen.dart';
import 'package:ludo_pay_app/features/products/presentation/screens/products_screen.dart';
import 'package:ludo_pay_app/features/report/presentation/screens/report_screen.dart';

class AppRouter {
  static const String cart = '/';
  static const String products = '/products';
  static const String report = '/report';
  static const String printer = '/printer';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case products:
        return MaterialPageRoute(builder: (_) => const ProductsScreen());
      case report:
        return MaterialPageRoute(builder: (_) => const ReportScreen());
      case printer:
        return MaterialPageRoute(builder: (_) => const PrinterScreen());
      default:
        return MaterialPageRoute(builder: (_) => const CartScreen());
    }
  }
}

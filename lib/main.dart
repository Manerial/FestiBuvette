import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/app.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  await SalesRepository(DatabaseHelper.instance).autoCloseUnclosedPastDays(today);
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

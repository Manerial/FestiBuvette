import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';

class CatalogueData {
  final int categoriesCount;
  final int productsCount;
  final List<Map<String, dynamic>> _categories;
  final List<Map<String, dynamic>> _products;

  const CatalogueData._({
    required this.categoriesCount,
    required this.productsCount,
    required this._categories,
    required this._products,
  });
}

class CatalogueTransferService {
  final DatabaseHelper _dbHelper;
  final CategoriesRepository _categoriesRepo;
  final ProductsRepository _productsRepo;

  CatalogueTransferService()
      : _dbHelper = DatabaseHelper.instance,
        _categoriesRepo = CategoriesRepository(DatabaseHelper.instance),
        _productsRepo = ProductsRepository(DatabaseHelper.instance);

  static const _channel =
      MethodChannel('com.jcbpartner.festi_buvette_app/file_saver');

  Future<void> exportCatalogue() async {
    final categories = await _categoriesRepo.getAll();
    final products = await _productsRepo.getAllActive();
    final categoryById = {for (final c in categories) c.id!: c.name};

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': [
        for (final c in categories) {'name': c.name, 'sort_order': c.order}
      ],
      'products': [
        for (final p in products)
          {
            'name': p.name,
            'price': p.price,
            'sort_order': p.order,
            'category_name':
                p.categoryId != null ? categoryById[p.categoryId] : null,
          }
      ],
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);

    if (Platform.isAndroid) {
      await _channel.invokeMethod<bool>('saveJsonFile', {
        'fileName': 'catalogue_festibuvette.json',
        'content': json,
      });
      return;
    }

    // iOS: share sheet native avec option "Enregistrer dans Fichiers"
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/catalogue_festibuvette.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'FestiBuvette — Catalogue',
    );
  }

  /// Picks and parses a JSON catalogue file. Returns null if the user cancels.
  /// Throws [FormatException] on invalid or incompatible file.
  Future<CatalogueData?> pickAndParseCatalogue() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final content = await File(result.files.single.path!).readAsString();
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) throw const FormatException();

    if (decoded['version'] != 1) throw const FormatException();

    final rawCategories = decoded['categories'];
    final rawProducts = decoded['products'];
    if (rawCategories is! List || rawProducts is! List) {
      throw const FormatException();
    }

    final categories = rawCategories.cast<Map<String, dynamic>>();
    final products = rawProducts.cast<Map<String, dynamic>>();

    return CatalogueData._(
      categoriesCount: categories.length,
      productsCount: products.length,
      categories: categories,
      products: products,
    );
  }

  /// Replaces the local catalogue with the given data inside a single transaction.
  /// Products referenced by past sales are deactivated instead of deleted.
  Future<void> applyCatalogue(CatalogueData data) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Soft-delete or hard-delete every existing product
      final existingProducts = await txn.query('products');
      for (final p in existingProducts) {
        final id = p['id'] as int;
        final count = (Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM sale_lines WHERE product_id = ?',
              [id],
            )) ??
            0);
        if (count > 0) {
          await txn.update(
            'products',
            {'active': 0, 'category_id': null},
            where: 'id = ? AND active = 1',
            whereArgs: [id],
          );
        } else {
          await txn.delete('products', where: 'id = ?', whereArgs: [id]);
        }
      }

      // Replace categories
      await txn.delete('categories');
      final categoryIdMap = <String, int>{};
      for (int i = 0; i < data._categories.length; i++) {
        final cat = data._categories[i];
        final id = await txn.insert('categories', {
          'name': cat['name'] as String,
          'sort_order': cat['sort_order'] as int? ?? i,
        });
        categoryIdMap[cat['name'] as String] = id;
      }

      // Insert imported products
      for (int i = 0; i < data._products.length; i++) {
        final p = data._products[i];
        final categoryName = p['category_name'] as String?;
        await txn.insert('products', {
          'name': p['name'] as String,
          'price': (p['price'] as num).toDouble(),
          'sort_order': p['sort_order'] as int? ?? i,
          'active': 1,
          'created_at': now,
          'category_id':
              categoryName != null ? categoryIdMap[categoryName] : null,
        });
      }
    });
  }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String errorMessage(Object message) {
    return 'Error: $message';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get cartTab => 'Cart';

  @override
  String get productsTab => 'Products';

  @override
  String get reportTab => 'Report';

  @override
  String get printerTooltip => 'Printer';

  @override
  String get noProductsInCatalogue => 'No products in catalogue';

  @override
  String get addProductsFromTab => 'Add products from the Products tab';

  @override
  String get saleRecorded => '✅ Sale recorded';

  @override
  String get clearCartTitle => 'Clear cart?';

  @override
  String get clearCartMessage => 'All selected items will be removed.';

  @override
  String get clear => 'Clear';

  @override
  String get total => 'TOTAL';

  @override
  String get print => 'Print';

  @override
  String get noProducts => 'No products';

  @override
  String get tapPlusToAddProduct => 'Tap + to add your first product';

  @override
  String get addProductTooltip => 'Add a product';

  @override
  String get deleteProductTitle => 'Delete?';

  @override
  String deleteProductMessage(String name) {
    return 'Delete \"$name\"?\n\nIf this product has already been sold, it will only be deactivated to preserve history.';
  }

  @override
  String get editProduct => 'Edit product';

  @override
  String get newProduct => 'New product';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get productNameHint => 'E.g.: Coffee, Sandwich…';

  @override
  String get nameRequired => 'Name required';

  @override
  String maximumCharacters(int count) {
    return 'Maximum $count characters';
  }

  @override
  String get priceLabel => 'Price (€)';

  @override
  String get priceHint => 'E.g.: 1.50';

  @override
  String get priceRequired => 'Price required';

  @override
  String get invalidPrice => 'Invalid price';

  @override
  String get priceMustBePositive => 'Price must be greater than 0';

  @override
  String get printerScreenTitle => 'Bluetooth Printer';

  @override
  String get printerSettingsPlaceholder =>
      'Printer settings — to be implemented (E3)';

  @override
  String get reportPlaceholder => 'Report — to be implemented (E4)';
}

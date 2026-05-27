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
  String get confirm => 'Confirm';

  @override
  String get cartTab => 'Cart';

  @override
  String get productsTab => 'Products';

  @override
  String get reportTab => 'Report';

  @override
  String get settingsTooltip => 'Settings';

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
  String get printerNotConnected => 'Not connected';

  @override
  String printerConnectedTo(String name) {
    return 'Connected: $name';
  }

  @override
  String get printerScanning => 'Scanning...';

  @override
  String get printerConnecting => 'Connecting...';

  @override
  String get printerBluetoothDisabled => 'Bluetooth is disabled';

  @override
  String get printerConnectionFailed => 'Connection failed';

  @override
  String get printerScanDevices => 'Scan';

  @override
  String get printerDisconnect => 'Disconnect';

  @override
  String get printerTestPrint => 'Test print';

  @override
  String get printerConnect => 'Connect';

  @override
  String get printerNoDevicesFound => 'No devices found';

  @override
  String get printerAndroidHint =>
      'Android: pair your printer in Bluetooth Settings first';

  @override
  String get printerPermissionDenied =>
      'Bluetooth permission denied. Open Settings to allow it.';

  @override
  String get printerOpenSettings => 'Open Settings';

  @override
  String get printerNotConnectedTitle => 'No printer connected';

  @override
  String get printerNotConnectedMessage =>
      'No printer is connected. Do you want to record the sale without printing?';

  @override
  String get printerRecordWithoutPrinting => 'Record only';

  @override
  String get printerPrintError => 'Print failed. Sale not recorded.';

  @override
  String get reportNoSalesToday => 'No sales recorded today';

  @override
  String reportSaleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sales',
      one: '1 sale',
    );
    return '$_temp0';
  }

  @override
  String get reportByProduct => 'By product';

  @override
  String get reportByCart => 'By cart';

  @override
  String get reportQtyHeader => 'Qty';

  @override
  String get reportCloseDay => 'Close day';

  @override
  String reportDayClosed(String time) {
    return 'Closed at $time';
  }

  @override
  String get reportCloseDayTitle => 'Close today\'s session?';

  @override
  String get reportCloseDayMessage =>
      'Once closed, no more sales can be added for today.';

  @override
  String get settingsAppSection => 'App settings';

  @override
  String get settingsAppNameLabel => 'Business name';

  @override
  String get settingsAppNameHint => 'E.g.: My Coffee Shop';

  @override
  String get settingsAppNameSaved => 'Name saved';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageFr => 'Français';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsPrinterSection => 'Bluetooth printer';

  @override
  String get allCategories => 'All';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get deleteCategoryTitle => 'Delete category?';

  @override
  String get deleteCategoryMessage =>
      'Products in this category will become uncategorized.';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get categoryNameHint => 'E.g.: Drinks, Food…';

  @override
  String get categoryLabel => 'Category';

  @override
  String get noCategory => 'Uncategorized';

  @override
  String get noProductsInCategory => 'No products in this category';

  @override
  String get tenderedAmount => 'Amount tendered';

  @override
  String get changeDue => 'Change';

  @override
  String get insufficientAmount => 'Insufficient amount';
}

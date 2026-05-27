import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorMessage(Object message);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cartTab.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTab;

  /// No description provided for @productsTab.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTab;

  /// No description provided for @reportTab.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTab;

  /// No description provided for @printerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printerTooltip;

  /// No description provided for @noProductsInCatalogue.
  ///
  /// In en, this message translates to:
  /// **'No products in catalogue'**
  String get noProductsInCatalogue;

  /// No description provided for @addProductsFromTab.
  ///
  /// In en, this message translates to:
  /// **'Add products from the Products tab'**
  String get addProductsFromTab;

  /// No description provided for @saleRecorded.
  ///
  /// In en, this message translates to:
  /// **'✅ Sale recorded'**
  String get saleRecorded;

  /// No description provided for @clearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cart?'**
  String get clearCartTitle;

  /// No description provided for @clearCartMessage.
  ///
  /// In en, this message translates to:
  /// **'All selected items will be removed.'**
  String get clearCartMessage;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products'**
  String get noProducts;

  /// No description provided for @tapPlusToAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first product'**
  String get tapPlusToAddProduct;

  /// No description provided for @addProductTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a product'**
  String get addProductTooltip;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?\n\nIf this product has already been sold, it will only be deactivated to preserve history.'**
  String deleteProductMessage(String name);

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @newProduct.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get newProduct;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Coffee, Sandwich…'**
  String get productNameHint;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// No description provided for @maximumCharacters.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} characters'**
  String maximumCharacters(int count);

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (€)'**
  String get priceLabel;

  /// No description provided for @priceHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: 1.50'**
  String get priceHint;

  /// No description provided for @priceRequired.
  ///
  /// In en, this message translates to:
  /// **'Price required'**
  String get priceRequired;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get invalidPrice;

  /// No description provided for @priceMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Price must be greater than 0'**
  String get priceMustBePositive;

  /// No description provided for @printerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Printer'**
  String get printerScreenTitle;

  /// No description provided for @printerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get printerNotConnected;

  /// No description provided for @printerConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected: {name}'**
  String printerConnectedTo(String name);

  /// No description provided for @printerScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get printerScanning;

  /// No description provided for @printerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get printerConnecting;

  /// No description provided for @printerBluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is disabled'**
  String get printerBluetoothDisabled;

  /// No description provided for @printerConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get printerConnectionFailed;

  /// No description provided for @printerScanDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get printerScanDevices;

  /// No description provided for @printerDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get printerDisconnect;

  /// No description provided for @printerTestPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get printerTestPrint;

  /// No description provided for @printerConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get printerConnect;

  /// No description provided for @printerNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get printerNoDevicesFound;

  /// No description provided for @printerAndroidHint.
  ///
  /// In en, this message translates to:
  /// **'Android: pair your printer in Bluetooth Settings first'**
  String get printerAndroidHint;

  /// No description provided for @printerNotConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No printer connected'**
  String get printerNotConnectedTitle;

  /// No description provided for @printerNotConnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'No printer is connected. Do you want to record the sale without printing?'**
  String get printerNotConnectedMessage;

  /// No description provided for @printerRecordWithoutPrinting.
  ///
  /// In en, this message translates to:
  /// **'Record only'**
  String get printerRecordWithoutPrinting;

  /// No description provided for @printerPrintError.
  ///
  /// In en, this message translates to:
  /// **'Print failed. Sale not recorded.'**
  String get printerPrintError;

  /// No description provided for @reportNoSalesToday.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded today'**
  String get reportNoSalesToday;

  /// No description provided for @reportSaleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sale} other{{count} sales}}'**
  String reportSaleCount(num count);

  /// No description provided for @reportByProduct.
  ///
  /// In en, this message translates to:
  /// **'By product'**
  String get reportByProduct;

  /// No description provided for @reportQtyHeader.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportQtyHeader;

  /// No description provided for @reportCloseDay.
  ///
  /// In en, this message translates to:
  /// **'Close day'**
  String get reportCloseDay;

  /// No description provided for @reportDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed at {time}'**
  String reportDayClosed(String time);

  /// No description provided for @reportCloseDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Close today\'s session?'**
  String get reportCloseDayTitle;

  /// No description provided for @reportCloseDayMessage.
  ///
  /// In en, this message translates to:
  /// **'Once closed, no more sales can be added for today.'**
  String get reportCloseDayMessage;

  /// No description provided for @settingsAppSection.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsAppSection;

  /// No description provided for @settingsAppNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get settingsAppNameLabel;

  /// No description provided for @settingsAppNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: My Coffee Shop'**
  String get settingsAppNameHint;

  /// No description provided for @settingsAppNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get settingsAppNameSaved;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageFr.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFr;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsPrinterSection.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth printer'**
  String get settingsPrinterSection;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

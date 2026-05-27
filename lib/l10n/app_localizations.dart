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

  /// Generic error with details
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorMessage(Object message);

  /// Generic cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Save button in edit mode
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Add button in create mode
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Generic confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Cart tab label and page title
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTab;

  /// Products tab label and page title
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTab;

  /// Report tab label and page title
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTab;

  /// App bar printer icon tooltip
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printerTooltip;

  /// Cart: empty catalogue state title
  ///
  /// In en, this message translates to:
  /// **'No products in catalogue'**
  String get noProductsInCatalogue;

  /// Cart: empty catalogue state hint
  ///
  /// In en, this message translates to:
  /// **'Add products from the Products tab'**
  String get addProductsFromTab;

  /// Snackbar after a successful sale
  ///
  /// In en, this message translates to:
  /// **'✅ Sale recorded'**
  String get saleRecorded;

  /// Clear cart dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear cart?'**
  String get clearCartTitle;

  /// Clear cart dialog body
  ///
  /// In en, this message translates to:
  /// **'All selected items will be removed.'**
  String get clearCartMessage;

  /// Clear cart button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Total label in cart footer
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// Print button label in cart footer
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// Products: empty list state title
  ///
  /// In en, this message translates to:
  /// **'No products'**
  String get noProducts;

  /// Products: empty list state hint
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first product'**
  String get tapPlusToAddProduct;

  /// FAB tooltip in products screen
  ///
  /// In en, this message translates to:
  /// **'Add a product'**
  String get addProductTooltip;

  /// Delete product dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteProductTitle;

  /// Delete product dialog body
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?\n\nIf this product has already been sold, it will only be deactivated to preserve history.'**
  String deleteProductMessage(String name);

  /// Product form dialog title in edit mode
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// Product form dialog title in create mode
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get newProduct;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameLabel;

  /// Name field hint
  ///
  /// In en, this message translates to:
  /// **'E.g.: Coffee, Sandwich…'**
  String get productNameHint;

  /// Validation: empty name
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// Validation: name too long
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} characters'**
  String maximumCharacters(int count);

  /// Price field label
  ///
  /// In en, this message translates to:
  /// **'Price (€)'**
  String get priceLabel;

  /// Price field hint
  ///
  /// In en, this message translates to:
  /// **'E.g.: 1.50'**
  String get priceHint;

  /// Validation: empty price
  ///
  /// In en, this message translates to:
  /// **'Price required'**
  String get priceRequired;

  /// Validation: price cannot be parsed
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get invalidPrice;

  /// Validation: price ≤ 0
  ///
  /// In en, this message translates to:
  /// **'Price must be greater than 0'**
  String get priceMustBePositive;

  /// Printer settings screen title
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Printer'**
  String get printerScreenTitle;

  /// Printer settings placeholder
  ///
  /// In en, this message translates to:
  /// **'Printer settings — to be implemented (E3)'**
  String get printerSettingsPlaceholder;

  /// Report: empty state when no business day exists
  ///
  /// In en, this message translates to:
  /// **'No sales recorded today'**
  String get reportNoSalesToday;

  /// Number of sales for the day
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sale} other{{count} sales}}'**
  String reportSaleCount(num count);

  /// Report section header: product breakdown
  ///
  /// In en, this message translates to:
  /// **'By product'**
  String get reportByProduct;

  /// Report table column header: quantity
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportQtyHeader;

  /// Button to close the business day
  ///
  /// In en, this message translates to:
  /// **'Close day'**
  String get reportCloseDay;

  /// Badge shown when the business day is already closed
  ///
  /// In en, this message translates to:
  /// **'Closed at {time}'**
  String reportDayClosed(String time);

  /// Close day confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Close today\'s session?'**
  String get reportCloseDayTitle;

  /// Close day confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Once closed, no more sales can be added for today.'**
  String get reportCloseDayMessage;
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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String errorMessage(Object message) {
    return 'Erreur : $message';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get save => 'Enregistrer';

  @override
  String get add => 'Ajouter';

  @override
  String get confirm => 'Confirmer';

  @override
  String get cartTab => 'Panier';

  @override
  String get productsTab => 'Produits';

  @override
  String get reportTab => 'Rapport';

  @override
  String get printerTooltip => 'Imprimante';

  @override
  String get noProductsInCatalogue => 'Aucun produit dans le catalogue';

  @override
  String get addProductsFromTab =>
      'Ajoutez des produits depuis l\'onglet Produits';

  @override
  String get saleRecorded => '✅ Vente enregistrée';

  @override
  String get clearCartTitle => 'Vider le panier ?';

  @override
  String get clearCartMessage =>
      'Tous les articles sélectionnés seront retirés.';

  @override
  String get clear => 'Vider';

  @override
  String get total => 'TOTAL';

  @override
  String get print => 'Imprimer';

  @override
  String get noProducts => 'Aucun produit';

  @override
  String get tapPlusToAddProduct =>
      'Appuyez sur + pour ajouter votre premier produit';

  @override
  String get addProductTooltip => 'Ajouter un produit';

  @override
  String get deleteProductTitle => 'Supprimer ?';

  @override
  String deleteProductMessage(String name) {
    return 'Supprimer « $name » ?\n\nSi ce produit a déjà été vendu, il sera seulement désactivé pour préserver l\'historique.';
  }

  @override
  String get editProduct => 'Modifier le produit';

  @override
  String get newProduct => 'Nouveau produit';

  @override
  String get productNameLabel => 'Nom du produit';

  @override
  String get productNameHint => 'Ex : Café, Sandwich…';

  @override
  String get nameRequired => 'Nom requis';

  @override
  String maximumCharacters(int count) {
    return 'Maximum $count caractères';
  }

  @override
  String get priceLabel => 'Prix TTC (€)';

  @override
  String get priceHint => 'Ex : 1,50';

  @override
  String get priceRequired => 'Prix requis';

  @override
  String get invalidPrice => 'Prix invalide';

  @override
  String get priceMustBePositive => 'Le prix doit être supérieur à 0';

  @override
  String get printerScreenTitle => 'Imprimante Bluetooth';

  @override
  String get printerSettingsPlaceholder =>
      'Paramètres imprimante — à implémenter (E3)';

  @override
  String get reportNoSalesToday => 'Aucune vente enregistrée aujourd\'hui';

  @override
  String reportSaleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ventes',
      one: '1 vente',
    );
    return '$_temp0';
  }

  @override
  String get reportByProduct => 'Par produit';

  @override
  String get reportQtyHeader => 'Qté';

  @override
  String get reportCloseDay => 'Clôturer la journée';

  @override
  String reportDayClosed(String time) {
    return 'Clôturée à $time';
  }

  @override
  String get reportCloseDayTitle => 'Clôturer la session ?';

  @override
  String get reportCloseDayMessage =>
      'Une fois clôturée, les ventes ne pourront plus être ajoutées pour aujourd\'hui.';
}

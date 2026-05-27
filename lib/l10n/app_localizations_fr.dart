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
  String get settings => 'Paramètres';

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
  String get printerNotConnected => 'Non connectée';

  @override
  String printerConnectedTo(String name) {
    return 'Connectée : $name';
  }

  @override
  String get printerScanning => 'Recherche en cours…';

  @override
  String get printerConnecting => 'Connexion en cours…';

  @override
  String get printerBluetoothDisabled => 'Bluetooth désactivé';

  @override
  String get printerConnectionFailed => 'Échec de la connexion';

  @override
  String get printerScanDevices => 'Rechercher';

  @override
  String get printerDisconnect => 'Déconnecter';

  @override
  String get printerTestPrint => 'Impression test';

  @override
  String get printerConnect => 'Connecter';

  @override
  String get printerNoDevicesFound => 'Aucun appareil trouvé';

  @override
  String get printerAndroidHint =>
      'Android : associez d\'abord l\'imprimante dans les Paramètres Bluetooth';

  @override
  String get printerPermissionDenied =>
      'Permission Bluetooth refusée. Ouvrez les Réglages pour l\'autoriser.';

  @override
  String get printerOpenSettings => 'Ouvrir les Réglages';

  @override
  String get printerNotConnectedTitle => 'Aucune imprimante connectée';

  @override
  String get printerNotConnectedMessage =>
      'Aucune imprimante n\'est connectée. Enregistrer la vente sans imprimer ?';

  @override
  String get printerRecordWithoutPrinting => 'Enregistrer seulement';

  @override
  String get printerPrintError =>
      'Échec de l\'impression. Vente non enregistrée.';

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
  String get reportByCart => 'Par panier';

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
      'Une journée cloturée pourra être rouverte si une nouvelle vente est faite le même jour.';

  @override
  String get settingsAppSection => 'Paramètres de l\'application';

  @override
  String get settingsAppNameLabel => 'Nom de l\'établissement';

  @override
  String get settingsAppNameHint => 'Ex : Mon café';

  @override
  String get settingsAppNameSaved => 'Nom enregistré';

  @override
  String get settingsLanguageSection => 'Langue';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsLanguageFr => 'Français';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsCartGridView => 'Vue en grille';

  @override
  String get settingsCartGridViewSubtitle =>
      'Afficher les produits en tuiles dans le panier';

  @override
  String get allCategories => 'Tout';

  @override
  String get manageCategories => 'Gérer les catégories';

  @override
  String get noCategoriesYet => 'Aucune catégorie pour l\'instant';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get deleteCategoryTitle => 'Supprimer la catégorie ?';

  @override
  String get deleteCategoryMessage =>
      'Les produits de cette catégorie passeront en non catégorisés.';

  @override
  String get categoryNameLabel => 'Nom de la catégorie';

  @override
  String get categoryNameHint => 'Ex : Boissons, Nourriture…';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get noCategory => 'Non catégorisé';

  @override
  String get noProductsInCategory => 'Aucun produit dans cette catégorie';

  @override
  String get tenderedAmount => 'Montant remis';

  @override
  String get changeDue => 'Rendu';

  @override
  String get insufficientAmount => 'Montant insuffisant';
}

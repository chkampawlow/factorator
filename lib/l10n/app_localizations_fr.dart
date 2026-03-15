// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get profile => 'Profil';

  @override
  String get logout => 'Déconnexion';

  @override
  String get cancel => 'Annuler';

  @override
  String get currency => 'Devise';

  @override
  String get selectCurrency => 'Choisir la devise';

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Choisir la langue';

  @override
  String get appColor => 'Couleur de l\'application';

  @override
  String get toggleTheme => 'Changer le thème';

  @override
  String get email => 'Email';

  @override
  String get fiscalId => 'Matricule fiscal';

  @override
  String get noUserData => 'Aucune donnée utilisateur';

  @override
  String get logoutQuestion => 'Voulez-vous vous déconnecter ?';

  @override
  String currencyChanged(String value) {
    return 'Devise changée en $value';
  }

  @override
  String languageChanged(String value) {
    return 'Langue changée en $value';
  }

  @override
  String get clientUpdateApiNotAddedYet => 'API de mise à jour du client non disponible';

  @override
  String get clientAddedSuccessfully => 'Client ajouté avec succès';

  @override
  String clientAddedSuccessfullyWithId(String id) {
    return 'Client ajouté avec succès avec l\'ID : $id';
  }

  @override
  String get saveFailed => 'Échec de l\'enregistrement';

  @override
  String get fiscalIdMf => 'Matricule Fiscal (MF)';

  @override
  String get cin => 'CIN';

  @override
  String get editCustomer => 'Modifier le client';

  @override
  String get addCustomer => 'Ajouter un client';

  @override
  String get companyName => 'Nom de l\'entreprise';

  @override
  String get fullName => 'Nom complet';

  @override
  String get requiredField => 'Champ requis';

  @override
  String get mfRequired => 'MF requis';

  @override
  String get cinRequired => 'CIN requis';

  @override
  String get cinTooShort => 'Le CIN est trop court';

  @override
  String get emailOptional => 'Email (optionnel)';

  @override
  String get phoneOptional => 'Téléphone (optionnel)';

  @override
  String get addressOptional => 'Adresse (optionnelle)';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveCustomer => 'Enregistrer le client';

  @override
  String get newInvoice => 'Nouvelle facture';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get createInvoice => 'Créer la facture';

  @override
  String get client => 'Client';

  @override
  String get chooseClientOrAddNew => 'Choisir un client ou en ajouter un';

  @override
  String get dueDate => 'Date d\'échéance';

  @override
  String get nextStep => 'Étape suivante';

  @override
  String issueDateAutoToday(String date) {
    return 'La date de facture sera définie automatiquement à aujourd\'hui ($date). Après la création de la facture, vous serez redirigé vers l\'écran de détail de la facture où vous pourrez ajouter des articles.';
  }

  @override
  String get clientSelectionFailed => 'Échec de la sélection du client';

  @override
  String get pleaseChooseClient => 'Veuillez choisir un client.';

  @override
  String get chooseClient => 'Choisir un client';

  @override
  String get addNewClient => 'Ajouter un nouveau client';

  @override
  String get loadFailed => 'Échec du chargement';

  @override
  String get invalidNumber => 'Nombre invalide';

  @override
  String get priceAndTvaMustBeValidNumbers => 'Le prix et la TVA doivent être des nombres valides.';

  @override
  String get invalidProductId => 'Identifiant produit invalide';

  @override
  String get productUpdatedSuccessfully => 'Produit mis à jour avec succès';

  @override
  String get productSavedSuccessfully => 'Produit enregistré avec succès';

  @override
  String get editProduct => 'Modifier le produit';

  @override
  String get addProduct => 'Ajouter un produit';

  @override
  String get saveProduct => 'Enregistrer le produit';

  @override
  String get updateProductDetails => 'Mettre à jour les détails du produit';

  @override
  String get createNewProductOrService => 'Créer un nouveau produit ou service';

  @override
  String get codeOptional => 'Code (optionnel)';

  @override
  String get productCodeExample => 'ex. PRD-001';

  @override
  String get productServiceName => 'Nom du produit / service';

  @override
  String get productServiceNameExample => 'ex. Web design, Consulting...';

  @override
  String get price => 'Prix';

  @override
  String get priceExample => 'ex. 120 ou 120,50';

  @override
  String get tvaPercent => 'TVA %';

  @override
  String get tvaExample => 'ex. 19';

  @override
  String get unitOptional => 'Unité (optionnelle)';

  @override
  String get unitExample => 'heure / pièce / kg...';

  @override
  String get failedToLoadCustomers => 'Échec du chargement des clients';

  @override
  String get mfLabel => 'MF';

  @override
  String get missingClientId => 'Identifiant client manquant';

  @override
  String get invalidClientId => 'Identifiant client invalide';

  @override
  String get deleteCustomerQuestion => 'Supprimer le client ?';

  @override
  String areYouSureDeleteCustomer(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ?';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get customerDeletedSuccessfully => 'Client supprimé avec succès';

  @override
  String get deleteFailed => 'Échec de la suppression';

  @override
  String get unnamedCustomer => 'Client sans nom';

  @override
  String get customers => 'Clients';

  @override
  String get refresh => 'Actualiser';

  @override
  String get add => 'Ajouter';

  @override
  String get searchNameMfCin => 'Rechercher (nom / MF / CIN)...';

  @override
  String get allCustomers => 'Tous les clients';

  @override
  String get noCustomersYet => 'Aucun client pour le moment';

  @override
  String get edit => 'Modifier';
}

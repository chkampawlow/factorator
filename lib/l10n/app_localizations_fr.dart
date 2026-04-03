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
  String get fiscalId => 'Identifiant fiscal';

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
  String get dashboard => 'Tableau';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get advanceInvoice => 'Facture d\'avance';

  @override
  String get advanceInvoiceComingSoon => 'Facture d\'avance : bientôt disponible';

  @override
  String get recentTransactions => 'Transactions récentes';

  @override
  String get all => 'Tous';

  @override
  String get noInvoicesYet => 'Aucune facture pour le moment.';

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

  @override
  String get invoice => 'Facture';

  @override
  String get status => 'Statut';

  @override
  String get issue => 'Date d\'émission';

  @override
  String get due => 'Échéance';

  @override
  String get fill => 'Remplir';

  @override
  String get previewPdf => 'Aperçu PDF';

  @override
  String get retry => 'Réessayer';

  @override
  String get error => 'Erreur';

  @override
  String get invoiceNotFound => 'Facture introuvable.';

  @override
  String get addAtLeastOneItemBeforePreviewPdf => 'Ajoutez au moins un article avant d\'afficher l\'aperçu PDF.';

  @override
  String get qtyMustBeGreaterThanZero => 'La quantité doit être > 0';

  @override
  String get itemAdded => 'Article ajouté';

  @override
  String get itemDeleted => 'Article supprimé';

  @override
  String get itemUpdated => 'Article mis à jour';

  @override
  String get deleteItem => 'Supprimer l\'article';

  @override
  String get removeThisItemFromInvoice => 'Supprimer cet article de la facture ?';

  @override
  String get editItem => 'Modifier l\'article';

  @override
  String get qty => 'Qté';

  @override
  String get discountPercent => 'Remise (%)';

  @override
  String get save => 'Enregistrer';

  @override
  String get addItem => 'Ajouter un article';

  @override
  String get product => 'Produit';

  @override
  String get priceOverride => 'Remplacer le prix';

  @override
  String get addToInvoice => 'Ajouter à la facture';

  @override
  String get noItemsYet => 'Aucun article pour le moment.';

  @override
  String get invoices => 'Factures';

  @override
  String get overdue => 'En retard';

  @override
  String get code => 'Code';

  @override
  String get type => 'Type';

  @override
  String get doc => 'Doc';

  @override
  String get issued => 'Émise le';

  @override
  String get dueToday => 'Échéance aujourd\'hui';

  @override
  String dueInDays(String days, String suffix) {
    return 'Échéance dans $days jour$suffix';
  }

  @override
  String overdueByDays(String days, String suffix) {
    return 'En retard de $days jour$suffix';
  }

  @override
  String get createYourFirstInvoiceToSeeItHere => 'Créez votre première facture pour l\'afficher ici.';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get loginToManageApp => 'Connectez-vous pour gérer vos clients, produits et factures.';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get emailRequired => 'L\'email est requis';

  @override
  String get enterValidEmail => 'Entrez un email valide';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordRequired => 'Le mot de passe est requis';

  @override
  String get minimum6Characters => 'Minimum 6 caractères';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get forgotPassword => 'Mot de passe oublié';

  @override
  String get login => 'Connexion';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte ? ';

  @override
  String get createOne => 'Créer un compte';

  @override
  String get loginSuccess => 'Connexion réussie';

  @override
  String welcomeUser(String name) {
    return 'Bienvenue $name';
  }

  @override
  String get productsServices => 'Produits / Services';

  @override
  String get searchProductsHint => 'Rechercher (nom / code / unité / TVA)...';

  @override
  String get noProductsYet => 'Aucun produit pour le moment';

  @override
  String get deleteProductQuestion => 'Supprimer le produit ?';

  @override
  String areYouSureDeleteProduct(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ?';
  }

  @override
  String get productDeleted => 'Produit supprimé ✅';

  @override
  String get unnamedProduct => 'Produit sans nom';

  @override
  String get unit => 'Unité';

  @override
  String get firstNameRequired => 'Le prénom est requis';

  @override
  String get lastNameRequired => 'Le nom est requis';

  @override
  String get fiscalIdRequired => 'Le matricule fiscal est requis';

  @override
  String get fiscalIdMustMatch => 'Le matricule fiscal doit correspondre à 1234567ABC123';

  @override
  String get passwordMinLength => 'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get pleaseConfirmPassword => 'Veuillez confirmer votre mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get accountCreatedSuccessfully => 'Compte créé avec succès';

  @override
  String get whoAreYou => 'Qui êtes-vous ?';

  @override
  String get startWithPersonalInformation => 'Commencez par vos informations personnelles.';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get companyDetails => 'Détails de l\'entreprise';

  @override
  String get addOrganizationAndFiscalInfo => 'Ajoutez votre organisation et vos informations fiscales.';

  @override
  String get organizationName => 'Nom de l\'entreprise';

  @override
  String get fiscalIdRequiredLabel => 'Matricule Fiscal*';

  @override
  String get fiscalIdFormat => 'Format : 1234567ABC123';

  @override
  String get contactInformation => 'Informations de contact';

  @override
  String get howCanWeReachYou => 'Comment pouvons-nous vous joindre ?';

  @override
  String get emailAddressLabel => 'Adresse email';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get secureYourAccount => 'Sécurisez votre compte';

  @override
  String get chooseStrongPassword => 'Choisissez un mot de passe fort.';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get reviewAndCreate => 'Vérifier et créer';

  @override
  String get reviewBeforeCreate => 'Assurez-vous que tout est correct avant de créer le compte.';

  @override
  String get organization => 'Organisation';

  @override
  String get fiscalIdLabel => 'Matricule Fiscal';

  @override
  String get phone => 'Téléphone';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get back => 'Retour';

  @override
  String get continueText => 'Continuer';

  @override
  String get invalidFiscalId => 'Matricule fiscal invalide';

  @override
  String get phoneNumberRequired => 'Le numéro de téléphone est requis';

  @override
  String get phoneNumberInvalid => 'Numéro de téléphone invalide';

  @override
  String get clients => 'Clients';

  @override
  String get items => 'Articles';

  @override
  String get searchProduct => 'Rechercher un produit';

  @override
  String get noProductsFound => 'Aucun produit trouvé';

  @override
  String get selectProduct => 'Sélectionner un produit';

  @override
  String get companyInformation => 'Informations de l\'entreprise';

  @override
  String get fax => 'Fax';

  @override
  String get address => 'Adresse';

  @override
  String get website => 'Site web';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès';

  @override
  String get profileImageUpdated => 'Photo de profil mise à jour';

  @override
  String get tapImageToChangePhoto => 'Appuyez sur l\'image pour changer la photo';

  @override
  String get region => 'Région';

  @override
  String get name => 'Nom';

  @override
  String get identifier => 'Identifiant';

  @override
  String get notes => 'Notes';

  @override
  String get subtotal => 'Sous-total';

  @override
  String get total => 'Total';

  @override
  String get verifyEmail => 'Vérifiez votre email';

  @override
  String get verifyEmailDescription => 'Veuillez vérifier votre email avant de continuer. Entrez le code à 6 chiffres ou renvoyez l\'email.';

  @override
  String get verificationCode => 'Code de vérification';

  @override
  String get verifyNow => 'Vérifier';

  @override
  String get resendEmail => 'Renvoyer l\'email';

  @override
  String resendEmailIn(int seconds) {
    return 'Renvoyer l\'email dans ${seconds}s';
  }

  @override
  String get verificationEmailSent => 'Email de vérification envoyé';

  @override
  String get enterVerificationCode => 'Entrez le code de vérification';

  @override
  String get emailVerifiedSuccessfully => 'Email vérifié avec succès';

  @override
  String get forgotPasswordDescription => 'Entrez votre email et nous vous enverrons un code à 6 chiffres pour réinitialiser votre mot de passe.';

  @override
  String get sendResetCode => 'Envoyer le code';

  @override
  String get resetCodeSent => 'Code de réinitialisation envoyé';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordDescription => 'Entrez le code à 6 chiffres et votre nouveau mot de passe.';

  @override
  String get enterResetCode => 'Entrez le code de réinitialisation';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get passwordResetSuccessful => 'Mot de passe réinitialisé avec succès';

  @override
  String get twoFactorTitle => 'Authentification à deux facteurs';

  @override
  String twoFactorSubtitle(Object email) {
    return 'Saisissez le code à 6 chiffres depuis votre application d’authentification pour $email.';
  }

  @override
  String get twoFactorCode => 'Code d’authentification';

  @override
  String get twoFactorCodeRequired => 'Le code d’authentification est requis';

  @override
  String get twoFactorCodeInvalid => 'Entrez un code valide à 6 chiffres';

  @override
  String get twoFactorHint => 'Ouvrez Google Authenticator et saisissez le code actuel à 6 chiffres.';

  @override
  String get twoFactorVerify => 'Vérifier';

  @override
  String get twoFactorBack => 'Retour';

  @override
  String get twoFactorSuccess => 'Vérification en deux facteurs réussie';

  @override
  String get twoFactorSetupTitle => 'Google Authenticator';

  @override
  String get twoFactorSetupSubtitle => 'Configurez l’authentification à deux facteurs pour mieux protéger votre compte.';

  @override
  String get twoFactorStep1 => 'Étape 1';

  @override
  String get twoFactorScanQr => 'Scannez ce QR code avec Google Authenticator ou saisissez la clé manuelle ci-dessous.';

  @override
  String get twoFactorManualKey => 'Clé manuelle';

  @override
  String get twoFactorManualKeyUnavailable => 'Clé manuelle indisponible';

  @override
  String get twoFactorQrUnavailable => 'QR code indisponible';

  @override
  String get twoFactorStep2 => 'Étape 2';

  @override
  String get twoFactorEnterSetupCode => 'Saisissez le code à 6 chiffres généré par votre application d’authentification.';

  @override
  String get twoFactorEnableButton => 'Activer la 2FA';

  @override
  String get twoFactorEnabledSuccess => 'Authentification à deux facteurs activée avec succès';

  @override
  String get somethingWentWrong => 'Une erreur s’est produite';

  @override
  String get twoFactorDisableTitle => 'Désactiver l’authentification à deux facteurs';

  @override
  String get twoFactorDisableMessage => 'Voulez-vous vraiment désactiver Google Authenticator pour ce compte ?';

  @override
  String get twoFactorDisableButton => 'Désactiver';

  @override
  String get twoFactorDisableCodeTitle => 'Entrez le code de désactivation';

  @override
  String get twoFactorDisabledSuccess => 'Authentification à deux facteurs désactivée avec succès';

  @override
  String get twoFactorToggleTitle => 'Google Authenticator';

  @override
  String get twoFactorToggleOn => 'L’authentification à deux facteurs est activée';

  @override
  String get twoFactorToggleOff => 'L’authentification à deux facteurs est désactivée';

  @override
  String get twoFactorLoadingStatus => 'Vérification du statut de l’authentification à deux facteurs...';

  @override
  String get twoFactorDisabling => 'Désactivation de l’authentification à deux facteurs...';

  @override
  String get twoFactorPreparing => 'Préparation de l’authentification à deux facteurs...';

  @override
  String get twoFactorManualKeyCopied => 'Clé manuelle copiée';

  @override
  String get copy => 'Copier';

  @override
  String get monthlyRevenue => 'Revenu mensuel';

  @override
  String get pending => 'En attente';

  @override
  String get averageInvoice => 'Moyenne facture';

  @override
  String get topClients => 'Top clients';

  @override
  String get revenueCurve => 'Courbe des revenus';

  @override
  String get paidVsUnpaid => 'Payées vs impayées';

  @override
  String get totalLabel => 'Total';

  @override
  String get paidLabel => 'Payée';

  @override
  String get unpaidLabel => 'Non payée';

  @override
  String get paymentRate => 'Taux de paiement';

  @override
  String get growthCurve => 'Courbe de croissance';

  @override
  String get cancelledLabel => 'Annulée';

  @override
  String get searchInvoiceClientEmail => 'Rechercher facture, client, email...';

  @override
  String get noInvoicesMatchSearch => 'Aucune facture ne correspond à votre recherche';

  @override
  String get changeStatus => 'Changer le statut';

  @override
  String get markAsPaid => 'Marquer comme payé';

  @override
  String get markAsUnpaid => 'Marquer comme impayé';

  @override
  String get markAsCancelled => 'Marquer comme annulé';

  @override
  String get invoiceStatusUpdated => 'Statut de la facture mis à jour';

  @override
  String get updateFailed => 'Échec de la mise à jour';

  @override
  String get dueSoon => 'Bientôt due';

  @override
  String get paid => 'Payées';

  @override
  String get unpaid => 'Non payées';

  @override
  String get cancelled => 'Annulées';

  @override
  String get expenseNotesTitle => 'Notes de dépenses';

  @override
  String get createExpenseNoteTitle => 'Nouvelle dépense';

  @override
  String get searchExpenseHint => 'Rechercher par titre, catégorie ou description';

  @override
  String get noExpenseNotes => 'Aucune note de dépense';

  @override
  String get noExpenseNotesMatchSearch => 'Aucune note de dépense ne correspond à votre recherche';

  @override
  String get createYourFirstExpenseNoteToSeeItHere => 'Créez votre première note de dépense pour l’afficher ici';

  @override
  String get expenseNotePreviewTitleFallback => 'Note de dépense';

  @override
  String get expenseStatusUpdated => 'Statut de la dépense mis à jour avec succès';

  @override
  String get expenseNoteDeletedSuccess => 'Note de dépense supprimée avec succès';

  @override
  String get confirmDeleteTitle => 'Confirmer la suppression';

  @override
  String get confirmDeleteExpenseMessage => 'Êtes-vous sûr de vouloir supprimer cette note de dépense ?';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get statusPaid => 'Payé';

  @override
  String get statusUnpaid => 'Impayé';

  @override
  String get statusCancelled => 'Annulé';

  @override
  String get dateLabel => 'Date';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get editExpenseNoteTitle => 'Modifier la dépense';

  @override
  String get editExpenseNoteSubtitle => 'Mettez à jour les détails de la note de dépense.';

  @override
  String get expenseNoteUpdatedSuccess => 'Note de dépense mise à jour avec succès';

  @override
  String get statusPending => 'En attente';

  @override
  String get receiptPathLabel => 'Chemin du reçu';

  @override
  String get receiptPathHint => 'Saisir le chemin du fichier du reçu';

  @override
  String get updateButton => 'Mettre à jour';

  @override
  String get createExpenseNoteSubtitle => 'Ajoutez et suivez une nouvelle note de dépense.';

  @override
  String get expenseNoteCreatedSuccess => 'Note de dépense créée avec succès';

  @override
  String get title => 'Titre';

  @override
  String get amount => 'Montant';

  @override
  String get description => 'Description';

  @override
  String get invalidField => 'Valeur invalide';

  @override
  String get saveButton => 'Enregistrer';
}

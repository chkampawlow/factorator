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
  String get saveFailed => 'Échec de l’enregistrement';

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
  String get serverUnavailable => 'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get requestTimedOut => 'Le serveur met trop de temps à répondre. Veuillez réessayer.';

  @override
  String get accountingServerUpdateRequired => 'Le module de révision comptable n’est pas encore installé sur le serveur. Déployez la dernière version du backend, puis réessayez.';

  @override
  String get captureCenterTitle => 'Capture';

  @override
  String get captureCenterSubtitle => 'Scannez un document, choisissez des PDF/images ou recherchez un produit par code-barres.';

  @override
  String get captureTakePhoto => 'Prendre une photo';

  @override
  String get captureChooseFiles => 'Choisir des PDF ou images';

  @override
  String get captureScanBarcode => 'Scanner un code-barres produit';

  @override
  String get extractorTitle => 'Extracteur de documents';

  @override
  String get extractorReady => 'Choisissez jusqu’à 10 fichiers, puis lancez l’extraction.';

  @override
  String extractorSelectedFiles(int count) {
    return '$count fichier(s) sélectionné(s)';
  }

  @override
  String get extractorRun => 'Lancer l’extraction';

  @override
  String extractorUploading(int percent) {
    return 'Téléversement $percent%';
  }

  @override
  String get extractorProcessing => 'Téléversement terminé. Extraction des champs…';

  @override
  String get extractorReviewRequired => 'L’extraction ne valide jamais un document financier. Vérifiez chaque champ avant de créer un brouillon.';

  @override
  String extractorBatchSummary(int processed, int requested) {
    return '$processed fichier(s) traité(s) sur $requested';
  }

  @override
  String get extractorSuccessRate => 'Taux de réussite';

  @override
  String get extractorPages => 'Pages';

  @override
  String get extractorFailed => 'Échec de l’extraction';

  @override
  String get extractorReview => 'Vérifier les champs';

  @override
  String get extractorReviewTitle => 'Vérification humaine';

  @override
  String get extractorReviewSubtitle => 'Corrigez les valeurs extraites et choisissez le type de document prévu.';

  @override
  String get extractorDocumentType => 'Type de document';

  @override
  String get extractorExpense => 'Reçu de dépense';

  @override
  String get extractorSupplierInvoice => 'Facture fournisseur';

  @override
  String get extractorSupplierDelivery => 'Bon de livraison fournisseur';

  @override
  String get extractorPurchaseOrder => 'Bon de commande';

  @override
  String get extractorWarnings => 'Avertissements à vérifier';

  @override
  String get extractorLineItems => 'Lignes extraites';

  @override
  String get extractorNoLineItems => 'Aucune ligne n’a été détectée.';

  @override
  String extractorConfidence(int percent) {
    return 'Confiance : $percent%';
  }

  @override
  String get extractorConfirmReviewed => 'J’ai vérifié et corrigé les valeurs extraites.';

  @override
  String get extractorCreatePendingExpense => 'Préparer une dépense en attente';

  @override
  String get extractorDraftNotice => 'Un formulaire prérempli sera ouvert. Rien n’est enregistré avant votre vérification et votre envoi, et la nouvelle dépense commence toujours avec le statut en attente.';

  @override
  String get extractorDestinationNeedsWeb => 'Cette destination nécessite la correspondance officielle du fournisseur, de la commande, de la réception, des produits et du profil fiscal. Terminez-la dans l’espace Web pour le moment.';

  @override
  String get extractorPermissionDenied => 'Votre rôle peut capturer des documents, mais ne peut pas utiliser l’extracteur.';

  @override
  String get extractorExpensePermissionDenied => 'Votre rôle ne peut pas créer de notes de frais.';

  @override
  String get extractorServerUpdateRequired => 'L’extracteur n’est pas encore installé sur le serveur déployé.';

  @override
  String get extractorRemoveFile => 'Retirer le fichier';

  @override
  String get extractorRawText => 'Texte brut extrait';

  @override
  String get extractorFileLimits => 'PDF, PNG, JPG, TIFF, BMP ou WebP · 15 Mo par fichier · 50 Mo par lot';

  @override
  String get extractorNoFilesSelected => 'Choisissez au moins un PDF ou une image.';

  @override
  String get extractorExtractedData => 'Données extraites';

  @override
  String get extractorTaxAmount => 'Montant de la taxe';

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
  String get scanInvoiceTitle => 'Scanner facture';

  @override
  String get scanInvoiceSubtitle => 'Placez la facture dans le cadre. Ceci est seulement l’aperçu UI de la caméra.';

  @override
  String get scanInvoiceMode => 'Facture';

  @override
  String get scanInvoiceAlign => 'Alignez la facture dans le cadre';

  @override
  String get scanInvoiceGuideTitle => 'Guide de scan';

  @override
  String get scanInvoiceGuideLight => 'Utilisez une bonne lumière et évitez les ombres sur le papier.';

  @override
  String get scanInvoiceGuideEdges => 'Gardez tous les coins de la facture visibles dans le cadre.';

  @override
  String get scanInvoiceGuideReadable => 'Assurez-vous que les totaux et les informations fournisseur sont lisibles.';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get advanceInvoice => 'Facture d\'avance';

  @override
  String get advanceInvoiceComingSoon => 'Facture d\'avance : bientôt disponible';

  @override
  String get recentTransactions => 'Statistiques';

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
  String get invalidClientId => 'ID client invalide';

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
  String get deleteFailed => 'Échec de suppression';

  @override
  String get unnamedCustomer => 'Client sans nom';

  @override
  String get customers => 'Clients';

  @override
  String get refresh => 'Actualiser';

  @override
  String get add => 'Ajouter';

  @override
  String get searchNameMfCin => 'Rechercher par nom, MF ou CIN';

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
  String get overdue => 'en retard';

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
  String get fiscalIdMustMatch => 'Le matricule fiscal doit correspondre à 1234567A';

  @override
  String get passwordMinLength => 'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get pleaseConfirmPassword => 'Veuillez confirmer votre mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get accountCreatedSuccessfully => 'Compte créé avec succès';

  @override
  String get accountAwaitingApproval => 'Compte créé et en attente de l’approbation de l’administrateur.';

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
  String get fiscalIdFormat => 'Format : 1234567A';

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
  String get note => 'Note';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get paymentMethod => 'Méthode de paiement';

  @override
  String get paymentCash => 'Espèces';

  @override
  String get paymentCard => 'Carte';

  @override
  String get paymentTransfer => 'Virement';

  @override
  String get paymentCheck => 'Chèque';

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
  String get draftLabel => 'Brouillon';

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
  String get validateInvoice => 'Valider la facture';

  @override
  String get confirmValidateInvoiceTitle => 'Valider cette facture ?';

  @override
  String get confirmValidateInvoiceBody => 'Êtes-vous sûr de vouloir valider cette facture ? Vous ne pourrez plus la modifier après validation.';

  @override
  String get invoiceLockedAfterValidation => 'Cette facture est validée. Vous ne pouvez plus modifier, ajouter ou supprimer des articles.';

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
  String get statusRejected => 'Rejeté';

  @override
  String get markAsPending => 'Marquer comme en attente';

  @override
  String get markAsRejected => 'Marquer comme rejeté';

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

  @override
  String get notAuthenticated => 'Non authentifié';

  @override
  String currencyChangedTo(String currency) {
    return 'Devise changée vers $currency';
  }

  @override
  String languageChangedTo(String language) {
    return 'Langue changée vers $language';
  }

  @override
  String get companyInfoIncompleteTitle => 'Informations de l’entreprise incomplètes';

  @override
  String get companyInfoIncompleteBody => 'Veuillez compléter les informations de votre entreprise.';

  @override
  String get googleAuthenticator => 'Google Authenticator';

  @override
  String get enableTwoFactorAuthentication => 'Activer l’authentification à deux facteurs';

  @override
  String get monthlyExpenses => 'Dépenses mensuelles';

  @override
  String get netMonthlyRevenue => 'Revenu mensuel net';

  @override
  String get alertsTitle => 'Alertes';

  @override
  String get alertsSnackbars => 'Snackbars';

  @override
  String get alertsBanners => 'Bannières';

  @override
  String get alertsDialogs => 'Dialogues';

  @override
  String get alertsBottomSheets => 'Feuilles';

  @override
  String get alertSuccessTitle => 'Succès';

  @override
  String get alertSuccessBody => 'Enregistré avec succès.';

  @override
  String get alertInfoTitle => 'Information';

  @override
  String get alertInfoBody => 'Ceci est un message d’information.';

  @override
  String get alertWarningTitle => 'Avertissement';

  @override
  String get alertWarningBody => 'Vérifiez vos champs avant de continuer.';

  @override
  String get alertErrorTitle => 'Erreur';

  @override
  String get alertErrorBody => 'Une erreur s’est produite. Réessayez.';

  @override
  String get alertConfirmTitle => 'Confirmer l’action';

  @override
  String get alertConfirmBody => 'Voulez-vous continuer ?';

  @override
  String get alertBottomSheetTitle => 'Attention requise';

  @override
  String get alertBottomSheetBody => 'Vérifiez les détails avant d’enregistrer.';

  @override
  String get alertSavedBody => 'Modifications enregistrées.';

  @override
  String get alertUndo => 'Annuler';

  @override
  String get alertDismiss => 'Fermer';

  @override
  String get french => 'Français';

  @override
  String get english => 'Anglais';

  @override
  String get arabic => 'Arabe';

  @override
  String get checkingSession => 'Vérification de la session...';

  @override
  String get unitPcs => 'pcs (Pièces)';

  @override
  String get unitKg => 'kg (Kilogramme)';

  @override
  String get unitG => 'g (Gramme)';

  @override
  String get unitL => 'L (Litre)';

  @override
  String get unitM => 'm (Mètre)';

  @override
  String get unitH => 'h (Heure)';

  @override
  String get unitDay => 'jour';

  @override
  String get unitService => 'service';

  @override
  String get invalidPhoneNumber => 'Invalid phone number. Example: +216 20123456';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get newCustomer => 'Nouveau client';

  @override
  String get createCustomer => 'Créer un client';

  @override
  String get createFirstCustomerToSeeHere => 'Créez votre premier client pour l’afficher ici.';

  @override
  String get searchCustomerNameIdEmail => 'Rechercher client, identifiant, email...';

  @override
  String get companies => 'Entreprises';

  @override
  String get createYourFirstProduct => 'Créez votre premier produit pour commencer à ajouter des lignes à cette facture.';

  @override
  String get individuals => 'Particuliers';

  @override
  String get productAdded => 'Produit ajouté';

  @override
  String get deleteDraftInvoiceConfirm => 'Supprimer cette facture brouillon ? Cette action est irréversible.';

  @override
  String get invoiceDeleted => 'Facture supprimée.';

  @override
  String get mobileSearchHint => 'Rechercher clients, produits, documents…';

  @override
  String get enterTwoCharacters => 'Saisissez au moins 2 caractères';

  @override
  String get noPermittedResults => 'Aucun résultat autorisé';

  @override
  String get scanProduct => 'Scanner un produit';

  @override
  String get lookingUpBarcode => 'Recherche du code-barres';

  @override
  String get productNotFoundBarcode => 'Produit introuvable. Essayez un autre code-barres.';

  @override
  String get pointCameraBarcode => 'Dirigez la caméra vers le code-barres du produit';

  @override
  String get toggleTorch => 'Activer ou désactiver la lampe';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentSearchHint => 'Rechercher un numéro, client ou fournisseur';

  @override
  String get searchAction => 'Rechercher';

  @override
  String get allDocuments => 'Tous les documents';

  @override
  String get dates => 'Dates';

  @override
  String get clearDates => 'Effacer les dates';

  @override
  String get documentSourcesFailed => 'sources de documents n’ont pas pu être chargées.';

  @override
  String get noDocumentsFilters => 'Aucun document ne correspond à ces filtres.';

  @override
  String get cannotViewDocument => 'Vous ne pouvez pas consulter ce document.';

  @override
  String get cannotViewRelatedDocument => 'Vous ne pouvez pas consulter ce document lié.';

  @override
  String get previewOrSharePdf => 'Prévisualiser ou partager le PDF';

  @override
  String get relatedDocuments => 'Documents liés';

  @override
  String get lines => 'Lignes';

  @override
  String get party => 'Tiers';

  @override
  String get dueExpected => 'Échéance / prévue';

  @override
  String get balance => 'Solde';

  @override
  String get match => 'Rapprochement';

  @override
  String get sourceOrder => 'Commande source';

  @override
  String get invoiceNumber => 'Numéro de facture';

  @override
  String get deliveryNote => 'Bon de livraison';

  @override
  String get exception => 'Exception';

  @override
  String get exceptionReason => 'Motif de l’exception';

  @override
  String get source => 'Source';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get documentLine => 'Ligne de document';

  @override
  String get accepted => 'Acceptée';

  @override
  String get damaged => 'Endommagée';

  @override
  String get rejected => 'Rejetée';

  @override
  String get quantityShort => 'Qté';

  @override
  String get allStatuses => 'Tous les statuts';

  @override
  String get statusDraftMobile => 'Brouillon';

  @override
  String get statusOpen => 'Ouvert';

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusCancelledMobile => 'Annulé';

  @override
  String get kindInvoice => 'Facture';

  @override
  String get kindQuotation => 'Devis';

  @override
  String get kindCreditNote => 'Avoir';

  @override
  String get kindSalesOrder => 'Commande client';

  @override
  String get kindDeliveryNote => 'Bon de livraison';

  @override
  String get kindSupplierOrder => 'Commande fournisseur';

  @override
  String get kindSupplierReception => 'Réception fournisseur';

  @override
  String get kindSupplierInvoice => 'Facture fournisseur';

  @override
  String get kindExpense => 'Dépense';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get allNotificationsRead => 'Toutes les notifications ont été marquées comme lues.';

  @override
  String get notificationNoDestination => 'Cette notification n’a pas de destination mobile.';

  @override
  String get searchNotifications => 'Rechercher des notifications';

  @override
  String get unread => 'Non lues';

  @override
  String get read => 'Lues';

  @override
  String get allAreas => 'Tous les domaines';

  @override
  String get nothingNeedsAttention => 'Aucun élément ne nécessite votre attention.';

  @override
  String get notificationOptions => 'Options de notification';

  @override
  String get markUnread => 'Marquer comme non lue';

  @override
  String get markRead => 'Marquer comme lue';

  @override
  String get unreadNotifications => 'Notifications non lues';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get salesArea => 'Ventes';

  @override
  String get stockArea => 'Stock';

  @override
  String get logisticsArea => 'Logistique';

  @override
  String get purchasingArea => 'Achats';

  @override
  String get accountingArea => 'Comptabilité';

  @override
  String get financeReview => 'Revue financière';

  @override
  String get refreshBalances => 'Actualiser les soldes';

  @override
  String get noMobileDocumentLinked => 'Aucun document mobile n’est lié à cette entrée.';

  @override
  String get reviewTab => 'Revue';

  @override
  String get receivables => 'Créances clients';

  @override
  String get payables => 'Dettes fournisseurs';

  @override
  String get expensesTab => 'Dépenses';

  @override
  String get activityTab => 'Activité';

  @override
  String get searchPartyDocument => 'Rechercher un tiers ou un document';

  @override
  String get needsAttention => 'À vérifier';

  @override
  String get nothingReviewQueue => 'Aucun élément dans cette file de revue.';

  @override
  String get accountingAttentionQueue => 'File d’attention comptable';

  @override
  String get authoritativeBalances => 'Soldes de référence du serveur';

  @override
  String get updated => 'Mis à jour';

  @override
  String get expenseReview => 'Revue des dépenses';

  @override
  String get matchingIssues => 'Écarts de rapprochement';

  @override
  String get certificatesPending => 'certificats en attente';

  @override
  String get approveExpenses => 'Approuver les dépenses';

  @override
  String get viewExpenses => 'Voir les dépenses';

  @override
  String get yourFinanceAccess => 'Vos accès financiers';

  @override
  String get customerPaymentLedger => 'Registre des paiements clients';

  @override
  String get withholdingCertificates => 'Certificats de retenue';

  @override
  String get supplierPaymentRecording => 'Saisie des paiements fournisseurs';

  @override
  String get supplierCredits => 'Avoirs fournisseurs';

  @override
  String get supplierReturns => 'Retours fournisseurs';

  @override
  String get accountingReports => 'Rapports comptables';

  @override
  String get backendAmountsNotice => 'Les montants sont calculés par le serveur. La saisie et la validation utilisent toujours les workflows audités existants.';

  @override
  String get salesOrdersTitle => 'Commandes clients';

  @override
  String get deliveriesTitle => 'Livraisons';

  @override
  String get searchOrderClient => 'Rechercher une commande ou un client';

  @override
  String get searchDeliveryClientOrder => 'Rechercher une livraison, un client ou une commande';

  @override
  String get salesOrderLabel => 'Commande client';

  @override
  String get deliveryLabel => 'Livraison';

  @override
  String get sourceLabel => 'Source';

  @override
  String get itemsLabel => 'Articles';

  @override
  String get quantityLabel => 'Quantité';

  @override
  String get invoicesLabel => 'factures';

  @override
  String get deliveriesLabel => 'livraisons';

  @override
  String get confirmDelivery => 'Confirmer la livraison';

  @override
  String get markDelivered => 'Marquer comme livrée';

  @override
  String get cancelDelivery => 'Annuler la livraison';

  @override
  String get readyToInvoice => 'Prête à facturer';

  @override
  String get supplierReceptionsTitle => 'Réceptions fournisseurs';

  @override
  String get cannotCreateReception => 'Vous ne pouvez pas créer de réceptions fournisseurs.';

  @override
  String get noSupplierOrderAvailable => 'Aucune commande fournisseur envoyée ou partiellement reçue n’est disponible.';

  @override
  String get selectSupplierOrder => 'Sélectionner une commande fournisseur';

  @override
  String get purchaseOrder => 'Commande fournisseur';

  @override
  String get receiveOrder => 'Réceptionner une commande';

  @override
  String get searchSupplierOrderDocument => 'Rechercher un fournisseur, une commande ou un document';

  @override
  String get noSupplierReceptions => 'Aucune réception fournisseur trouvée.';

  @override
  String get receptionLabel => 'Réception';

  @override
  String get confirmSupplierReception => 'Confirmer la réception fournisseur ?';

  @override
  String get atomicStockNotice => 'Les quantités acceptées seront ajoutées au stock de façon atomique. La réception ne pourra plus être modifiée.';

  @override
  String get createLinkedExpense => 'Créer la dépense liée';

  @override
  String get confirmPostStock => 'Confirmer et comptabiliser le stock';

  @override
  String get receptionConfirmed => 'Réception confirmée.';

  @override
  String get productLinesPosted => 'ligne(s) produit comptabilisée(s) en stock.';

  @override
  String get receptionDetails => 'Détails de la réception';

  @override
  String get editDraft => 'Modifier le brouillon';

  @override
  String get stockPosted => 'Stock comptabilisé';

  @override
  String get stockPending => 'Stock en attente';

  @override
  String get supplierDeliveryNote => 'Bon de livraison fournisseur';

  @override
  String get supplierInvoice => 'Facture fournisseur';

  @override
  String get received => 'Reçu';

  @override
  String get receptionLines => 'Lignes de réception';

  @override
  String get totalHt => 'Total HT';

  @override
  String get vat => 'TVA';

  @override
  String get totalTtc => 'Total TTC';

  @override
  String get postingStock => 'Comptabilisation du stock…';

  @override
  String get editReception => 'Modifier la réception';

  @override
  String get newReception => 'Nouvelle réception';

  @override
  String get receptionWithoutOrder => 'Réception sans commande fournisseur';

  @override
  String get supplierInvoiceOptional => 'Numéro de facture fournisseur (facultatif)';

  @override
  String get supplierDeliveryNumber => 'Numéro du bon de livraison fournisseur';

  @override
  String get invoiceDate => 'Date de facture';

  @override
  String get receivedDate => 'Date de réception';

  @override
  String get deliveryDateOptional => 'Date du bon de livraison (facultatif)';

  @override
  String get notSet => 'Non définie';

  @override
  String get receivedQuantities => 'Quantités reçues';

  @override
  String get receptionException => 'Exception de réception';

  @override
  String get none => 'Aucune';

  @override
  String get overdelivery => 'Sur-livraison';

  @override
  String get noPurchaseOrder => 'Sans commande fournisseur';

  @override
  String get internalNotes => 'Notes internes';

  @override
  String get takeEvidencePhoto => 'Prendre une photo de preuve';

  @override
  String get chooseEvidencePhoto => 'Choisir une photo de preuve';

  @override
  String get couldNotSelectPhoto => 'Impossible de sélectionner la photo';

  @override
  String get negativeReceptionQuantities => 'Les quantités reçues ne peuvent pas être négatives.';

  @override
  String get enterReceivedQuantity => 'Saisissez une quantité reçue ou retirez la ligne.';

  @override
  String get discrepancyReasonRequired => 'Un motif d’écart est obligatoire.';

  @override
  String get selectReceptionLine => 'Sélectionnez au moins une ligne pour cette réception.';

  @override
  String get explainReceptionException => 'Expliquez l’exception de réception avant d’enregistrer.';

  @override
  String get evidenceUploadFailed => 'La réception est enregistrée, mais la photo de preuve n’a pas pu être envoyée.';

  @override
  String get receptionDraftSaved => 'Le brouillon de réception fournisseur est enregistré.';

  @override
  String get addDiscrepancyEvidence => 'Ajouter une preuve d’écart';

  @override
  String get evidenceFileHelp => 'JPEG, PNG ou WebP ; 10 Mo maximum';

  @override
  String get receptionTotals => 'Totaux de la réception';

  @override
  String get saveReceptionDraft => 'Enregistrer le brouillon';

  @override
  String get ordered => 'Commandé';

  @override
  String get remaining => 'Restant';

  @override
  String get discrepancyReason => 'Motif de l’écart';

  @override
  String get statusConfirmed => 'Confirmé';

  @override
  String get statusDelivered => 'Livré';

  @override
  String get statusInvoiced => 'Facturé';

  @override
  String get statusReviewed => 'Révisé';

  @override
  String get statusPartiallyDelivered => 'Partiellement livré';

  @override
  String get statusPartiallyReceived => 'Partiellement reçu';

  @override
  String get statusSent => 'Envoyé';

  @override
  String get supplierLabel => 'Fournisseur';

  @override
  String get more => 'Plus';

  @override
  String get noMobileFeatures => 'Aucune fonctionnalité mobile n’est attribuée à cet utilisateur.';
}

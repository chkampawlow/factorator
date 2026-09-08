import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select currency'**
  String get selectCurrency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @appColor.
  ///
  /// In en, this message translates to:
  /// **'App color'**
  String get appColor;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Fiscal identification number
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID'**
  String get fiscalId;

  /// No description provided for @noUserData.
  ///
  /// In en, this message translates to:
  /// **'No user data'**
  String get noUserData;

  /// No description provided for @logoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to logout?'**
  String get logoutQuestion;

  /// No description provided for @currencyChanged.
  ///
  /// In en, this message translates to:
  /// **'Currency changed to {value}'**
  String currencyChanged(String value);

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed to {value}'**
  String languageChanged(String value);

  /// No description provided for @clientUpdateApiNotAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Client update API not added yet'**
  String get clientUpdateApiNotAddedYet;

  /// No description provided for @clientAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Client added successfully'**
  String get clientAddedSuccessfully;

  /// No description provided for @clientAddedSuccessfullyWithId.
  ///
  /// In en, this message translates to:
  /// **'Client added successfully with ID: {id}'**
  String clientAddedSuccessfullyWithId(String id);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @fiscalIdMf.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID (MF)'**
  String get fiscalIdMf;

  /// No description provided for @cin.
  ///
  /// In en, this message translates to:
  /// **'CIN'**
  String get cin;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get editCustomer;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyName;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @mfRequired.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID required'**
  String get mfRequired;

  /// No description provided for @cinRequired.
  ///
  /// In en, this message translates to:
  /// **'CIN required'**
  String get cinRequired;

  /// No description provided for @cinTooShort.
  ///
  /// In en, this message translates to:
  /// **'CIN looks too short'**
  String get cinTooShort;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save Customer'**
  String get saveCustomer;

  /// No description provided for @newInvoice.
  ///
  /// In en, this message translates to:
  /// **'New Invoice'**
  String get newInvoice;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @createInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get createInvoice;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @chooseClientOrAddNew.
  ///
  /// In en, this message translates to:
  /// **'Choose client or add new'**
  String get chooseClientOrAddNew;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextStep;

  /// No description provided for @issueDateAutoToday.
  ///
  /// In en, this message translates to:
  /// **'The issue date will be set automatically to today ({date}). After creating the invoice, you will be redirected to the invoice detail screen where you can add invoice items.'**
  String issueDateAutoToday(String date);

  /// No description provided for @clientSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Client selection failed'**
  String get clientSelectionFailed;

  /// No description provided for @pleaseChooseClient.
  ///
  /// In en, this message translates to:
  /// **'Please choose a client.'**
  String get pleaseChooseClient;

  /// No description provided for @chooseClient.
  ///
  /// In en, this message translates to:
  /// **'Choose a client'**
  String get chooseClient;

  /// No description provided for @addNewClient.
  ///
  /// In en, this message translates to:
  /// **'Add new client'**
  String get addNewClient;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get loadFailed;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check your connection and try again.'**
  String get serverUnavailable;

  /// No description provided for @requestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get requestTimedOut;

  /// No description provided for @accountingServerUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Accounting Review is not installed on the server yet. Deploy the latest backend, then try again.'**
  String get accountingServerUpdateRequired;

  /// No description provided for @captureCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get captureCenterTitle;

  /// No description provided for @captureCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a document, choose PDF/images, or look up a product barcode.'**
  String get captureCenterSubtitle;

  /// No description provided for @captureTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get captureTakePhoto;

  /// No description provided for @captureChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF or images'**
  String get captureChooseFiles;

  /// No description provided for @captureScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan product barcode'**
  String get captureScanBarcode;

  /// No description provided for @extractorTitle.
  ///
  /// In en, this message translates to:
  /// **'Document extractor'**
  String get extractorTitle;

  /// No description provided for @extractorReady.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 10 files, then run extraction.'**
  String get extractorReady;

  /// No description provided for @extractorSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) selected'**
  String extractorSelectedFiles(int count);

  /// No description provided for @extractorRun.
  ///
  /// In en, this message translates to:
  /// **'Run extraction'**
  String get extractorRun;

  /// No description provided for @extractorUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String extractorUploading(int percent);

  /// No description provided for @extractorProcessing.
  ///
  /// In en, this message translates to:
  /// **'Upload complete. Extracting document fields…'**
  String get extractorProcessing;

  /// No description provided for @extractorReviewRequired.
  ///
  /// In en, this message translates to:
  /// **'Extraction never validates a financial document. Review every field before creating a draft.'**
  String get extractorReviewRequired;

  /// No description provided for @extractorBatchSummary.
  ///
  /// In en, this message translates to:
  /// **'{processed} of {requested} file(s) processed'**
  String extractorBatchSummary(int processed, int requested);

  /// No description provided for @extractorSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Success rate'**
  String get extractorSuccessRate;

  /// No description provided for @extractorPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get extractorPages;

  /// No description provided for @extractorFailed.
  ///
  /// In en, this message translates to:
  /// **'Extraction failed'**
  String get extractorFailed;

  /// No description provided for @extractorReview.
  ///
  /// In en, this message translates to:
  /// **'Review fields'**
  String get extractorReview;

  /// No description provided for @extractorReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Human review'**
  String get extractorReviewTitle;

  /// No description provided for @extractorReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Correct extracted values and choose the intended document type.'**
  String get extractorReviewSubtitle;

  /// No description provided for @extractorDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get extractorDocumentType;

  /// No description provided for @extractorExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense receipt'**
  String get extractorExpense;

  /// No description provided for @extractorSupplierInvoice.
  ///
  /// In en, this message translates to:
  /// **'Supplier invoice'**
  String get extractorSupplierInvoice;

  /// No description provided for @extractorSupplierDelivery.
  ///
  /// In en, this message translates to:
  /// **'Supplier delivery document'**
  String get extractorSupplierDelivery;

  /// No description provided for @extractorPurchaseOrder.
  ///
  /// In en, this message translates to:
  /// **'Purchase order'**
  String get extractorPurchaseOrder;

  /// No description provided for @extractorWarnings.
  ///
  /// In en, this message translates to:
  /// **'Review warnings'**
  String get extractorWarnings;

  /// No description provided for @extractorLineItems.
  ///
  /// In en, this message translates to:
  /// **'Extracted line items'**
  String get extractorLineItems;

  /// No description provided for @extractorNoLineItems.
  ///
  /// In en, this message translates to:
  /// **'No line items were detected.'**
  String get extractorNoLineItems;

  /// No description provided for @extractorConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percent}%'**
  String extractorConfidence(int percent);

  /// No description provided for @extractorConfirmReviewed.
  ///
  /// In en, this message translates to:
  /// **'I reviewed and corrected the extracted values.'**
  String get extractorConfirmReviewed;

  /// No description provided for @extractorCreatePendingExpense.
  ///
  /// In en, this message translates to:
  /// **'Prepare pending expense'**
  String get extractorCreatePendingExpense;

  /// No description provided for @extractorDraftNotice.
  ///
  /// In en, this message translates to:
  /// **'This opens a prefilled form. Nothing is saved until you review and submit it, and the new expense always starts as pending.'**
  String get extractorDraftNotice;

  /// No description provided for @extractorDestinationNeedsWeb.
  ///
  /// In en, this message translates to:
  /// **'This destination needs authoritative supplier, order, reception, product, and tax-profile matching. Complete it in the web workspace for now.'**
  String get extractorDestinationNeedsWeb;

  /// No description provided for @extractorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Your role can capture documents but cannot use the extractor.'**
  String get extractorPermissionDenied;

  /// No description provided for @extractorExpensePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot create expense notes.'**
  String get extractorExpensePermissionDenied;

  /// No description provided for @extractorServerUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'The extractor is not installed on the deployed server yet.'**
  String get extractorServerUpdateRequired;

  /// No description provided for @extractorRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get extractorRemoveFile;

  /// No description provided for @extractorRawText.
  ///
  /// In en, this message translates to:
  /// **'Raw extracted text'**
  String get extractorRawText;

  /// No description provided for @extractorFileLimits.
  ///
  /// In en, this message translates to:
  /// **'PDF, PNG, JPG, TIFF, BMP or WebP · 15 MB per file · 50 MB per batch'**
  String get extractorFileLimits;

  /// No description provided for @extractorNoFilesSelected.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one PDF or image.'**
  String get extractorNoFilesSelected;

  /// No description provided for @extractorExtractedData.
  ///
  /// In en, this message translates to:
  /// **'Extracted data'**
  String get extractorExtractedData;

  /// No description provided for @extractorTaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Tax amount'**
  String get extractorTaxAmount;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @priceAndTvaMustBeValidNumbers.
  ///
  /// In en, this message translates to:
  /// **'Price and TVA must be valid numbers.'**
  String get priceAndTvaMustBeValidNumbers;

  /// No description provided for @invalidProductId.
  ///
  /// In en, this message translates to:
  /// **'Invalid product id'**
  String get invalidProductId;

  /// No description provided for @productUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully'**
  String get productUpdatedSuccessfully;

  /// No description provided for @productSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product saved successfully'**
  String get productSavedSuccessfully;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get saveProduct;

  /// No description provided for @updateProductDetails.
  ///
  /// In en, this message translates to:
  /// **'Update product details'**
  String get updateProductDetails;

  /// No description provided for @createNewProductOrService.
  ///
  /// In en, this message translates to:
  /// **'Create a new product or service'**
  String get createNewProductOrService;

  /// No description provided for @codeOptional.
  ///
  /// In en, this message translates to:
  /// **'Code (optional)'**
  String get codeOptional;

  /// No description provided for @productCodeExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. PRD-001'**
  String get productCodeExample;

  /// No description provided for @productServiceName.
  ///
  /// In en, this message translates to:
  /// **'Product / Service name'**
  String get productServiceName;

  /// No description provided for @productServiceNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Web design, Consulting...'**
  String get productServiceNameExample;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @priceExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 120 or 120,50'**
  String get priceExample;

  /// No description provided for @tvaPercent.
  ///
  /// In en, this message translates to:
  /// **'TVA %'**
  String get tvaPercent;

  /// No description provided for @tvaExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 19'**
  String get tvaExample;

  /// No description provided for @unitOptional.
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get unitOptional;

  /// No description provided for @unitExample.
  ///
  /// In en, this message translates to:
  /// **'hour / piece / kg...'**
  String get unitExample;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @scanInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan invoice'**
  String get scanInvoiceTitle;

  /// No description provided for @scanInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Place the invoice inside the frame. This is the camera UI preview.'**
  String get scanInvoiceSubtitle;

  /// No description provided for @scanInvoiceMode.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get scanInvoiceMode;

  /// No description provided for @scanInvoiceAlign.
  ///
  /// In en, this message translates to:
  /// **'Align the invoice inside the frame'**
  String get scanInvoiceAlign;

  /// No description provided for @scanInvoiceGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan guide'**
  String get scanInvoiceGuideTitle;

  /// No description provided for @scanInvoiceGuideLight.
  ///
  /// In en, this message translates to:
  /// **'Use good light and avoid shadows on the paper.'**
  String get scanInvoiceGuideLight;

  /// No description provided for @scanInvoiceGuideEdges.
  ///
  /// In en, this message translates to:
  /// **'Keep all invoice corners visible in the frame.'**
  String get scanInvoiceGuideEdges;

  /// No description provided for @scanInvoiceGuideReadable.
  ///
  /// In en, this message translates to:
  /// **'Make sure totals and supplier details are readable.'**
  String get scanInvoiceGuideReadable;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @advanceInvoice.
  ///
  /// In en, this message translates to:
  /// **'Advance invoice'**
  String get advanceInvoice;

  /// No description provided for @advanceInvoiceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Advance invoice: coming soon'**
  String get advanceInvoiceComingSoon;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get recentTransactions;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get noInvoicesYet;

  /// No description provided for @failedToLoadCustomers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load customers'**
  String get failedToLoadCustomers;

  /// No description provided for @mfLabel.
  ///
  /// In en, this message translates to:
  /// **'MF'**
  String get mfLabel;

  /// No description provided for @missingClientId.
  ///
  /// In en, this message translates to:
  /// **'Missing client id'**
  String get missingClientId;

  /// No description provided for @invalidClientId.
  ///
  /// In en, this message translates to:
  /// **'Invalid client id'**
  String get invalidClientId;

  /// No description provided for @deleteCustomerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete customer?'**
  String get deleteCustomerQuestion;

  /// No description provided for @areYouSureDeleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String areYouSureDeleteCustomer(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @customerDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Customer deleted successfully'**
  String get customerDeletedSuccessfully;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get deleteFailed;

  /// No description provided for @unnamedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Unnamed customer'**
  String get unnamedCustomer;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @searchNameMfCin.
  ///
  /// In en, this message translates to:
  /// **'Search by name, MF or CIN'**
  String get searchNameMfCin;

  /// No description provided for @allCustomers.
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get allCustomers;

  /// No description provided for @noCustomersYet.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get noCustomersYet;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @issue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get issue;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get fill;

  /// No description provided for @previewPdf.
  ///
  /// In en, this message translates to:
  /// **'Preview PDF'**
  String get previewPdf;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @invoiceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invoice not found.'**
  String get invoiceNotFound;

  /// No description provided for @addAtLeastOneItemBeforePreviewPdf.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item before previewing the PDF.'**
  String get addAtLeastOneItemBeforePreviewPdf;

  /// No description provided for @qtyMustBeGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Qty must be > 0'**
  String get qtyMustBeGreaterThanZero;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'Item added'**
  String get itemAdded;

  /// No description provided for @itemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get itemDeleted;

  /// No description provided for @itemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item updated'**
  String get itemUpdated;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get deleteItem;

  /// No description provided for @removeThisItemFromInvoice.
  ///
  /// In en, this message translates to:
  /// **'Remove this item from the invoice?'**
  String get removeThisItemFromInvoice;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'Discount (%)'**
  String get discountPercent;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @priceOverride.
  ///
  /// In en, this message translates to:
  /// **'Price override'**
  String get priceOverride;

  /// No description provided for @addToInvoice.
  ///
  /// In en, this message translates to:
  /// **'Add to invoice'**
  String get addToInvoice;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet.'**
  String get noItemsYet;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'overdue'**
  String get overdue;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Indicatif'**
  String get code;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @doc.
  ///
  /// In en, this message translates to:
  /// **'Doc'**
  String get doc;

  /// No description provided for @issued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get issued;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} day{suffix}'**
  String dueInDays(String days, String suffix);

  /// No description provided for @overdueByDays.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {days} day{suffix}'**
  String overdueByDays(String days, String suffix);

  /// No description provided for @createYourFirstInvoiceToSeeItHere.
  ///
  /// In en, this message translates to:
  /// **'Create your first invoice to see it here.'**
  String get createYourFirstInvoiceToSeeItHere;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @loginToManageApp.
  ///
  /// In en, this message translates to:
  /// **'Login to manage your clients, products and invoices.'**
  String get loginToManageApp;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @minimum6Characters.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get minimum6Characters;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login success'**
  String get loginSuccess;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome {name}'**
  String welcomeUser(String name);

  /// No description provided for @productsServices.
  ///
  /// In en, this message translates to:
  /// **'Products / Services'**
  String get productsServices;

  /// No description provided for @searchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search (name / code / unit / TVA)...'**
  String get searchProductsHint;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @deleteProductQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete product?'**
  String get deleteProductQuestion;

  /// No description provided for @areYouSureDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String areYouSureDeleteProduct(String name);

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted ✅'**
  String get productDeleted;

  /// No description provided for @unnamedProduct.
  ///
  /// In en, this message translates to:
  /// **'Unnamed product'**
  String get unnamedProduct;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get lastNameRequired;

  /// No description provided for @fiscalIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID is required'**
  String get fiscalIdRequired;

  /// No description provided for @fiscalIdMustMatch.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID must match 1234567A'**
  String get fiscalIdMustMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get accountCreatedSuccessfully;

  /// No description provided for @accountAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Account created and awaiting administrator approval.'**
  String get accountAwaitingApproval;

  /// No description provided for @whoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get whoAreYou;

  /// No description provided for @startWithPersonalInformation.
  ///
  /// In en, this message translates to:
  /// **'Start with your personal information.'**
  String get startWithPersonalInformation;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @companyDetails.
  ///
  /// In en, this message translates to:
  /// **'Company details'**
  String get companyDetails;

  /// No description provided for @addOrganizationAndFiscalInfo.
  ///
  /// In en, this message translates to:
  /// **'Add your organization and fiscal information.'**
  String get addOrganizationAndFiscalInfo;

  /// Company or organization name field
  ///
  /// In en, this message translates to:
  /// **'Organization name'**
  String get organizationName;

  /// No description provided for @fiscalIdRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID*'**
  String get fiscalIdRequiredLabel;

  /// No description provided for @fiscalIdFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: 1234567A'**
  String get fiscalIdFormat;

  /// No description provided for @contactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get contactInformation;

  /// No description provided for @howCanWeReachYou.
  ///
  /// In en, this message translates to:
  /// **'How can we reach you?'**
  String get howCanWeReachYou;

  /// No description provided for @emailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddressLabel;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @secureYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get secureYourAccount;

  /// No description provided for @chooseStrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password.'**
  String get chooseStrongPassword;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @reviewAndCreate.
  ///
  /// In en, this message translates to:
  /// **'Review & create'**
  String get reviewAndCreate;

  /// No description provided for @reviewBeforeCreate.
  ///
  /// In en, this message translates to:
  /// **'Make sure everything looks good before creating the account.'**
  String get reviewBeforeCreate;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @fiscalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Fiscal ID'**
  String get fiscalIdLabel;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @invalidFiscalId.
  ///
  /// In en, this message translates to:
  /// **'Invalid fiscal ID'**
  String get invalidFiscalId;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get phoneNumberInvalid;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @searchProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product'**
  String get searchProduct;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select product'**
  String get selectProduct;

  /// Title for company information dialog
  ///
  /// In en, this message translates to:
  /// **'Company information'**
  String get companyInformation;

  /// Company fax number
  ///
  /// In en, this message translates to:
  /// **'Fax'**
  String get fax;

  /// Company address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Company website
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// Shown after updating company info
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// Shown after updating profile picture
  ///
  /// In en, this message translates to:
  /// **'Profile image updated'**
  String get profileImageUpdated;

  /// Instruction under profile picture
  ///
  /// In en, this message translates to:
  /// **'Tap image to change photo'**
  String get tapImageToChangePhoto;

  /// User region
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// Generic label for a person's or client's name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Generic identifier label when neither fiscal ID nor CIN is available
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get identifier;

  /// Notes section title in invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Short invoice note button label
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// Button and hint used to add an invoice note
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// Payment method selection title
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentTransfer;

  /// No description provided for @paymentCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get paymentCheck;

  /// Subtotal label in invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// Total label in invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmail;

  /// No description provided for @verifyEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email before continuing. Enter the 6-digit code or resend the email.'**
  String get verifyEmailDescription;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @verifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify now'**
  String get verifyNow;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @resendEmailIn.
  ///
  /// In en, this message translates to:
  /// **'Resend email in {seconds}s'**
  String resendEmailIn(int seconds);

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent'**
  String get verificationEmailSent;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get enterVerificationCode;

  /// No description provided for @emailVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully'**
  String get emailVerifiedSuccessfully;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a 6-digit code to reset your password.'**
  String get forgotPasswordDescription;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetCode;

  /// No description provided for @resetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Reset code sent'**
  String get resetCodeSent;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code and your new password.'**
  String get resetPasswordDescription;

  /// No description provided for @enterResetCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the reset code'**
  String get enterResetCode;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordResetSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful'**
  String get passwordResetSuccessful;

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app for {email}.'**
  String twoFactorSubtitle(Object email);

  /// No description provided for @twoFactorCode.
  ///
  /// In en, this message translates to:
  /// **'Authentication code'**
  String get twoFactorCode;

  /// No description provided for @twoFactorCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication code is required'**
  String get twoFactorCodeRequired;

  /// No description provided for @twoFactorCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit code'**
  String get twoFactorCodeInvalid;

  /// No description provided for @twoFactorHint.
  ///
  /// In en, this message translates to:
  /// **'Open Google Authenticator and enter the current 6-digit code.'**
  String get twoFactorHint;

  /// No description provided for @twoFactorVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get twoFactorVerify;

  /// No description provided for @twoFactorBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get twoFactorBack;

  /// No description provided for @twoFactorSuccess.
  ///
  /// In en, this message translates to:
  /// **'Two-factor verification successful'**
  String get twoFactorSuccess;

  /// No description provided for @twoFactorSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Authenticator'**
  String get twoFactorSetupTitle;

  /// No description provided for @twoFactorSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up two-factor authentication to better protect your account.'**
  String get twoFactorSetupSubtitle;

  /// No description provided for @twoFactorStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1'**
  String get twoFactorStep1;

  /// No description provided for @twoFactorScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code with Google Authenticator or enter the manual key below.'**
  String get twoFactorScanQr;

  /// No description provided for @twoFactorManualKey.
  ///
  /// In en, this message translates to:
  /// **'Manual key'**
  String get twoFactorManualKey;

  /// No description provided for @twoFactorManualKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Manual key unavailable'**
  String get twoFactorManualKeyUnavailable;

  /// No description provided for @twoFactorQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR code unavailable'**
  String get twoFactorQrUnavailable;

  /// No description provided for @twoFactorStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2'**
  String get twoFactorStep2;

  /// No description provided for @twoFactorEnterSetupCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code generated by your authenticator app.'**
  String get twoFactorEnterSetupCode;

  /// No description provided for @twoFactorEnableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA'**
  String get twoFactorEnableButton;

  /// No description provided for @twoFactorEnabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication enabled successfully'**
  String get twoFactorEnabledSuccess;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @twoFactorDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable two-factor authentication'**
  String get twoFactorDisableTitle;

  /// No description provided for @twoFactorDisableMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disable Google Authenticator for this account?'**
  String get twoFactorDisableMessage;

  /// No description provided for @twoFactorDisableButton.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get twoFactorDisableButton;

  /// No description provided for @twoFactorDisableCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter disable code'**
  String get twoFactorDisableCodeTitle;

  /// No description provided for @twoFactorDisabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication disabled successfully'**
  String get twoFactorDisabledSuccess;

  /// No description provided for @twoFactorToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Authenticator'**
  String get twoFactorToggleTitle;

  /// No description provided for @twoFactorToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is enabled'**
  String get twoFactorToggleOn;

  /// No description provided for @twoFactorToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is disabled'**
  String get twoFactorToggleOff;

  /// No description provided for @twoFactorLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking two-factor authentication status...'**
  String get twoFactorLoadingStatus;

  /// No description provided for @twoFactorDisabling.
  ///
  /// In en, this message translates to:
  /// **'Disabling two-factor authentication...'**
  String get twoFactorDisabling;

  /// No description provided for @twoFactorPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing two-factor authentication...'**
  String get twoFactorPreparing;

  /// No description provided for @twoFactorManualKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Manual key copied'**
  String get twoFactorManualKeyCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @monthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get monthlyRevenue;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @averageInvoice.
  ///
  /// In en, this message translates to:
  /// **'Average Invoice'**
  String get averageInvoice;

  /// No description provided for @topClients.
  ///
  /// In en, this message translates to:
  /// **'Top Clients'**
  String get topClients;

  /// No description provided for @revenueCurve.
  ///
  /// In en, this message translates to:
  /// **'Revenue Curve'**
  String get revenueCurve;

  /// No description provided for @paidVsUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Paid vs Unpaid'**
  String get paidVsUnpaid;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @paidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// No description provided for @unpaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaidLabel;

  /// No description provided for @paymentRate.
  ///
  /// In en, this message translates to:
  /// **'Payment Rate'**
  String get paymentRate;

  /// No description provided for @growthCurve.
  ///
  /// In en, this message translates to:
  /// **'Growth Curve'**
  String get growthCurve;

  /// No description provided for @draftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftLabel;

  /// No description provided for @cancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledLabel;

  /// No description provided for @searchInvoiceClientEmail.
  ///
  /// In en, this message translates to:
  /// **'Search invoice, client, email...'**
  String get searchInvoiceClientEmail;

  /// No description provided for @noInvoicesMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No invoices match your search'**
  String get noInvoicesMatchSearch;

  /// No description provided for @changeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get changeStatus;

  /// No description provided for @markAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get markAsPaid;

  /// No description provided for @markAsUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as unpaid'**
  String get markAsUnpaid;

  /// No description provided for @validateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Validate invoice'**
  String get validateInvoice;

  /// No description provided for @confirmValidateInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Validate this invoice?'**
  String get confirmValidateInvoiceTitle;

  /// No description provided for @confirmValidateInvoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to validate this invoice? You cannot modify it after validating.'**
  String get confirmValidateInvoiceBody;

  /// No description provided for @invoiceLockedAfterValidation.
  ///
  /// In en, this message translates to:
  /// **'This invoice is validated. You can no longer modify, add, or delete items.'**
  String get invoiceLockedAfterValidation;

  /// No description provided for @markAsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Mark as cancelled'**
  String get markAsCancelled;

  /// No description provided for @invoiceStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Invoice status updated'**
  String get invoiceStatusUpdated;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @dueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueSoon;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @expenseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense Notes'**
  String get expenseNotesTitle;

  /// No description provided for @createExpenseNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get createExpenseNoteTitle;

  /// No description provided for @searchExpenseHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title, category or description'**
  String get searchExpenseHint;

  /// No description provided for @noExpenseNotes.
  ///
  /// In en, this message translates to:
  /// **'No expense notes yet'**
  String get noExpenseNotes;

  /// No description provided for @noExpenseNotesMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No expense notes match your search'**
  String get noExpenseNotesMatchSearch;

  /// No description provided for @createYourFirstExpenseNoteToSeeItHere.
  ///
  /// In en, this message translates to:
  /// **'Create your first expense note to see it here'**
  String get createYourFirstExpenseNoteToSeeItHere;

  /// No description provided for @expenseNotePreviewTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Expense Note'**
  String get expenseNotePreviewTitleFallback;

  /// No description provided for @expenseStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Expense status updated successfully'**
  String get expenseStatusUpdated;

  /// No description provided for @expenseNoteDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense note deleted successfully'**
  String get expenseNoteDeletedSuccess;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteExpenseMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this expense note?'**
  String get confirmDeleteExpenseMessage;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get statusUnpaid;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @markAsPending.
  ///
  /// In en, this message translates to:
  /// **'Mark as pending'**
  String get markAsPending;

  /// No description provided for @markAsRejected.
  ///
  /// In en, this message translates to:
  /// **'Mark as rejected'**
  String get markAsRejected;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @editExpenseNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get editExpenseNoteTitle;

  /// No description provided for @editExpenseNoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your expense note details.'**
  String get editExpenseNoteSubtitle;

  /// No description provided for @expenseNoteUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense note updated successfully'**
  String get expenseNoteUpdatedSuccess;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @receiptPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt path'**
  String get receiptPathLabel;

  /// No description provided for @receiptPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter receipt file path'**
  String get receiptPathHint;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @createExpenseNoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add and track a new expense note.'**
  String get createExpenseNoteSubtitle;

  /// No description provided for @expenseNoteCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense note created successfully'**
  String get expenseNoteCreatedSuccess;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @invalidField.
  ///
  /// In en, this message translates to:
  /// **'Invalid value'**
  String get invalidField;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @currencyChangedTo.
  ///
  /// In en, this message translates to:
  /// **'Currency changed to {currency}'**
  String currencyChangedTo(String currency);

  /// No description provided for @languageChangedTo.
  ///
  /// In en, this message translates to:
  /// **'Language changed to {language}'**
  String languageChangedTo(String language);

  /// No description provided for @companyInfoIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Company information is incomplete'**
  String get companyInfoIncompleteTitle;

  /// No description provided for @companyInfoIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Please complete your company information.'**
  String get companyInfoIncompleteBody;

  /// No description provided for @googleAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Google Authenticator'**
  String get googleAuthenticator;

  /// No description provided for @enableTwoFactorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Enable two-factor authentication'**
  String get enableTwoFactorAuthentication;

  /// No description provided for @monthlyExpenses.
  ///
  /// In en, this message translates to:
  /// **'Monthly expenses'**
  String get monthlyExpenses;

  /// No description provided for @netMonthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net monthly revenue'**
  String get netMonthlyRevenue;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsSnackbars.
  ///
  /// In en, this message translates to:
  /// **'Snackbars'**
  String get alertsSnackbars;

  /// No description provided for @alertsBanners.
  ///
  /// In en, this message translates to:
  /// **'Banners'**
  String get alertsBanners;

  /// No description provided for @alertsDialogs.
  ///
  /// In en, this message translates to:
  /// **'Dialogs'**
  String get alertsDialogs;

  /// No description provided for @alertsBottomSheets.
  ///
  /// In en, this message translates to:
  /// **'Bottom sheets'**
  String get alertsBottomSheets;

  /// No description provided for @alertSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get alertSuccessTitle;

  /// No description provided for @alertSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully.'**
  String get alertSuccessBody;

  /// No description provided for @alertInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get alertInfoTitle;

  /// No description provided for @alertInfoBody.
  ///
  /// In en, this message translates to:
  /// **'This is an informational message.'**
  String get alertInfoBody;

  /// No description provided for @alertWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get alertWarningTitle;

  /// No description provided for @alertWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Check your inputs before continuing.'**
  String get alertWarningBody;

  /// No description provided for @alertErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get alertErrorTitle;

  /// No description provided for @alertErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get alertErrorBody;

  /// No description provided for @alertConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm action'**
  String get alertConfirmTitle;

  /// No description provided for @alertConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to continue?'**
  String get alertConfirmBody;

  /// No description provided for @alertBottomSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Attention required'**
  String get alertBottomSheetTitle;

  /// No description provided for @alertBottomSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Review the details before saving.'**
  String get alertBottomSheetBody;

  /// No description provided for @alertSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Changes saved.'**
  String get alertSavedBody;

  /// No description provided for @alertUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get alertUndo;

  /// No description provided for @alertDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get alertDismiss;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @checkingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking session...'**
  String get checkingSession;

  /// No description provided for @unitPcs.
  ///
  /// In en, this message translates to:
  /// **'pcs (Pieces)'**
  String get unitPcs;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg (Kilogram)'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g (Gram)'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'L (Liter)'**
  String get unitL;

  /// No description provided for @unitM.
  ///
  /// In en, this message translates to:
  /// **'m (Meter)'**
  String get unitM;

  /// No description provided for @unitH.
  ///
  /// In en, this message translates to:
  /// **'h (Hour)'**
  String get unitH;

  /// No description provided for @unitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get unitDay;

  /// No description provided for @unitService.
  ///
  /// In en, this message translates to:
  /// **'service'**
  String get unitService;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Numéro invalide. Exemple : +216 20123456'**
  String get invalidPhoneNumber;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @newCustomer.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get newCustomer;

  /// No description provided for @createCustomer.
  ///
  /// In en, this message translates to:
  /// **'Create Customer'**
  String get createCustomer;

  /// No description provided for @createFirstCustomerToSeeHere.
  ///
  /// In en, this message translates to:
  /// **'Create your first customer to see it here.'**
  String get createFirstCustomerToSeeHere;

  /// No description provided for @searchCustomerNameIdEmail.
  ///
  /// In en, this message translates to:
  /// **'Search customer, ID, email...'**
  String get searchCustomerNameIdEmail;

  /// No description provided for @companies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companies;

  /// No description provided for @createYourFirstProduct.
  ///
  /// In en, this message translates to:
  /// **'Create your first product to start adding items to this invoice.'**
  String get createYourFirstProduct;

  /// No description provided for @individuals.
  ///
  /// In en, this message translates to:
  /// **'Individuals'**
  String get individuals;

  /// No description provided for @productAdded.
  ///
  /// In en, this message translates to:
  /// **'Product added'**
  String get productAdded;

  /// No description provided for @deleteDraftInvoiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this draft invoice? This action cannot be undone.'**
  String get deleteDraftInvoiceConfirm;

  /// No description provided for @invoiceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Invoice deleted.'**
  String get invoiceDeleted;

  /// No description provided for @mobileSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search clients, products, documents…'**
  String get mobileSearchHint;

  /// No description provided for @enterTwoCharacters.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters'**
  String get enterTwoCharacters;

  /// No description provided for @noPermittedResults.
  ///
  /// In en, this message translates to:
  /// **'No permitted results found'**
  String get noPermittedResults;

  /// No description provided for @scanProduct.
  ///
  /// In en, this message translates to:
  /// **'Scan product'**
  String get scanProduct;

  /// No description provided for @lookingUpBarcode.
  ///
  /// In en, this message translates to:
  /// **'Looking up barcode'**
  String get lookingUpBarcode;

  /// No description provided for @productNotFoundBarcode.
  ///
  /// In en, this message translates to:
  /// **'Product not found. Try another barcode.'**
  String get productNotFoundBarcode;

  /// No description provided for @pointCameraBarcode.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a product barcode'**
  String get pointCameraBarcode;

  /// No description provided for @toggleTorch.
  ///
  /// In en, this message translates to:
  /// **'Toggle flashlight'**
  String get toggleTorch;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search number, client or supplier'**
  String get documentSearchHint;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// No description provided for @allDocuments.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get allDocuments;

  /// No description provided for @dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get dates;

  /// No description provided for @clearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get clearDates;

  /// No description provided for @documentSourcesFailed.
  ///
  /// In en, this message translates to:
  /// **'document sources could not be loaded.'**
  String get documentSourcesFailed;

  /// No description provided for @noDocumentsFilters.
  ///
  /// In en, this message translates to:
  /// **'No documents match these filters.'**
  String get noDocumentsFilters;

  /// No description provided for @cannotViewDocument.
  ///
  /// In en, this message translates to:
  /// **'You cannot view this document.'**
  String get cannotViewDocument;

  /// No description provided for @cannotViewRelatedDocument.
  ///
  /// In en, this message translates to:
  /// **'You cannot view this related document.'**
  String get cannotViewRelatedDocument;

  /// No description provided for @previewOrSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Preview or share PDF'**
  String get previewOrSharePdf;

  /// No description provided for @relatedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Related documents'**
  String get relatedDocuments;

  /// No description provided for @lines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get lines;

  /// No description provided for @party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get party;

  /// No description provided for @dueExpected.
  ///
  /// In en, this message translates to:
  /// **'Due / expected'**
  String get dueExpected;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @match.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get match;

  /// No description provided for @sourceOrder.
  ///
  /// In en, this message translates to:
  /// **'Source order'**
  String get sourceOrder;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @deliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Delivery note'**
  String get deliveryNote;

  /// No description provided for @exception.
  ///
  /// In en, this message translates to:
  /// **'Exception'**
  String get exception;

  /// No description provided for @exceptionReason.
  ///
  /// In en, this message translates to:
  /// **'Exception reason'**
  String get exceptionReason;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @documentLine.
  ///
  /// In en, this message translates to:
  /// **'Document line'**
  String get documentLine;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @damaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get damaged;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @quantityShort.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantityShort;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @statusDraftMobile.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraftMobile;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelledMobile.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelledMobile;

  /// No description provided for @kindInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get kindInvoice;

  /// No description provided for @kindQuotation.
  ///
  /// In en, this message translates to:
  /// **'Quotation'**
  String get kindQuotation;

  /// No description provided for @kindCreditNote.
  ///
  /// In en, this message translates to:
  /// **'Credit note'**
  String get kindCreditNote;

  /// No description provided for @kindSalesOrder.
  ///
  /// In en, this message translates to:
  /// **'Sales order'**
  String get kindSalesOrder;

  /// No description provided for @kindDeliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Delivery note'**
  String get kindDeliveryNote;

  /// No description provided for @kindSupplierOrder.
  ///
  /// In en, this message translates to:
  /// **'Supplier PO'**
  String get kindSupplierOrder;

  /// No description provided for @kindSupplierReception.
  ///
  /// In en, this message translates to:
  /// **'Supplier reception'**
  String get kindSupplierReception;

  /// No description provided for @kindSupplierInvoice.
  ///
  /// In en, this message translates to:
  /// **'Supplier invoice'**
  String get kindSupplierInvoice;

  /// No description provided for @kindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get kindExpense;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @allNotificationsRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read.'**
  String get allNotificationsRead;

  /// No description provided for @notificationNoDestination.
  ///
  /// In en, this message translates to:
  /// **'This notification has no mobile destination.'**
  String get notificationNoDestination;

  /// No description provided for @searchNotifications.
  ///
  /// In en, this message translates to:
  /// **'Search notifications'**
  String get searchNotifications;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @allAreas.
  ///
  /// In en, this message translates to:
  /// **'All areas'**
  String get allAreas;

  /// No description provided for @nothingNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention.'**
  String get nothingNeedsAttention;

  /// No description provided for @notificationOptions.
  ///
  /// In en, this message translates to:
  /// **'Notification options'**
  String get notificationOptions;

  /// No description provided for @markUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark unread'**
  String get markUnread;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// No description provided for @unreadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Unread notifications'**
  String get unreadNotifications;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @salesArea.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesArea;

  /// No description provided for @stockArea.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockArea;

  /// No description provided for @logisticsArea.
  ///
  /// In en, this message translates to:
  /// **'Logistics'**
  String get logisticsArea;

  /// No description provided for @purchasingArea.
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get purchasingArea;

  /// No description provided for @accountingArea.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get accountingArea;

  /// No description provided for @financeReview.
  ///
  /// In en, this message translates to:
  /// **'Finance review'**
  String get financeReview;

  /// No description provided for @refreshBalances.
  ///
  /// In en, this message translates to:
  /// **'Refresh balances'**
  String get refreshBalances;

  /// No description provided for @noMobileDocumentLinked.
  ///
  /// In en, this message translates to:
  /// **'No mobile document is linked to this entry.'**
  String get noMobileDocumentLinked;

  /// No description provided for @reviewTab.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTab;

  /// No description provided for @receivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get receivables;

  /// No description provided for @payables.
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get payables;

  /// No description provided for @expensesTab.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTab;

  /// No description provided for @activityTab.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTab;

  /// No description provided for @searchPartyDocument.
  ///
  /// In en, this message translates to:
  /// **'Search party or document'**
  String get searchPartyDocument;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @nothingReviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this review queue.'**
  String get nothingReviewQueue;

  /// No description provided for @accountingAttentionQueue.
  ///
  /// In en, this message translates to:
  /// **'Accounting attention queue'**
  String get accountingAttentionQueue;

  /// No description provided for @authoritativeBalances.
  ///
  /// In en, this message translates to:
  /// **'Authoritative backend balances'**
  String get authoritativeBalances;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @expenseReview.
  ///
  /// In en, this message translates to:
  /// **'Expense review'**
  String get expenseReview;

  /// No description provided for @matchingIssues.
  ///
  /// In en, this message translates to:
  /// **'Matching issues'**
  String get matchingIssues;

  /// No description provided for @certificatesPending.
  ///
  /// In en, this message translates to:
  /// **'certificates pending'**
  String get certificatesPending;

  /// No description provided for @approveExpenses.
  ///
  /// In en, this message translates to:
  /// **'Approve expenses'**
  String get approveExpenses;

  /// No description provided for @viewExpenses.
  ///
  /// In en, this message translates to:
  /// **'View expenses'**
  String get viewExpenses;

  /// No description provided for @yourFinanceAccess.
  ///
  /// In en, this message translates to:
  /// **'Your finance access'**
  String get yourFinanceAccess;

  /// No description provided for @customerPaymentLedger.
  ///
  /// In en, this message translates to:
  /// **'Customer payment ledger'**
  String get customerPaymentLedger;

  /// No description provided for @withholdingCertificates.
  ///
  /// In en, this message translates to:
  /// **'Withholding certificates'**
  String get withholdingCertificates;

  /// No description provided for @supplierPaymentRecording.
  ///
  /// In en, this message translates to:
  /// **'Supplier payment recording'**
  String get supplierPaymentRecording;

  /// No description provided for @supplierCredits.
  ///
  /// In en, this message translates to:
  /// **'Supplier credits'**
  String get supplierCredits;

  /// No description provided for @supplierReturns.
  ///
  /// In en, this message translates to:
  /// **'Supplier returns'**
  String get supplierReturns;

  /// No description provided for @accountingReports.
  ///
  /// In en, this message translates to:
  /// **'Accounting reports'**
  String get accountingReports;

  /// No description provided for @backendAmountsNotice.
  ///
  /// In en, this message translates to:
  /// **'Amounts are calculated by the backend. Recording and validation still use the existing audited workflows.'**
  String get backendAmountsNotice;

  /// No description provided for @salesOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales orders'**
  String get salesOrdersTitle;

  /// No description provided for @deliveriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveriesTitle;

  /// No description provided for @searchOrderClient.
  ///
  /// In en, this message translates to:
  /// **'Search order or client'**
  String get searchOrderClient;

  /// No description provided for @searchDeliveryClientOrder.
  ///
  /// In en, this message translates to:
  /// **'Search delivery, client or order'**
  String get searchDeliveryClientOrder;

  /// No description provided for @salesOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sales order'**
  String get salesOrderLabel;

  /// No description provided for @deliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @itemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @invoicesLabel.
  ///
  /// In en, this message translates to:
  /// **'invoices'**
  String get invoicesLabel;

  /// No description provided for @deliveriesLabel.
  ///
  /// In en, this message translates to:
  /// **'deliveries'**
  String get deliveriesLabel;

  /// No description provided for @confirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get confirmDelivery;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as delivered'**
  String get markDelivered;

  /// No description provided for @cancelDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cancel delivery'**
  String get cancelDelivery;

  /// No description provided for @readyToInvoice.
  ///
  /// In en, this message translates to:
  /// **'Ready to invoice'**
  String get readyToInvoice;

  /// No description provided for @supplierReceptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier receptions'**
  String get supplierReceptionsTitle;

  /// No description provided for @cannotCreateReception.
  ///
  /// In en, this message translates to:
  /// **'You cannot create supplier receptions.'**
  String get cannotCreateReception;

  /// No description provided for @noSupplierOrderAvailable.
  ///
  /// In en, this message translates to:
  /// **'No sent or partially received supplier order is available.'**
  String get noSupplierOrderAvailable;

  /// No description provided for @selectSupplierOrder.
  ///
  /// In en, this message translates to:
  /// **'Select a supplier order'**
  String get selectSupplierOrder;

  /// No description provided for @purchaseOrder.
  ///
  /// In en, this message translates to:
  /// **'Purchase order'**
  String get purchaseOrder;

  /// No description provided for @receiveOrder.
  ///
  /// In en, this message translates to:
  /// **'Receive order'**
  String get receiveOrder;

  /// No description provided for @searchSupplierOrderDocument.
  ///
  /// In en, this message translates to:
  /// **'Search supplier, order or document number'**
  String get searchSupplierOrderDocument;

  /// No description provided for @noSupplierReceptions.
  ///
  /// In en, this message translates to:
  /// **'No supplier receptions found.'**
  String get noSupplierReceptions;

  /// No description provided for @receptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get receptionLabel;

  /// No description provided for @confirmSupplierReception.
  ///
  /// In en, this message translates to:
  /// **'Confirm supplier reception?'**
  String get confirmSupplierReception;

  /// No description provided for @atomicStockNotice.
  ///
  /// In en, this message translates to:
  /// **'Accepted quantities will be posted to stock atomically. The reception cannot be edited afterwards.'**
  String get atomicStockNotice;

  /// No description provided for @createLinkedExpense.
  ///
  /// In en, this message translates to:
  /// **'Create linked expense'**
  String get createLinkedExpense;

  /// No description provided for @confirmPostStock.
  ///
  /// In en, this message translates to:
  /// **'Confirm and post stock'**
  String get confirmPostStock;

  /// No description provided for @receptionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Reception confirmed.'**
  String get receptionConfirmed;

  /// No description provided for @productLinesPosted.
  ///
  /// In en, this message translates to:
  /// **'product line(s) posted to stock.'**
  String get productLinesPosted;

  /// No description provided for @receptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Reception details'**
  String get receptionDetails;

  /// No description provided for @editDraft.
  ///
  /// In en, this message translates to:
  /// **'Edit draft'**
  String get editDraft;

  /// No description provided for @stockPosted.
  ///
  /// In en, this message translates to:
  /// **'Stock posted'**
  String get stockPosted;

  /// No description provided for @stockPending.
  ///
  /// In en, this message translates to:
  /// **'Stock pending'**
  String get stockPending;

  /// No description provided for @supplierDeliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Supplier delivery note'**
  String get supplierDeliveryNote;

  /// No description provided for @supplierInvoice.
  ///
  /// In en, this message translates to:
  /// **'Supplier invoice'**
  String get supplierInvoice;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @receptionLines.
  ///
  /// In en, this message translates to:
  /// **'Reception lines'**
  String get receptionLines;

  /// No description provided for @totalHt.
  ///
  /// In en, this message translates to:
  /// **'Total excl. tax'**
  String get totalHt;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vat;

  /// No description provided for @totalTtc.
  ///
  /// In en, this message translates to:
  /// **'Total incl. tax'**
  String get totalTtc;

  /// No description provided for @postingStock.
  ///
  /// In en, this message translates to:
  /// **'Posting stock…'**
  String get postingStock;

  /// No description provided for @editReception.
  ///
  /// In en, this message translates to:
  /// **'Edit reception'**
  String get editReception;

  /// No description provided for @newReception.
  ///
  /// In en, this message translates to:
  /// **'New reception'**
  String get newReception;

  /// No description provided for @receptionWithoutOrder.
  ///
  /// In en, this message translates to:
  /// **'Reception without purchase order'**
  String get receptionWithoutOrder;

  /// No description provided for @supplierInvoiceOptional.
  ///
  /// In en, this message translates to:
  /// **'Supplier invoice number (optional)'**
  String get supplierInvoiceOptional;

  /// No description provided for @supplierDeliveryNumber.
  ///
  /// In en, this message translates to:
  /// **'Supplier delivery-note number'**
  String get supplierDeliveryNumber;

  /// No description provided for @invoiceDate.
  ///
  /// In en, this message translates to:
  /// **'Invoice date'**
  String get invoiceDate;

  /// No description provided for @receivedDate.
  ///
  /// In en, this message translates to:
  /// **'Received date'**
  String get receivedDate;

  /// No description provided for @deliveryDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Delivery-note date (optional)'**
  String get deliveryDateOptional;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @receivedQuantities.
  ///
  /// In en, this message translates to:
  /// **'Received quantities'**
  String get receivedQuantities;

  /// No description provided for @receptionException.
  ///
  /// In en, this message translates to:
  /// **'Reception exception'**
  String get receptionException;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @overdelivery.
  ///
  /// In en, this message translates to:
  /// **'Overdelivery'**
  String get overdelivery;

  /// No description provided for @noPurchaseOrder.
  ///
  /// In en, this message translates to:
  /// **'No purchase order'**
  String get noPurchaseOrder;

  /// No description provided for @internalNotes.
  ///
  /// In en, this message translates to:
  /// **'Internal notes'**
  String get internalNotes;

  /// No description provided for @takeEvidencePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take evidence photo'**
  String get takeEvidencePhoto;

  /// No description provided for @chooseEvidencePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose evidence photo'**
  String get chooseEvidencePhoto;

  /// No description provided for @couldNotSelectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not select photo'**
  String get couldNotSelectPhoto;

  /// No description provided for @negativeReceptionQuantities.
  ///
  /// In en, this message translates to:
  /// **'Reception quantities cannot be negative.'**
  String get negativeReceptionQuantities;

  /// No description provided for @enterReceivedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a received quantity or remove the line.'**
  String get enterReceivedQuantity;

  /// No description provided for @discrepancyReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'A discrepancy reason is required.'**
  String get discrepancyReasonRequired;

  /// No description provided for @selectReceptionLine.
  ///
  /// In en, this message translates to:
  /// **'Select at least one line for this reception.'**
  String get selectReceptionLine;

  /// No description provided for @explainReceptionException.
  ///
  /// In en, this message translates to:
  /// **'Explain the reception exception before saving.'**
  String get explainReceptionException;

  /// No description provided for @evidenceUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Reception saved, but the evidence photo could not be uploaded.'**
  String get evidenceUploadFailed;

  /// No description provided for @receptionDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Supplier reception draft saved.'**
  String get receptionDraftSaved;

  /// No description provided for @addDiscrepancyEvidence.
  ///
  /// In en, this message translates to:
  /// **'Add discrepancy evidence'**
  String get addDiscrepancyEvidence;

  /// No description provided for @evidenceFileHelp.
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG or WebP; maximum 10 MB'**
  String get evidenceFileHelp;

  /// No description provided for @receptionTotals.
  ///
  /// In en, this message translates to:
  /// **'Reception totals'**
  String get receptionTotals;

  /// No description provided for @saveReceptionDraft.
  ///
  /// In en, this message translates to:
  /// **'Save reception draft'**
  String get saveReceptionDraft;

  /// No description provided for @ordered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get ordered;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @discrepancyReason.
  ///
  /// In en, this message translates to:
  /// **'Discrepancy reason'**
  String get discrepancyReason;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced'**
  String get statusInvoiced;

  /// No description provided for @statusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get statusReviewed;

  /// No description provided for @statusPartiallyDelivered.
  ///
  /// In en, this message translates to:
  /// **'Partially delivered'**
  String get statusPartiallyDelivered;

  /// No description provided for @statusPartiallyReceived.
  ///
  /// In en, this message translates to:
  /// **'Partially received'**
  String get statusPartiallyReceived;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @supplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplierLabel;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @noMobileFeatures.
  ///
  /// In en, this message translates to:
  /// **'No mobile features are assigned to this user.'**
  String get noMobileFeatures;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}

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
  /// **'Recent transactions'**
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
  /// **'Overdue'**
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
  /// **'Fiscal ID must match 1234567ABC123'**
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
  /// **'Format: 1234567ABC123'**
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

  /// No description provided for @draftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftLabel;

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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

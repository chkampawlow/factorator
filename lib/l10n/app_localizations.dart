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

  /// No description provided for @fiscalId.
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
  /// **'Choose Client'**
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
  /// **'Add Product'**
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
  /// **'Search (name / MF / CIN)...'**
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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get cancel => 'Cancel';

  @override
  String get currency => 'Currency';

  @override
  String get selectCurrency => 'Select currency';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get appColor => 'App color';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get email => 'Email';

  @override
  String get fiscalId => 'Fiscal ID';

  @override
  String get noUserData => 'No user data';

  @override
  String get logoutQuestion => 'Do you want to logout?';

  @override
  String currencyChanged(String value) {
    return 'Currency changed to $value';
  }

  @override
  String languageChanged(String value) {
    return 'Language changed to $value';
  }

  @override
  String get clientUpdateApiNotAddedYet => 'Client update API not added yet';

  @override
  String get clientAddedSuccessfully => 'Client added successfully';

  @override
  String clientAddedSuccessfullyWithId(String id) {
    return 'Client added successfully with ID: $id';
  }

  @override
  String get saveFailed => 'Save failed';

  @override
  String get fiscalIdMf => 'Fiscal ID (MF)';

  @override
  String get cin => 'CIN';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get companyName => 'Company name';

  @override
  String get fullName => 'Full name';

  @override
  String get requiredField => 'Required';

  @override
  String get mfRequired => 'Fiscal ID required';

  @override
  String get cinRequired => 'CIN required';

  @override
  String get cinTooShort => 'CIN looks too short';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get saveCustomer => 'Save Customer';

  @override
  String get newInvoice => 'New Invoice';

  @override
  String get saving => 'Saving...';

  @override
  String get createInvoice => 'Create Invoice';

  @override
  String get client => 'Client';

  @override
  String get chooseClientOrAddNew => 'Choose client or add new';

  @override
  String get dueDate => 'Due date';

  @override
  String get nextStep => 'Next step';

  @override
  String issueDateAutoToday(String date) {
    return 'The issue date will be set automatically to today ($date). After creating the invoice, you will be redirected to the invoice detail screen where you can add invoice items.';
  }

  @override
  String get clientSelectionFailed => 'Client selection failed';

  @override
  String get pleaseChooseClient => 'Please choose a client.';

  @override
  String get chooseClient => 'Choose Client';

  @override
  String get addNewClient => 'Add new client';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get priceAndTvaMustBeValidNumbers => 'Price and TVA must be valid numbers.';

  @override
  String get invalidProductId => 'Invalid product id';

  @override
  String get productUpdatedSuccessfully => 'Product updated successfully';

  @override
  String get productSavedSuccessfully => 'Product saved successfully';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get addProduct => 'Add Product';

  @override
  String get saveProduct => 'Save Product';

  @override
  String get updateProductDetails => 'Update product details';

  @override
  String get createNewProductOrService => 'Create a new product or service';

  @override
  String get codeOptional => 'Code (optional)';

  @override
  String get productCodeExample => 'e.g. PRD-001';

  @override
  String get productServiceName => 'Product / Service name';

  @override
  String get productServiceNameExample => 'e.g. Web design, Consulting...';

  @override
  String get price => 'Price';

  @override
  String get priceExample => 'e.g. 120 or 120,50';

  @override
  String get tvaPercent => 'TVA %';

  @override
  String get tvaExample => 'e.g. 19';

  @override
  String get unitOptional => 'Unit (optional)';

  @override
  String get unitExample => 'hour / piece / kg...';

  @override
  String get failedToLoadCustomers => 'Failed to load customers';

  @override
  String get mfLabel => 'MF';

  @override
  String get missingClientId => 'Missing client id';

  @override
  String get invalidClientId => 'Invalid client id';

  @override
  String get deleteCustomerQuestion => 'Delete customer?';

  @override
  String areYouSureDeleteCustomer(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get customerDeletedSuccessfully => 'Customer deleted successfully';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get unnamedCustomer => 'Unnamed customer';

  @override
  String get customers => 'Customers';

  @override
  String get refresh => 'Refresh';

  @override
  String get add => 'Add';

  @override
  String get searchNameMfCin => 'Search (name / MF / CIN)...';

  @override
  String get allCustomers => 'All customers';

  @override
  String get noCustomersYet => 'No customers yet';

  @override
  String get edit => 'Edit';
}

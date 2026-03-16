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
  String get dashboard => 'Dashboard';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get advanceInvoice => 'Advance invoice';

  @override
  String get advanceInvoiceComingSoon => 'Advance invoice: coming soon';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get all => 'All';

  @override
  String get noInvoicesYet => 'No invoices yet.';

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

  @override
  String get invoice => 'Invoice';

  @override
  String get status => 'Status';

  @override
  String get issue => 'Issue';

  @override
  String get due => 'Due';

  @override
  String get fill => 'Fill';

  @override
  String get previewPdf => 'Preview PDF';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get invoiceNotFound => 'Invoice not found.';

  @override
  String get addAtLeastOneItemBeforePreviewPdf => 'Add at least one item before previewing the PDF.';

  @override
  String get qtyMustBeGreaterThanZero => 'Qty must be > 0';

  @override
  String get itemAdded => 'Item added';

  @override
  String get itemDeleted => 'Item deleted';

  @override
  String get itemUpdated => 'Item updated';

  @override
  String get deleteItem => 'Delete item';

  @override
  String get removeThisItemFromInvoice => 'Remove this item from the invoice?';

  @override
  String get editItem => 'Edit item';

  @override
  String get qty => 'Qty';

  @override
  String get discountPercent => 'Discount (%)';

  @override
  String get save => 'Save';

  @override
  String get addItem => 'Add item';

  @override
  String get product => 'Product';

  @override
  String get priceOverride => 'Price override';

  @override
  String get addToInvoice => 'Add to invoice';

  @override
  String get noItemsYet => 'No items yet.';

  @override
  String get invoices => 'Invoices';

  @override
  String get overdue => 'Overdue';

  @override
  String get code => 'Code';

  @override
  String get type => 'Type';

  @override
  String get doc => 'Doc';

  @override
  String get issued => 'Issued';

  @override
  String get dueToday => 'Due today';

  @override
  String dueInDays(String days, String suffix) {
    return 'Due in $days day$suffix';
  }

  @override
  String overdueByDays(String days, String suffix) {
    return 'Overdue by $days day$suffix';
  }

  @override
  String get createYourFirstInvoiceToSeeItHere => 'Create your first invoice to see it here.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginToManageApp => 'Login to manage your clients, products and invoices.';

  @override
  String get emailAddress => 'Email address';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get minimum6Characters => 'Minimum 6 characters';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get login => 'Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get createOne => 'Create one';

  @override
  String get loginSuccess => 'Login success';

  @override
  String welcomeUser(String name) {
    return 'Welcome $name';
  }

  @override
  String get productsServices => 'Products / Services';

  @override
  String get searchProductsHint => 'Search (name / code / unit / TVA)...';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get deleteProductQuestion => 'Delete product?';

  @override
  String areYouSureDeleteProduct(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get productDeleted => 'Product deleted ✅';

  @override
  String get unnamedProduct => 'Unnamed product';

  @override
  String get unit => 'Unit';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get lastNameRequired => 'Last name is required';

  @override
  String get fiscalIdRequired => 'Fiscal ID is required';

  @override
  String get fiscalIdMustMatch => 'Fiscal ID must match 1234567ABC123';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get accountCreatedSuccessfully => 'Account created successfully';

  @override
  String get whoAreYou => 'Who are you?';

  @override
  String get startWithPersonalInformation => 'Start with your personal information.';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get companyDetails => 'Company details';

  @override
  String get addOrganizationAndFiscalInfo => 'Add your organization and fiscal information.';

  @override
  String get organizationName => 'Organization name';

  @override
  String get fiscalIdRequiredLabel => 'Fiscal ID*';

  @override
  String get fiscalIdFormat => 'Format: 1234567ABC123';

  @override
  String get contactInformation => 'Contact information';

  @override
  String get howCanWeReachYou => 'How can we reach you?';

  @override
  String get emailAddressLabel => 'Email address';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get secureYourAccount => 'Secure your account';

  @override
  String get chooseStrongPassword => 'Choose a strong password.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get reviewAndCreate => 'Review & create';

  @override
  String get reviewBeforeCreate => 'Make sure everything looks good before creating the account.';

  @override
  String get organization => 'Organization';

  @override
  String get fiscalIdLabel => 'Fiscal ID';

  @override
  String get phone => 'Phone';

  @override
  String get createAccount => 'Create account';

  @override
  String get back => 'Back';

  @override
  String get continueText => 'Continue';

  @override
  String get invalidFiscalId => 'Invalid fiscal ID';

  @override
  String get phoneNumberRequired => 'Phone number is required';

  @override
  String get phoneNumberInvalid => 'Invalid phone number';

  @override
  String get clients => 'Clients';

  @override
  String get items => 'Items';

  @override
  String get searchProduct => 'Search product';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get selectProduct => 'Select product';

  @override
  String get companyInformation => 'Company information';

  @override
  String get fax => 'Fax';

  @override
  String get address => 'Address';

  @override
  String get website => 'Website';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get profileImageUpdated => 'Profile image updated';

  @override
  String get tapImageToChangePhoto => 'Tap image to change photo';

  @override
  String get region => 'Region';

  @override
  String get name => 'Name';

  @override
  String get identifier => 'Identifier';

  @override
  String get notes => 'Notes';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';
}

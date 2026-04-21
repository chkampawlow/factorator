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
  String get chooseClient => 'Choose a client';

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
  String get addProduct => 'Add product';

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
  String get scanInvoiceTitle => 'Scan invoice';

  @override
  String get scanInvoiceSubtitle => 'Place the invoice inside the frame. This is the camera UI preview.';

  @override
  String get scanInvoiceMode => 'Invoice';

  @override
  String get scanInvoiceAlign => 'Align the invoice inside the frame';

  @override
  String get scanInvoiceGuideTitle => 'Scan guide';

  @override
  String get scanInvoiceGuideLight => 'Use good light and avoid shadows on the paper.';

  @override
  String get scanInvoiceGuideEdges => 'Keep all invoice corners visible in the frame.';

  @override
  String get scanInvoiceGuideReadable => 'Make sure totals and supplier details are readable.';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get advanceInvoice => 'Advance invoice';

  @override
  String get advanceInvoiceComingSoon => 'Advance invoice: coming soon';

  @override
  String get recentTransactions => 'Stats';

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
  String get searchNameMfCin => 'Search by name, MF or CIN';

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
  String get code => 'Indicatif';

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
  String get forgotPassword => 'Forgot password';

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
  String get fiscalIdMustMatch => 'Fiscal ID must match 1234567A';

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
  String get fiscalIdFormat => 'Format: 1234567A';

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
  String get note => 'Note';

  @override
  String get addNote => 'Add note';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentTransfer => 'Bank transfer';

  @override
  String get paymentCheck => 'Check';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';

  @override
  String get verifyEmail => 'Verify your email';

  @override
  String get verifyEmailDescription => 'Please verify your email before continuing. Enter the 6-digit code or resend the email.';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get verifyNow => 'Verify now';

  @override
  String get resendEmail => 'Resend email';

  @override
  String resendEmailIn(int seconds) {
    return 'Resend email in ${seconds}s';
  }

  @override
  String get verificationEmailSent => 'Verification email sent';

  @override
  String get enterVerificationCode => 'Enter the verification code';

  @override
  String get emailVerifiedSuccessfully => 'Email verified successfully';

  @override
  String get forgotPasswordDescription => 'Enter your email and we will send you a 6-digit code to reset your password.';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get resetCodeSent => 'Reset code sent';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordDescription => 'Enter the 6-digit code and your new password.';

  @override
  String get enterResetCode => 'Enter the reset code';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordResetSuccessful => 'Password reset successful';

  @override
  String get twoFactorTitle => 'Two-factor authentication';

  @override
  String twoFactorSubtitle(Object email) {
    return 'Enter the 6-digit code from your authenticator app for $email.';
  }

  @override
  String get twoFactorCode => 'Authentication code';

  @override
  String get twoFactorCodeRequired => 'Authentication code is required';

  @override
  String get twoFactorCodeInvalid => 'Enter a valid 6-digit code';

  @override
  String get twoFactorHint => 'Open Google Authenticator and enter the current 6-digit code.';

  @override
  String get twoFactorVerify => 'Verify';

  @override
  String get twoFactorBack => 'Back';

  @override
  String get twoFactorSuccess => 'Two-factor verification successful';

  @override
  String get twoFactorSetupTitle => 'Google Authenticator';

  @override
  String get twoFactorSetupSubtitle => 'Set up two-factor authentication to better protect your account.';

  @override
  String get twoFactorStep1 => 'Step 1';

  @override
  String get twoFactorScanQr => 'Scan this QR code with Google Authenticator or enter the manual key below.';

  @override
  String get twoFactorManualKey => 'Manual key';

  @override
  String get twoFactorManualKeyUnavailable => 'Manual key unavailable';

  @override
  String get twoFactorQrUnavailable => 'QR code unavailable';

  @override
  String get twoFactorStep2 => 'Step 2';

  @override
  String get twoFactorEnterSetupCode => 'Enter the 6-digit code generated by your authenticator app.';

  @override
  String get twoFactorEnableButton => 'Enable 2FA';

  @override
  String get twoFactorEnabledSuccess => 'Two-factor authentication enabled successfully';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get twoFactorDisableTitle => 'Disable two-factor authentication';

  @override
  String get twoFactorDisableMessage => 'Are you sure you want to disable Google Authenticator for this account?';

  @override
  String get twoFactorDisableButton => 'Disable';

  @override
  String get twoFactorDisableCodeTitle => 'Enter disable code';

  @override
  String get twoFactorDisabledSuccess => 'Two-factor authentication disabled successfully';

  @override
  String get twoFactorToggleTitle => 'Google Authenticator';

  @override
  String get twoFactorToggleOn => 'Two-factor authentication is enabled';

  @override
  String get twoFactorToggleOff => 'Two-factor authentication is disabled';

  @override
  String get twoFactorLoadingStatus => 'Checking two-factor authentication status...';

  @override
  String get twoFactorDisabling => 'Disabling two-factor authentication...';

  @override
  String get twoFactorPreparing => 'Preparing two-factor authentication...';

  @override
  String get twoFactorManualKeyCopied => 'Manual key copied';

  @override
  String get copy => 'Copy';

  @override
  String get monthlyRevenue => 'Monthly Revenue';

  @override
  String get pending => 'Pending';

  @override
  String get averageInvoice => 'Average Invoice';

  @override
  String get topClients => 'Top Clients';

  @override
  String get revenueCurve => 'Revenue Curve';

  @override
  String get paidVsUnpaid => 'Paid vs Unpaid';

  @override
  String get totalLabel => 'Total';

  @override
  String get paidLabel => 'Paid';

  @override
  String get unpaidLabel => 'Unpaid';

  @override
  String get paymentRate => 'Payment Rate';

  @override
  String get growthCurve => 'Growth Curve';

  @override
  String get draftLabel => 'Draft';

  @override
  String get cancelledLabel => 'Cancelled';

  @override
  String get searchInvoiceClientEmail => 'Search invoice, client, email...';

  @override
  String get noInvoicesMatchSearch => 'No invoices match your search';

  @override
  String get changeStatus => 'Change status';

  @override
  String get markAsPaid => 'Mark as paid';

  @override
  String get markAsUnpaid => 'Mark as unpaid';

  @override
  String get validateInvoice => 'Validate invoice';

  @override
  String get confirmValidateInvoiceTitle => 'Validate this invoice?';

  @override
  String get confirmValidateInvoiceBody => 'Are you sure you want to validate this invoice? You cannot modify it after validating.';

  @override
  String get invoiceLockedAfterValidation => 'This invoice is validated. You can no longer modify, add, or delete items.';

  @override
  String get markAsCancelled => 'Mark as cancelled';

  @override
  String get invoiceStatusUpdated => 'Invoice status updated';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get dueSoon => 'Due soon';

  @override
  String get paid => 'Paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get expenseNotesTitle => 'Expense Notes';

  @override
  String get createExpenseNoteTitle => 'New Expense';

  @override
  String get searchExpenseHint => 'Search by title, category or description';

  @override
  String get noExpenseNotes => 'No expense notes yet';

  @override
  String get noExpenseNotesMatchSearch => 'No expense notes match your search';

  @override
  String get createYourFirstExpenseNoteToSeeItHere => 'Create your first expense note to see it here';

  @override
  String get expenseNotePreviewTitleFallback => 'Expense Note';

  @override
  String get expenseStatusUpdated => 'Expense status updated successfully';

  @override
  String get expenseNoteDeletedSuccess => 'Expense note deleted successfully';

  @override
  String get confirmDeleteTitle => 'Confirm deletion';

  @override
  String get confirmDeleteExpenseMessage => 'Are you sure you want to delete this expense note?';

  @override
  String get deleteButton => 'Delete';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get markAsPending => 'Mark as pending';

  @override
  String get markAsRejected => 'Mark as rejected';

  @override
  String get dateLabel => 'Date';

  @override
  String get categoryLabel => 'Category';

  @override
  String get editExpenseNoteTitle => 'Edit Expense';

  @override
  String get editExpenseNoteSubtitle => 'Update your expense note details.';

  @override
  String get expenseNoteUpdatedSuccess => 'Expense note updated successfully';

  @override
  String get statusPending => 'Pending';

  @override
  String get receiptPathLabel => 'Receipt path';

  @override
  String get receiptPathHint => 'Enter receipt file path';

  @override
  String get updateButton => 'Update';

  @override
  String get createExpenseNoteSubtitle => 'Add and track a new expense note.';

  @override
  String get expenseNoteCreatedSuccess => 'Expense note created successfully';

  @override
  String get title => 'Title';

  @override
  String get amount => 'Amount';

  @override
  String get description => 'Description';

  @override
  String get invalidField => 'Invalid value';

  @override
  String get saveButton => 'Save';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String currencyChangedTo(String currency) {
    return 'Currency changed to $currency';
  }

  @override
  String languageChangedTo(String language) {
    return 'Language changed to $language';
  }

  @override
  String get companyInfoIncompleteTitle => 'Company information is incomplete';

  @override
  String get companyInfoIncompleteBody => 'Please complete your company information.';

  @override
  String get googleAuthenticator => 'Google Authenticator';

  @override
  String get enableTwoFactorAuthentication => 'Enable two-factor authentication';

  @override
  String get monthlyExpenses => 'Monthly expenses';

  @override
  String get netMonthlyRevenue => 'Net monthly revenue';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsSnackbars => 'Snackbars';

  @override
  String get alertsBanners => 'Banners';

  @override
  String get alertsDialogs => 'Dialogs';

  @override
  String get alertsBottomSheets => 'Bottom sheets';

  @override
  String get alertSuccessTitle => 'Success';

  @override
  String get alertSuccessBody => 'Saved successfully.';

  @override
  String get alertInfoTitle => 'Information';

  @override
  String get alertInfoBody => 'This is an informational message.';

  @override
  String get alertWarningTitle => 'Warning';

  @override
  String get alertWarningBody => 'Check your inputs before continuing.';

  @override
  String get alertErrorTitle => 'Error';

  @override
  String get alertErrorBody => 'Something went wrong. Try again.';

  @override
  String get alertConfirmTitle => 'Confirm action';

  @override
  String get alertConfirmBody => 'Do you want to continue?';

  @override
  String get alertBottomSheetTitle => 'Attention required';

  @override
  String get alertBottomSheetBody => 'Review the details before saving.';

  @override
  String get alertSavedBody => 'Changes saved.';

  @override
  String get alertUndo => 'Undo';

  @override
  String get alertDismiss => 'Dismiss';

  @override
  String get french => 'French';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get checkingSession => 'Checking session...';

  @override
  String get unitPcs => 'pcs (Pieces)';

  @override
  String get unitKg => 'kg (Kilogram)';

  @override
  String get unitG => 'g (Gram)';

  @override
  String get unitL => 'L (Liter)';

  @override
  String get unitM => 'm (Meter)';

  @override
  String get unitH => 'h (Hour)';

  @override
  String get unitDay => 'day';

  @override
  String get unitService => 'service';

  @override
  String get invalidPhoneNumber => 'Numéro invalide. Exemple : +216 20123456';

  @override
  String get noResults => 'No results';

  @override
  String get newCustomer => 'New Customer';

  @override
  String get createCustomer => 'Create Customer';

  @override
  String get createFirstCustomerToSeeHere => 'Create your first customer to see it here.';

  @override
  String get searchCustomerNameIdEmail => 'Search customer, ID, email...';

  @override
  String get companies => 'Companies';

  @override
  String get createYourFirstProduct => 'Create your first product to start adding items to this invoice.';

  @override
  String get individuals => 'Individuals';

  @override
  String get productAdded => 'Product added';

  @override
  String get deleteDraftInvoiceConfirm => 'Delete this draft invoice? This action cannot be undone.';

  @override
  String get invoiceDeleted => 'Invoice deleted.';
}

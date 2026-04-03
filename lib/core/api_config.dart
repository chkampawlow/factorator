class ApiConfig {
  static String baseUrl = 'http://192.168.1.144/backend';

  // 🔐 STATIC TOKEN
  static const String staticToken = 'a3Jmk8xjRHe443zusjKxAaE7PkHqrFPq';

  // ✅ Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $staticToken',
      };

  // Auth
  static String get login => '$baseUrl/auth/login.php';
  static String get signup => '$baseUrl/auth/signup.php';
  static String get me => '$baseUrl/auth/me.php';
  static String get refresh => '$baseUrl/auth/refresh.php';

  // Clients
  static String get getClients => '$baseUrl/clients/get_clients.php';
  static String get getClientsevenarchived => '$baseUrl/clients/get_clients_all_with_archieved.php';
  static String get addClient => '$baseUrl/clients/add_client.php';
  static String get updateClient => '$baseUrl/clients/update_client.php';
  static String get deleteClient => '$baseUrl/clients/delete_client.php';

  // Products
  static String get getProducts => '$baseUrl/products/get_products.php';
  static String get addProduct => '$baseUrl/products/add_product.php';
  static String get updateProduct => '$baseUrl/products/update_product.php';
  static String get deleteProduct => '$baseUrl/products/delete_product.php';

  // Invoices
  static String get getInvoices => '$baseUrl/invoices/get_invoices.php';
  static String get getInvoiceById => '$baseUrl/invoices/get_invoice_by_id.php';
  static String get addInvoice => '$baseUrl/invoices/add_invoice.php';
  static String get recomputeInvoiceTotals =>
      '$baseUrl/invoices/recompute_invoice_totals.php';
  static String get updateInvoiceStatus =>
    '$baseUrl/invoices/update_invoice_status.php';
  

  // Invoice items
  static String get addInvoiceItem =>
      '$baseUrl/invoice_items/add_invoice_item.php';
  static String get getInvoiceItems =>
      '$baseUrl/invoice_items/get_invoice_items.php';
  static String get deleteInvoiceItem =>
      '$baseUrl/invoice_items/delete_invoice_item.php';
  static String get updateInvoiceItem =>
      '$baseUrl/invoice_items/update_invoice_item.php';

  // User
  static String get updateProfile => '$baseUrl/user/update_profile.php';



//mailing services
  static String get sendVerificationEmail =>
    '$baseUrl/auth/send_verification_email.php';

static String get verifyEmail =>
    '$baseUrl/auth/verify_email.php';

static String get forgotPassword =>
    '$baseUrl/auth/forgot_password.php';

static String get resetPassword =>
    '$baseUrl/auth/reset_password.php';

static String get sendInvoicePdf =>
    '$baseUrl/mailer/send_invoice_pdf.php';
    
//2fa services
static String get verify2faLogin => '$baseUrl/auth/verify_2fa_login.php';    
static String get enable2fa => '$baseUrl/auth/enable_2fa.php';
static String get confirm2fa => '$baseUrl/auth/confirm_2fa.php';
static String get disable2fa => '$baseUrl/auth/disable_2fa.php';
static String get twofaStatus => '$baseUrl/auth/twofa_status.php';
 
 
//Expences repo
static String get expenseNotesList => '$baseUrl/expense_notes/list.php';
static String get expenseNotesAdd => '$baseUrl/expense_notes/add.php';
static String get expenseNotesUpdate => '$baseUrl/expense_notes/update.php';
static String get expenseNotesDelete => '$baseUrl/expense_notes/delete.php';
static String get expenseNotesUpdateStatus => '$baseUrl/expense_notes/update_status.php'; 
    }

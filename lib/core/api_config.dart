class ApiConfig {
  static String baseUrl = '';

  // Auth
  static String get login => '$baseUrl/auth/login.php';
  static String get signup => '$baseUrl/auth/signup.php';
  static String get me => '$baseUrl/auth/me.php';
  static String get refresh => '$baseUrl/auth/refresh.php';

  // Clients
  static String get getClients => '$baseUrl/clients/get_clients.php';
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
}
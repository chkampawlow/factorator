class ApiConfig {
  static const String baseUrl = 'http://deployment-airfare-insights-regulations.trycloudflare.com/ready/';

  // Auth
  static const String login = '$baseUrl/auth/login.php';
  static const String signup = '$baseUrl/auth/signup.php';
  static const String me = '$baseUrl/auth/me.php';
  static const String refresh = '$baseUrl/auth/refresh.php';

  // Clients
  static const String getClients = '$baseUrl/clients/get_clients.php';
  static const String addClient = '$baseUrl/clients/add_client.php';
  static const String updateClient = '$baseUrl/clients/update_client.php';
  static const String deleteClient = '$baseUrl/clients/delete_client.php';

  // Products
  static const String getProducts = '$baseUrl/products/get_products.php';
  static const String addProduct = '$baseUrl/products/add_product.php';
  static const String updateProduct = '$baseUrl/products/update_product.php';
  static const String deleteProduct = '$baseUrl/products/delete_product.php';

  // Invoices
  static const String getInvoices = '$baseUrl/invoices/get_invoices.php';
  static const String getInvoiceById = '$baseUrl/invoices/get_invoice_by_id.php';
  static const String addInvoice = '$baseUrl/invoices/add_invoice.php';
  static const String recomputeInvoiceTotals =
      '$baseUrl/invoices/recompute_invoice_totals.php';

  // Invoice items
  static const String addInvoiceItem =
      '$baseUrl/invoice_items/add_invoice_item.php';
  static const String getInvoiceItems =
      '$baseUrl/invoice_items/get_invoice_items.php';
  static const String deleteInvoiceItem =
      '$baseUrl/invoice_items/delete_invoice_item.php';
  static const String updateInvoiceItem =
      '$baseUrl/invoice_items/update_invoice_item.php';

  // User
  static const String updateProfile =
      '$baseUrl/user/update_profile.php';
}
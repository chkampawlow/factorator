class ApiConfig {
  static const String baseUrl = 'http://192.168.1.28/facturation_api/php';

  // Auth
  static const String login = '$baseUrl/login.php';
  static const String signup = '$baseUrl/signup.php';
  static const String me = '$baseUrl/me.php';
  static const String refresh = '$baseUrl/refresh.php';

  // Clients
  static const String getClients = '$baseUrl/get_clients.php';
  static const String addClient = '$baseUrl/add_client.php';
static const String updateClient = '$baseUrl/update_client.php';
static const String deleteClient = '$baseUrl/delete_client.php';

  // Products
  static const String getProducts = '$baseUrl/get_products.php';
  static const String addProduct = '$baseUrl/add_product.php';
  static const String updateProduct = '$baseUrl/update_product.php';
  static const String deleteProduct = '$baseUrl/delete_product.php';

  // Invoices
  static const String getInvoices = '$baseUrl/get_invoices.php';
  static const String getInvoiceById = '$baseUrl/get_invoice_by_id.php';
  static const String addInvoice = '$baseUrl/add_invoice.php';
  static const String recomputeInvoiceTotals =
      '$baseUrl/recompute_invoice_totals.php';

  // Invoice items
  static const String addInvoiceItem = '$baseUrl/add_invoice_item.php';
  static const String getInvoiceItems = '$baseUrl/get_invoice_items.php';
  static const String deleteInvoiceItem = '$baseUrl/delete_invoice_item.php';
static const String updateInvoiceItem = '$baseUrl/update_invoice_item.php';
}
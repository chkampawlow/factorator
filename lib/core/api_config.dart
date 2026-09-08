class ApiConfig {
  /// Production is the default on every platform. Override it for local
  /// development with:
  /// flutter run --dart-define=API_BASE_URL=http://127.0.0.1/backend
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://facture.myenv.digital/backend',
  );

  /// Keep unfinished backend-dependent features out of production navigation.
  static const bool assistantEnabled = bool.fromEnvironment(
    'ASSISTANT_ENABLED',
    defaultValue: false,
  );

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

  // Dashboard
  static String get dashboardOverview => '$baseUrl/dashboard/overview.php';
  static String get notificationOverview =>
      '$baseUrl/notifications/overview.php';
  static String get notificationsList => '$baseUrl/notifications/list.php';
  static String get notificationsMarkRead =>
      '$baseUrl/notifications/mark_read.php';
  static String get accountingMobileReview =>
      '$baseUrl/accounting/mobile_review.php';
  static String get extractorRun => '$baseUrl/extractor/run_extraction.php';
  static String get extractorSamples => '$baseUrl/extractor/list_samples.php';
  static String get suppliersList => '$baseUrl/suppliers/list_page.php';
  static String get supplierOrdersList =>
      '$baseUrl/supplier_orders/list_page.php';
  static String get supplierReceptionsList =>
      '$baseUrl/supplier_receptions/list_page.php';
  static String get supplierReceptionDetail =>
      '$baseUrl/supplier_receptions/get_supplier_receptions.php';
  static String get supplierReceptionSave =>
      '$baseUrl/supplier_receptions/save_supplier_reception.php';
  static String get supplierReceptionConfirm =>
      '$baseUrl/supplier_receptions/confirm_supplier_reception.php';
  static String get supplierReceptionUpload =>
      '$baseUrl/supplier_receptions/upload_discrepancy_attachment.php';
  static String get supplierOrderDetail =>
      '$baseUrl/supplier_orders/get_supplier_orders.php';
  static String get supplierInvoicesList =>
      '$baseUrl/supplier_invoices/list_page.php';
  static String get supplierInvoiceSources =>
      '$baseUrl/supplier_invoices/available_sources.php';
  static String get supplierInvoiceDetail =>
      '$baseUrl/supplier_invoices/get_supplier_invoice.php';
  static String get documentPdf => '$baseUrl/mailer/download_document_pdf.php';
  static String get salesOrdersList => '$baseUrl/bon_commandes/list.php';
  static String get salesOrderDetail => '$baseUrl/bon_commandes/get.php';
  static String get deliveriesList => '$baseUrl/bon_livraisons/list.php';
  static String get deliveryDetail => '$baseUrl/bon_livraisons/get.php';
  static String get deliveryAction => '$baseUrl/bon_livraisons/action.php';

  // Clients
  static String get getClients => '$baseUrl/clients/list_page.php';
  static String get getClientsevenarchived =>
      '$baseUrl/clients/get_clients_all_with_archieved.php';
  static String get addClient => '$baseUrl/clients/add_client.php';
  static String get updateClient => '$baseUrl/clients/update_client.php';
  static String get deleteClient => '$baseUrl/clients/delete_client.php';

  // Products
  static String get getProducts => '$baseUrl/products/list_page.php';
  static String get addProduct => '$baseUrl/products/add_product.php';
  static String get updateProduct => '$baseUrl/products/update_product.php';
  static String get deleteProduct => '$baseUrl/products/delete_product.php';
  static String get getProduct => '$baseUrl/products/get_product.php';
  static String get productStockHistory =>
      '$baseUrl/products/get_product_stock_history.php';
  static String get productBarcodeLookup =>
      '$baseUrl/products/barcode_lookup.php';
  static String get createStockAdjustment =>
      '$baseUrl/products/create_stock_adjustment.php';

  // Invoices
  static String get getInvoices => '$baseUrl/invoices/list_page.php';
  static String get getInvoiceById => '$baseUrl/invoices/get_invoice_by_id.php';
  static String get invoiceSettlements =>
      '$baseUrl/invoice_settlements/get.php';
  static String get addInvoice => '$baseUrl/invoices/add_invoice.php';
  static String get updateInvoice => '$baseUrl/invoices/update_invoice.php';
  static String get recomputeInvoiceTotals =>
      '$baseUrl/invoices/recompute_invoice_totals.php';
  static String get updateInvoiceStatus =>
      '$baseUrl/invoices/update_invoice_status.php';
  static String get deleteInvoice => '$baseUrl/invoices/delete_invoice.php';

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

  static String get verifyEmail => '$baseUrl/auth/verify_email.php';

  static String get forgotPassword => '$baseUrl/auth/forgot_password.php';

  static String get resetPassword => '$baseUrl/auth/reset_password.php';

  static String get sendInvoicePdf => '$baseUrl/mailer/send_invoice_pdf.php';

//2fa services
  static String get verify2faLogin => '$baseUrl/auth/verify_2fa_login.php';
  static String get enable2fa => '$baseUrl/auth/enable_2fa.php';
  static String get confirm2fa => '$baseUrl/auth/confirm_2fa.php';
  static String get disable2fa => '$baseUrl/auth/disable_2fa.php';
  static String get twofaStatus => '$baseUrl/auth/twofa_status.php';

//Expences repo
  static String get expenseNotesList => '$baseUrl/expense_notes/list_page.php';
  static String get expenseNoteDetail => '$baseUrl/expense_notes/get.php';
  static String get expenseNotesAdd => '$baseUrl/expense_notes/add.php';
  static String get expenseNotesUpdate => '$baseUrl/expense_notes/update.php';
  static String get expenseNotesDelete => '$baseUrl/expense_notes/delete.php';
  static String get expenseNotesUpdateStatus =>
      '$baseUrl/expense_notes/update_status.php';

  // AI
  static String get assistant => '$baseUrl/ai/assistant.php';
}

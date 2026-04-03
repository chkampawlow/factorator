import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ExpenseNotesRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listExpenseNotes() async {
    final res = await _api.get(
      ApiConfig.expenseNotesList,
      authRequired: true,
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load expense notes');
    }

    final items = res['items'];
    if (items is! List) return [];

    return items.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);

      return {
        ...map,
        'id': map['id'],
        'title': map['title'] ?? '',
        'category': map['category'] ?? '',
        'amount': map['amount'] ?? 0,
        'description': map['description'] ?? '',
        'receipt_path': map['receipt_path'] ?? '',
        'date': map['expense_date'] ?? map['date'] ?? '',
        'status': _uiStatusFromBackend((map['status'] ?? 'PENDING').toString()),
      };
    }).toList();
  }

  Future<int> addExpenseNote({
    required String title,
    required String category,
    required double amount,
    required String description,
    required String status,
    required String date,
    String receiptPath = '',
  }) async {
    final res = await _api.post(
      ApiConfig.expenseNotesAdd,
      authRequired: true,
      body: {
        'title': title,
        'category': category,
        'amount': amount,
        'expense_date': date,
        'description': description,
        'receipt_path': receiptPath,
        'status': _backendStatusFromUi(status),
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to add expense note');
    }

    return int.tryParse((res['id'] ?? '0').toString()) ?? 0;
  }

  Future<void> updateExpenseNote({
    required int id,
    required String title,
    required String category,
    required double amount,
    required String description,
    required String status,
    required String date,
    String receiptPath = '',
  }) async {
    final res = await _api.post(
      ApiConfig.expenseNotesUpdate,
      authRequired: true,
      body: {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'expense_date': date,
        'description': description,
        'receipt_path': receiptPath,
        'status': _backendStatusFromUi(status),
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to update expense note');
    }
  }

  Future<void> deleteExpenseNote(int id) async {
    final res = await _api.post(
      ApiConfig.expenseNotesDelete,
      authRequired: true,
      body: {
        'id': id,
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to delete expense note');
    }
  }

  Future<void> updateExpenseNoteStatus({
    required int id,
    required String status,
  }) async {
    final res = await _api.post(
      ApiConfig.expenseNotesUpdateStatus,
      authRequired: true,
      body: {
        'id': id,
        'status': _backendStatusFromUi(status),
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(
        res['message'] ?? 'Failed to update expense note status',
      );
    }
  }

  String _backendStatusFromUi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return 'PAID';
      case 'cancelled':
      case 'canceled':
        return 'CANCELLED';
      case 'unpaid':
      default:
        return 'PENDING';
    }
  }

  String _uiStatusFromBackend(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return 'paid';
      case 'CANCELLED':
      case 'CANCELED':
        return 'cancelled';
      case 'PENDING':
      default:
        return 'unpaid';
    }
  }
}
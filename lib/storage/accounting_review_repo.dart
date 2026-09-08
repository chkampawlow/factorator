import 'package:my_app/core/accounting_review.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class AccountingReviewRepo {
  final ApiClient _api = ApiClient.instance;

  Future<AccountingReviewSnapshot> load() async {
    final raw = await _api.get(
      ApiConfig.accountingMobileReview,
      authRequired: true,
    );
    if (raw is! Map) throw Exception('Invalid accounting review response.');
    return AccountingReviewSnapshot.fromJson(Map<String, dynamic>.from(raw));
  }
}

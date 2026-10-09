import 'package:my_app/core/dashboard_revenue.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class DashboardRepo {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getOverview() async {
    final response = await _api.get(
      ApiConfig.dashboardOverview,
      authRequired: true,
    );
    if (response is! Map) {
      throw Exception('Invalid dashboard response');
    }
    final overview = Map<String, dynamic>.from(response);
    if (overview['success'] != true) {
      throw Exception(overview['message'] ?? 'Could not load dashboard');
    }
    if (dashboardRevenueRows(overview).length < 2) {
      try {
        final history = await _api.get(
            '${ApiConfig.baseUrl}/dashboard/monthly_revenue.php',
            authRequired: true);
        if (history is Map && history['monthly_series'] is List) {
          overview['monthly_series'] = history['monthly_series'];
        }
      } catch (_) {
        // Keep current totals available without inventing historical revenue.
      }
    }
    return overview;
  }

  Future<Map<String, dynamic>> getNotificationCounts() async {
    try {
      final response = await _api.get(
        ApiConfig.notificationOverview,
        authRequired: true,
      );
      if (response is! Map) return {};
      final envelope = Map<String, dynamic>.from(response);
      final counts = envelope['counts'];
      return counts is Map ? Map<String, dynamic>.from(counts) : {};
    } catch (_) {
      // Notifications are supplementary. A deployment that has not exposed
      // this endpoint yet must not prevent the main dashboard from loading.
      return {};
    }
  }
}

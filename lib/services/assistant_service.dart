import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class AssistantService {
  final ApiClient _api = ApiClient.instance;

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message is empty.');
    }

    final raw = await _api.post(
      ApiConfig.assistant,
      authRequired: true,
      body: {
        'message': trimmed,
      },
    );

    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid assistant response.');
    }

    final success = raw['success'] == true;
    final content = (raw['message'] ?? '').toString().trim();

    if (!success) {
      throw Exception(
        content.isEmpty ? 'The assistant is temporarily unavailable.' : content,
      );
    }

    if (content.isEmpty) {
      throw Exception('The assistant returned an empty response.');
    }

    return content;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationFeedbackResult {
  final String strength;
  final String nextTry;
  final String realWorldAction;
  final bool fallback;

  const ConversationFeedbackResult({
    required this.strength,
    required this.nextTry,
    required this.realWorldAction,
    required this.fallback,
  });
}

class ConversationFeedbackService {
  static Future<ConversationFeedbackResult> getFeedback({
    required String scenarioCode,
    required String scenarioTitle,
    required String difficulty,
    required List<Map<String, dynamic>> messages,
  }) async {
    final supabase = Supabase.instance.client;

    final session = supabase.auth.currentSession;

    if (session == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final response = await supabase.functions.invoke(
        'conversation-feedback',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'scenarioCode': scenarioCode,
          'scenarioTitle': scenarioTitle,
          'difficulty': difficulty,
          'messages': messages,
        },
      );

      if (response.status != 200) {
        throw Exception('피드백 요청 실패: ${response.status}');
      }

      final data = response.data;

      if (data is! Map) {
        throw Exception('피드백 응답 형식이 올바르지 않습니다.');
      }

      final strength = data['strength']?.toString().trim() ?? '';

      final nextTry = data['nextTry']?.toString().trim() ?? '';

      final realWorldAction = data['realWorldAction']?.toString().trim() ?? '';

      final fallback = data['fallback'] == true;

      if (strength.isEmpty || nextTry.isEmpty || realWorldAction.isEmpty) {
        throw Exception('피드백 내용이 비어 있습니다.');
      }

      return ConversationFeedbackResult(
        strength: strength,
        nextTry: nextTry,
        realWorldAction: realWorldAction,
        fallback: fallback,
      );
    } catch (e) {
      debugPrint('AI 피드백 요청 실패: $e');

      rethrow;
    }
  }
}

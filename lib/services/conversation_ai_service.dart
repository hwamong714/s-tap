
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// S-TAP AI 대화 결과
// ============================================================

class ConversationAiResult {
  final String reply;
  final bool shouldComplete;
  final int goalStep;

  const ConversationAiResult({
    required this.reply,
    required this.shouldComplete,
    required this.goalStep,
  });
}

// ============================================================
// S-TAP AI 대화 서비스
// ============================================================

class ConversationAiService {
  ConversationAiService._();

  static const Set<String> _freeConversationDomains = {
    'daily',
    'career',
    'hobby',
  };

  static Future<ConversationAiResult> getReply({
    required String scenarioCode,
    required String scenarioTitle,
    required String difficulty,
    required String roleName,
    required int goalStep,
    required int totalGoalSteps,
    required String userMessage,
    required List<Map<String, dynamic>> history,
  }) async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        '로그인 정보가 없습니다. 다시 로그인해주세요.',
      );
    }

    final trimmedUserMessage = userMessage.trim();

    if (trimmedUserMessage.isEmpty) {
      throw Exception(
        'AI에게 보낼 대화 내용이 없습니다.',
      );
    }

    // ========================================================
    // 자유 대화 / 기존 훈련 구분
    // ========================================================

    final isFreeConversation =
        _freeConversationDomains.contains(scenarioCode);

    final functionName = isFreeConversation
        ? 'free-conversation-ai'
        : 'conversation-ai';

    // ========================================================
    // 요청 데이터
    // ========================================================

    final Map<String, dynamic> requestBody;

    if (isFreeConversation) {
      requestBody = {
        'domainCode': scenarioCode,
        'userMessage': trimmedUserMessage,
        'history': history,
      };
    } else {
      // 기존 상황별 훈련 호환성 유지
      requestBody = {
        'scenarioCode': scenarioCode,
        'scenarioTitle': scenarioTitle,
        'difficulty': difficulty,
        'roleName': roleName,
        'goalStep': goalStep,
        'totalGoalSteps': totalGoalSteps,
        'userMessage': trimmedUserMessage,
        'history': history,
      };
    }

    try {
      // ======================================================
      // Supabase Edge Function 호출
      // ======================================================

      final response = await supabase.functions
          .invoke(
            functionName,
            headers: {
              'Authorization':
                  'Bearer ${session.accessToken}',
            },
            body: requestBody,
          )
          .timeout(
            Duration(
              seconds: isFreeConversation ? 40 : 18,
            ),
          );

      if (response.status < 200 ||
          response.status >= 300) {
        throw Exception(
          'AI 서버 요청 실패: ${response.status}',
        );
      }

      // ======================================================
      // 응답 JSON 처리
      // ======================================================

      dynamic data = response.data;

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw Exception(
            'AI 서버 응답 형식이 올바르지 않습니다.',
          );
        }
      }

      if (data is! Map) {
        throw Exception(
          'AI 서버에서 올바른 응답을 받지 못했습니다.',
        );
      }

      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      final reply =
          data['reply']?.toString().trim() ?? '';

      if (reply.isEmpty) {
        throw Exception(
          'AI가 대답을 생성하지 못했습니다.',
        );
      }

      // ======================================================
      // 자유 대화는 자동 종료 및 목표 단계 사용 안 함
      // ======================================================

      if (isFreeConversation) {
        debugPrint(
          'S-TAP 자유 대화 AI 응답 수신 완료',
        );

        return ConversationAiResult(
          reply: reply,
          shouldComplete: false,
          goalStep: goalStep,
        );
      }

      // ======================================================
      // 기존 훈련 결과 호환
      // ======================================================

      final shouldComplete =
          data['shouldComplete'] == true;

      int nextGoalStep = goalStep;

      final rawGoalStep = data['goalStep'];

      if (rawGoalStep is num) {
        nextGoalStep = rawGoalStep.round();
      } else {
        final parsed = int.tryParse(
          rawGoalStep?.toString() ?? '',
        );

        if (parsed != null) {
          nextGoalStep = parsed;
        }
      }

      nextGoalStep = nextGoalStep
          .clamp(1, totalGoalSteps)
          .toInt();

      return ConversationAiResult(
        reply: reply,
        shouldComplete: shouldComplete,
        goalStep: nextGoalStep,
      );
    } on TimeoutException catch (error) {
      debugPrint('AI 요청 시간 초과: $error');

      throw Exception(
        'AI 응답 시간이 너무 길어졌습니다. '
        '다시 시도해주세요.',
      );
    } catch (error) {
      debugPrint(
        'ConversationAiService 요청 실패: $error',
      );

      rethrow;
    }
  }
}

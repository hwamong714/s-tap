import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// AI 대화 결과
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
// AI 대화 서비스
// ============================================================

class ConversationAiService {
  ConversationAiService._();

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

    // ==========================================================
    // 로그인 상태 확인
    // ==========================================================

    final session = supabase.auth.currentSession;

    if (session == null) {
      throw Exception('로그인 정보가 없습니다. 다시 로그인해주세요.');
    }

    // ==========================================================
    // 사용자 발화 확인
    // ==========================================================

    final trimmedUserMessage = userMessage.trim();

    if (trimmedUserMessage.isEmpty) {
      throw Exception('AI에게 보낼 대화 내용이 없습니다.');
    }

    try {
      // ========================================================
      // Supabase Edge Function 호출
      //
      // 최대 18초까지만 기다림
      //
      // Edge Function 쪽에서:
      // Gemini 5초 timeout
      // → 필요한 경우 1회 재시도
      // → fallback
      //
      // 이 구조라면 정상적으로 18초 안에 반환되어야 함
      // ========================================================

      final response = await supabase.functions
          .invoke(
            'conversation-ai',
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
            body: {
              'scenarioCode': scenarioCode,
              'scenarioTitle': scenarioTitle,
              'difficulty': difficulty,
              'roleName': roleName,
              'goalStep': goalStep,
              'totalGoalSteps': totalGoalSteps,
              'userMessage': trimmedUserMessage,
              'history': history,
            },
          )
          .timeout(const Duration(seconds: 18));

      // ========================================================
      // HTTP 상태 확인
      // ========================================================

      if (response.status < 200 || response.status >= 300) {
        throw Exception(
          'AI 서버 요청에 실패했습니다. '
          '상태 코드: ${response.status}',
        );
      }

      // ========================================================
      // 응답 데이터 정리
      // ========================================================

      dynamic data = response.data;

      // 혹시 JSON 문자열로 오는 경우 대비
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw Exception('AI 서버의 응답 형식을 확인할 수 없습니다.');
        }
      }

      if (data is! Map) {
        throw Exception('AI 서버에서 올바른 응답을 받지 못했습니다.');
      }

      // ========================================================
      // Edge Function 오류 확인
      // ========================================================

      final error = data['error'];

      if (error != null) {
        throw Exception(error.toString());
      }

      // ========================================================
      // AI 대사
      // ========================================================

      final reply = data['reply']?.toString().trim() ?? '';

      if (reply.isEmpty) {
        throw Exception('AI가 대답을 생성하지 못했습니다.');
      }

      // ========================================================
      // AI의 훈련 종료 판단
      // ========================================================

      final shouldComplete = data['shouldComplete'] == true;

      // ========================================================
      // AI의 현재 목표 단계 판단
      // ========================================================

      int nextGoalStep = goalStep;

      final rawGoalStep = data['goalStep'];

      if (rawGoalStep is num) {
        nextGoalStep = rawGoalStep.round();
      } else {
        final parsedGoalStep = int.tryParse(rawGoalStep?.toString() ?? '');

        if (parsedGoalStep != null) {
          nextGoalStep = parsedGoalStep;
        }
      }

      // 최소 1단계
      if (nextGoalStep < 1) {
        nextGoalStep = 1;
      }

      // 최대 totalGoalSteps
      if (nextGoalStep > totalGoalSteps) {
        nextGoalStep = totalGoalSteps;
      }

      // ========================================================
      // fallback 여부 디버그 확인
      // ========================================================

      final isFallback = data['fallback'] == true;

      // ========================================================
      // 디버그 출력
      // ========================================================

      debugPrint('AI 응답: $reply');

      debugPrint(
        'AI 진행 단계: '
        '$nextGoalStep / $totalGoalSteps',
      );

      debugPrint(
        'AI 종료 판단: '
        '$shouldComplete',
      );

      debugPrint(
        'AI fallback 사용 여부: '
        '$isFallback',
      );

      // ========================================================
      // 결과 반환
      // ========================================================

      return ConversationAiResult(
        reply: reply,
        shouldComplete: shouldComplete,
        goalStep: nextGoalStep,
      );
    }
    // ==========================================================
    // Flutter 자체 timeout
    // ==========================================================
    on TimeoutException catch (error) {
      debugPrint(
        'ConversationAiService timeout: '
        '$error',
      );

      throw Exception('AI 응답 시간이 너무 길어졌습니다. 다시 시도해주세요.');
    }
    // ==========================================================
    // 기타 오류
    // ==========================================================
    catch (error) {
      debugPrint(
        'ConversationAiService 오류: '
        '$error',
      );

      rethrow;
    }
  }
}

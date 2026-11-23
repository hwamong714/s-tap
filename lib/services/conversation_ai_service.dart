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
//
// 운영 버전: AI Conversation v2.1
//
// - 일상 / 진로 / 취미 자유 대화
// - Supabase 일반 및 익명 사용자 인증
// - AI v2.1 운영 Edge Function 연결
// - 요청 메시지 및 대화 기록 길이 제한
// - AI 이용 한도 초과 안내
// - 기존 상황별 훈련 호환성 유지
// - 기존 응답 및 대화 저장 구조 유지
// ============================================================

class ConversationAiService {
  ConversationAiService._();

  // ==========================================================
  // 1. 자유 대화 영역
  // ==========================================================

  static const Set<String> _freeConversationDomains = {
    'daily',
    'career',
    'hobby',
  };

  // ==========================================================
  // 2. Edge Function 설정
  //
  // 운영 AI v2.1 함수
  // 일상 / 진로 / 취미 모두 같은 함수를 사용합니다.
  //
  // 대화 영역에 따른 프롬프트 분리는
  // Edge Function 서버 내부에서 처리합니다.
  // ==========================================================

  static const String _freeConversationFunction = 'free-conversation-ai';

  // 기존 상황별 대화 훈련용 함수
  // 구형 화면 정리가 끝나기 전까지 유지합니다.
  static const String _trainingFunction = 'conversation-ai';

  // ==========================================================
  // 3. 입력 데이터 제한
  //
  // 서버의 요청 크기 제한과 호환되도록
  // 클라이언트에서도 전송 크기를 줄입니다.
  // ==========================================================

  static const int _maxMessageLength = 2000;

  static const int _maxHistoryMessages = 10;

  static const int _maxHistoryItemLength = 600;

  static const int _maxHistoryTotalLength = 4000;

  // ==========================================================
  // 4. 자유 대화 기록 정리
  //
  // - 최근 10개 메시지 사용
  // - 각 메시지 최대 600자
  // - 전체 대화 기록 최대 4000자
  // - 서버에서 사용하는 text / isUser 형식 유지
  // - 최신 기록을 우선 보존
  //
  // 이 작업은 서버에 전송할 기록만 정리합니다.
  // Supabase에 저장된 원본 대화는 변경하지 않습니다.
  // ==========================================================

  static List<Map<String, dynamic>> _prepareHistory(
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final recentHistory = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;

    final prepared = <Map<String, dynamic>>[];

    int totalLength = 0;

    // 최신 메시지부터 확인해 필요한 맥락을 보존합니다.
    for (final item in recentHistory.reversed) {
      final rawText = item['text'];
      final rawIsUser = item['isUser'];

      if (rawText is! String || rawIsUser is! bool) {
        continue;
      }

      final text = rawText.trim();

      if (text.isEmpty) {
        continue;
      }

      final remaining = _maxHistoryTotalLength - totalLength;

      if (remaining <= 0) {
        break;
      }

      String safeText = text;

      if (safeText.length > _maxHistoryItemLength) {
        safeText = safeText.substring(0, _maxHistoryItemLength);
      }

      if (safeText.length > remaining) {
        safeText = safeText.substring(0, remaining);
      }

      if (safeText.isEmpty) {
        break;
      }

      prepared.add({'text': safeText, 'isUser': rawIsUser});

      totalLength += safeText.length;
    }

    // Gemini에는 원래 대화 순서로 전달합니다.
    return prepared.reversed.toList();
  }

  // ==========================================================
  // 5. 서버 응답 해석
  //
  // Supabase SDK에 따라 응답이 JSON 객체 또는
  // 문자열로 전달될 수 있으므로 둘 다 처리합니다.
  // ==========================================================

  static dynamic _decodeResponse(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }

    return data;
  }

  // ==========================================================
  // 6. Edge Function 오류 메시지 추출
  //
  // 서버에서 전달한 JSON의 error 필드를 읽습니다.
  // 임의의 내부 오류나 긴 응답은 사용자에게
  // 그대로 노출하지 않습니다.
  // ==========================================================

  static String? _extractServerMessage(dynamic details) {
    final data = _decodeResponse(details);

    if (data is! Map) {
      return null;
    }

    final rawMessage = data['error'];

    if (rawMessage is! String) {
      return null;
    }

    final message = rawMessage.trim();

    if (message.isEmpty || message.length > 300) {
      return null;
    }

    return message;
  }

  // ==========================================================
  // 7. HTTP 상태별 사용자 안내
  // ==========================================================

  static String _errorMessageForStatus(int status, dynamic details) {
    // 사용량 초과
    if (status == 429) {
      return _extractServerMessage(details) ??
          'AI 대화 이용 횟수에 도달했어요. '
              '잠시 후 다시 시도해 주세요.';
    }

    // 인증 실패
    if (status == 401 || status == 403) {
      return 'AI 서비스 인증에 실패했어요. '
          'S-TAP을 다시 시작해 주세요.';
    }

    // 요청 데이터 초과
    if (status == 413) {
      return '대화 데이터가 너무 커요. '
          '다시 시도해 주세요.';
    }

    // 요청 형식 오류
    if (status == 400 || status == 415) {
      return _extractServerMessage(details) ?? 'AI 요청 형식을 확인해 주세요.';
    }

    // 서버 연결 및 일시적 장애
    if (status == 500 || status == 502 || status == 503 || status == 504) {
      return 'AI 서버가 일시적으로 응답하지 않아요. '
          '잠시 후 다시 시도해 주세요.';
    }

    return 'AI 대화 요청을 처리하지 못했어요. '
        '잠시 후 다시 시도해 주세요.';
  }

  // ==========================================================
  // 8. AI 응답 요청
  // ==========================================================

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

    // ========================================================
    // 사용자 인증 확인
    //
    // Google / 이메일 로그인과
    // Supabase 익명 로그인을 모두 지원합니다.
    // ========================================================

    if (session == null) {
      throw Exception(
        '사용자 인증 정보가 없어요. '
        'S-TAP을 다시 시작해 주세요.',
      );
    }

    // ========================================================
    // 사용자 메시지 확인
    // ========================================================

    final trimmedUserMessage = userMessage.trim();

    if (trimmedUserMessage.isEmpty) {
      throw Exception('AI에게 보낼 대화 내용이 없습니다.');
    }

    if (trimmedUserMessage.length > _maxMessageLength) {
      throw Exception(
        '한 번에 보낼 수 있는 메시지는 '
        '2000자까지입니다.',
      );
    }

    // ========================================================
    // 자유 대화 / 기존 상황별 훈련 구분
    // ========================================================

    final isFreeConversation = _freeConversationDomains.contains(scenarioCode);

    final functionName = isFreeConversation
        ? _freeConversationFunction
        : _trainingFunction;

    // ========================================================
    // 요청 데이터 생성
    // ========================================================

    final Map<String, dynamic> requestBody;

    if (isFreeConversation) {
      // ------------------------------------------------------
      // AI Conversation v2.1
      //
      // daily  : 일상 대화
      // career : 진로 대화
      // hobby  : 취미 대화
      //
      // 세 영역 모두 운영 Edge Function으로 전송합니다.
      //
      // 프롬프트, TTS 서식 제거, 사용량 제한은
      // 서버의 free-conversation-ai에서 처리합니다.
      // ------------------------------------------------------

      requestBody = {
        'domainCode': scenarioCode,
        'userMessage': trimmedUserMessage,
        'history': _prepareHistory(history),
      };
    } else {
      // ------------------------------------------------------
      // 기존 상황별 훈련 호환성 유지
      //
      // 구형 기능을 아직 삭제하지 않았으므로
      // 기존 요청 형식을 유지합니다.
      // ------------------------------------------------------

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

      debugPrint(
        'S-TAP AI 요청: '
        '${isFreeConversation ? "자유 대화" : "기존 훈련"}',
      );

      final response = await supabase.functions
          .invoke(
            functionName,
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
            body: requestBody,
          )
          .timeout(Duration(seconds: isFreeConversation ? 40 : 18));

      // ======================================================
      // 응답 상태 확인
      //
      // 일부 SDK에서는 비정상 상태에서
      // FunctionException을 먼저 발생시킵니다.
      // ======================================================

      if (response.status < 200 || response.status >= 300) {
        throw Exception(_errorMessageForStatus(response.status, response.data));
      }

      // ======================================================
      // JSON 응답 처리
      // ======================================================

      final dynamic data = _decodeResponse(response.data);

      if (data is! Map) {
        throw Exception('AI 서버에서 올바른 응답을 받지 못했습니다.');
      }

      // ======================================================
      // 서버 오류 응답 확인
      // ======================================================

      if (data['error'] != null) {
        final message = _extractServerMessage(data) ?? 'AI 대화 처리 중 오류가 발생했습니다.';

        throw Exception(message);
      }

      // ======================================================
      // AI 답변 추출
      //
      // 서버 v2.1이 Markdown 기호를 정리한
      // 일반 텍스트를 반환하므로 여기서는
      // 원문을 그대로 사용합니다.
      // ======================================================

      final reply = data['reply']?.toString().trim() ?? '';

      if (reply.isEmpty) {
        throw Exception('AI가 대답을 생성하지 못했습니다.');
      }

      // ======================================================
      // 자유 대화 응답 처리
      //
      // - 자동 종료 없음
      // - 목표 단계 없음
      // - 기존 대화 화면 및 저장 로직 유지
      // ======================================================

      if (isFreeConversation) {
        debugPrint('S-TAP AI v2.1 자유 대화 응답 완료');

        return ConversationAiResult(
          reply: reply,
          shouldComplete: false,
          goalStep: goalStep,
        );
      }

      // ======================================================
      // 기존 상황별 훈련 응답 처리
      // ======================================================

      final shouldComplete = data['shouldComplete'] == true;

      int nextGoalStep = goalStep;

      final rawGoalStep = data['goalStep'];

      if (rawGoalStep is num) {
        nextGoalStep = rawGoalStep.round();
      } else {
        final parsed = int.tryParse(rawGoalStep?.toString() ?? '');

        if (parsed != null) {
          nextGoalStep = parsed;
        }
      }

      nextGoalStep = nextGoalStep.clamp(1, totalGoalSteps).toInt();

      debugPrint('S-TAP 기존 상황별 훈련 응답 완료');

      return ConversationAiResult(
        reply: reply,
        shouldComplete: shouldComplete,
        goalStep: nextGoalStep,
      );
    }
    // ========================================================
    // 네트워크 요청 시간 초과
    // ========================================================
    on TimeoutException catch (_) {
      debugPrint('S-TAP AI 요청 시간 초과');

      throw Exception(
        'AI 응답 시간이 너무 길어졌어요. '
        '잠시 후 다시 시도해 주세요.',
      );
    }
    // ========================================================
    // Supabase Edge Function 오류
    //
    // 429 사용량 초과 등 비정상 HTTP 상태가
    // 예외로 전달되는 경우를 처리합니다.
    // ========================================================
    on FunctionException catch (error) {
      debugPrint(
        'S-TAP AI Edge Function 오류: '
        'HTTP ${error.status}',
      );

      throw Exception(_errorMessageForStatus(error.status, error.details));
    }
    // ========================================================
    // 그 밖의 오류
    //
    // JWT, 사용자의 원문 메시지 등 민감한 정보는
    // 디버그 로그에 출력하지 않습니다.
    // ========================================================
    catch (error) {
      debugPrint(
        'S-TAP AI 요청 처리 오류: '
        '${error.runtimeType}',
      );

      rethrow;
    }
  }
}

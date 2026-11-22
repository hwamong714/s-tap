
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// S-TAP AI 자유 대화 기록 저장 서비스
//
// 사용하는 Supabase 테이블
// 1. ai_conversation_sessions
// 2. ai_conversation_messages
// 3. ai_conversation_activity_days
//
// 대화 원문은 사용자가 저장에 동의한 경우에만 저장합니다.
// ============================================================

class AiConversationStorageService {
  AiConversationStorageService._();

  static SupabaseClient get _client =>
      Supabase.instance.client;

  // ----------------------------------------------------------
  // 현재 로그인 사용자
  // ----------------------------------------------------------

  static String get _userId {
    final id = _client.auth.currentUser?.id;

    if (id == null) {
      throw StateError(
        '대화 기록을 이용하려면 로그인이 필요합니다.',
      );
    }

    return id;
  }

  // ----------------------------------------------------------
  // 저장된 대화 목록 불러오기
  // ----------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getSessions(
    String domainCode,
  ) async {
    final data = await _client
        .from('ai_conversation_sessions')
        .select(
          'id, domain_code, title, created_at, last_message_at',
        )
        .eq('user_id', _userId)
        .eq('domain_code', domainCode)
        .eq('save_history_enabled', true)
        .order('last_message_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(data);
  }

  // ----------------------------------------------------------
  // 새로운 대화 세션 생성
  //
  // AI 응답이 성공한 후에만 생성합니다.
  // 따라서 대화를 시작했다가 바로 나간 경우에는
  // 빈 세션이 불필요하게 남지 않습니다.
  // ----------------------------------------------------------

  static Future<String> createSession({
    required String domainCode,
    required String title,
  }) async {
    final data = await _client
        .from('ai_conversation_sessions')
        .insert({
          'user_id': _userId,
          'domain_code': domainCode,
          'title': title,
          'save_history_enabled': true,
          'history_consent_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    return data['id'].toString();
  }

  // ----------------------------------------------------------
  // 기존 대화 메시지 불러오기
  //
  // 최근 200개 메시지를 시간순으로 반환합니다.
  // ----------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getMessages(
    String sessionId,
  ) async {
    final data = await _client
        .from('ai_conversation_messages')
        .select('id, role, content, created_at')
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .limit(200);

    return List<Map<String, dynamic>>.from(
      data.reversed,
    );
  }

  // ----------------------------------------------------------
  // 사용자 메시지 + AI 응답 저장
  //
  // 한 번의 insert 요청으로 두 메시지를 저장합니다.
  // ----------------------------------------------------------

  static Future<void> saveExchange({
    required String sessionId,
    required String userText,
    required String aiText,
  }) async {
    final timestamp = DateTime.now().toUtc();

    await _client.from('ai_conversation_messages').insert([
      {
        'session_id': sessionId,
        'role': 'user',
        'content': userText,
        'created_at': timestamp.toIso8601String(),
      },
      {
        'session_id': sessionId,
        'role': 'assistant',
        'content': aiText,
        'created_at': timestamp
            .add(const Duration(milliseconds: 1))
            .toIso8601String(),
      },
    ]);

    // 대화 목록의 최근 활동 시간 갱신
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      await _client
          .from('ai_conversation_sessions')
          .update({
            'last_message_at': now,
            'updated_at': now,
          })
          .eq('id', sessionId)
          .eq('user_id', _userId);
    } catch (_) {
      // 메시지 저장 자체는 성공했으므로
      // 최근 활동 시간 갱신 오류는 별도로 처리합니다.
    }
  }

  // ----------------------------------------------------------
  // AI 대화 참여 날짜 기록
  //
  // AI 응답이 정상 생성된 이후에만 호출합니다.
  // 같은 날짜에 여러 번 대화해도 한 번만 저장됩니다.
  // ----------------------------------------------------------

  static Future<void> recordConversationDay() async {
    final today = _koreaDate(DateTime.now());

    await _client
        .from('ai_conversation_activity_days')
        .upsert(
      {
        'user_id': _userId,
        'activity_date': today,
      },
      onConflict: 'user_id,activity_date',
      ignoreDuplicates: true,
    );
  }

  // ----------------------------------------------------------
  // 이번 주 AI 대화 참여 일수
  //
  // 월요일 ~ 일요일, 한국 시간 기준
  // ----------------------------------------------------------

  static Future<int> getThisWeekActiveDays() async {
    final koreaNow = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 9));

    final monday = DateTime.utc(
      koreaNow.year,
      koreaNow.month,
      koreaNow.day,
    ).subtract(
      Duration(
        days: koreaNow.weekday - DateTime.monday,
      ),
    );

    final sunday = monday.add(
      const Duration(days: 6),
    );

    final rows = await _client
        .from('ai_conversation_activity_days')
        .select('activity_date')
        .eq('user_id', _userId)
        .gte('activity_date', _formatDate(monday))
        .lte('activity_date', _formatDate(sunday));

    return rows.length;
  }

  // ----------------------------------------------------------
  // 대화 세션 삭제
  //
  // 메시지 테이블은 ON DELETE CASCADE이므로
  // 해당 세션의 메시지도 함께 삭제됩니다.
  //
  // 참여 날짜 기록은 별도로 유지됩니다.
  // ----------------------------------------------------------

  static Future<void> deleteSession(
    String sessionId,
  ) async {
    await _client
        .from('ai_conversation_sessions')
        .delete()
        .eq('id', sessionId)
        .eq('user_id', _userId);
  }

  // ----------------------------------------------------------
  // 한국 날짜 계산
  // ----------------------------------------------------------

  static String _koreaDate(DateTime time) {
    final koreaTime = time
        .toUtc()
        .add(const Duration(hours: 9));

    return _formatDate(koreaTime);
  }

  static String _formatDate(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

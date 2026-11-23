import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'life_status_screen.dart';

// ============================================================
// S-TAP 나의 기록 화면 v2.2
//
// 주요 기능
// 1. 이번 주 AI 대화 참여일
// 2. 이번 주 일상 미션 완료 횟수
// 3. 이번 주 활동한 날짜 수
// 4. 생활상태 체크인
// 5. 최근 생활 변화 비교
// 6. 최근 AI 대화 참여 날짜
//
// AI 대화 활동 데이터:
// ai_conversation_activity_days
//
// 기존 conversation_training_records는 사용하지 않음.
//
// 대화 원문은 조회하지 않음.
// ============================================================

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ==========================================================
  // 색상
  // ==========================================================

  static const Color primaryColor = Color(0xFF00A87E);
  static const Color missionColor = Color(0xFFEF8B2C);
  static const Color activityColor = Color(0xFF5278CE);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color darkColor = Color(0xFF17201D);

  // ==========================================================
  // 상태
  // ==========================================================

  bool isLoading = true;

  // 이번 주 AI 대화 참여일
  int conversationDayCount = 0;

  // 이번 주 일상 미션 완료 횟수
  int missionCount = 0;

  // 이번 주 활동한 날짜 수
  int activeDayCount = 0;

  // 이번 주 생활상태 체크인 여부
  bool hasCheckinThisWeek = false;

  // 최근 생활상태
  Map<String, dynamic>? latestLifeStatus;

  // 직전 생활상태
  Map<String, dynamic>? previousLifeStatus;

  // 최근 AI 대화 참여 날짜
  List<String> recentConversationDays = [];

  // ==========================================================
  // 초기화
  // ==========================================================

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ==========================================================
  // 한국 시간 기준 현재 날짜
  //
  // 브라우저 시간대와 무관하게
  // 한국의 날짜를 기준으로 통계를 계산합니다.
  // ==========================================================

  DateTime _koreaNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 9));
  }

  // ==========================================================
  // 날짜 -> YYYY-MM-DD
  // ==========================================================

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ==========================================================
  // 이번 주 월요일
  //
  // 날짜 계산은 한국 기준 달력 날짜를 사용합니다.
  // ==========================================================

  DateTime _getMonday(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);

    return normalized.subtract(Duration(days: date.weekday - 1));
  }

  // ==========================================================
  // 한국 시간의 주간 시작 시각을 UTC로 변환
  //
  // 생활상태 completed_at은 timestamp이므로
  // UTC 범위로 조회합니다.
  // ==========================================================

  DateTime _koreaMidnightToUtc(DateTime date) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(const Duration(hours: 9));
  }

  // ==========================================================
  // 기록 데이터 불러오기
  // ==========================================================

  Future<void> _loadRecords() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          conversationDayCount = 0;
          missionCount = 0;
          activeDayCount = 0;
          hasCheckinThisWeek = false;
          latestLifeStatus = null;
          previousLifeStatus = null;
          recentConversationDays = [];
          isLoading = false;
        });

        return;
      }

      // ------------------------------------------------------
      // 이번 주 날짜 범위
      // ------------------------------------------------------

      final now = _koreaNow();

      final monday = _getMonday(now);
      final sunday = monday.add(const Duration(days: 6));
      final nextMonday = monday.add(const Duration(days: 7));

      final mondayDate = _dateString(monday);
      final sundayDate = _dateString(sunday);

      final mondayUtc = _koreaMidnightToUtc(monday).toIso8601String();

      final nextMondayUtc = _koreaMidnightToUtc(nextMonday).toIso8601String();

      // ======================================================
      // 필요한 데이터 동시 조회
      // ======================================================

      final results = await Future.wait([
        // ----------------------------------------------------
        // 1. 이번 주 AI 대화 참여 날짜
        //
        // 기존 대화 리허설 기록이 아니라
        // 현재 AI 대화의 활동 날짜를 사용합니다.
        // ----------------------------------------------------

        supabase
            .from('ai_conversation_activity_days')
            .select('activity_date')
            .eq('user_id', user.id)
            .gte('activity_date', mondayDate)
            .lte('activity_date', sundayDate),

        // ----------------------------------------------------
        // 2. 이번 주 완료한 일상 미션
        // ----------------------------------------------------
        supabase
            .from('mission_records')
            .select('record_date, status')
            .eq('user_id', user.id)
            .eq('status', 'completed')
            .gte('record_date', mondayDate)
            .lte('record_date', sundayDate),

        // ----------------------------------------------------
        // 3. 최근 생활상태
        //
        // initial + checkin 중 최근 2개
        // ----------------------------------------------------
        supabase
            .from('life_status_assessments')
            .select(
              'id, '
              'assessment_type, '
              'outing_days_7d, '
              'avg_outing_minutes_7d, '
              'interaction_days_7d, '
              'outing_burden, '
              'duration_months, '
              'completed_at',
            )
            .eq('user_id', user.id)
            .order('completed_at', ascending: false)
            .limit(2),

        // ----------------------------------------------------
        // 4. 이번 주 생활상태 체크인
        // ----------------------------------------------------
        supabase
            .from('life_status_assessments')
            .select('id, completed_at')
            .eq('user_id', user.id)
            .eq('assessment_type', 'checkin')
            .gte('completed_at', mondayUtc)
            .lt('completed_at', nextMondayUtc),

        // ----------------------------------------------------
        // 5. 최근 AI 대화 참여 날짜 5개
        //
        // 사용자가 원문 저장에 동의하지 않아도
        // 참여 날짜만 표시할 수 있습니다.
        // ----------------------------------------------------
        supabase
            .from('ai_conversation_activity_days')
            .select('activity_date')
            .eq('user_id', user.id)
            .order('activity_date', ascending: false)
            .limit(5),
      ]);

      // ======================================================
      // 조회 결과 변환
      // ======================================================

      final weeklyConversations = List<Map<String, dynamic>>.from(results[0]);

      final weeklyMissions = List<Map<String, dynamic>>.from(results[1]);

      final lifeStatuses = List<Map<String, dynamic>>.from(results[2]);

      final weeklyCheckins = List<Map<String, dynamic>>.from(results[3]);

      final recentConversations = List<Map<String, dynamic>>.from(results[4]);

      // ======================================================
      // 이번 주 AI 대화 참여일 계산
      //
      // 하루 동안 여러 번 메시지를 보내더라도
      // 1일로 계산합니다.
      // ======================================================

      final conversationDates = <String>{};

      for (final record in weeklyConversations) {
        final date = record['activity_date']?.toString();

        if (date != null && date.isNotEmpty) {
          conversationDates.add(date);
        }
      }

      // ======================================================
      // 일상 미션 완료 날짜 계산
      // ======================================================

      final missionDates = <String>{};

      for (final mission in weeklyMissions) {
        final date = mission['record_date']?.toString();

        if (date != null && date.isNotEmpty) {
          missionDates.add(date);
        }
      }

      // ======================================================
      // 이번 주 활동한 날짜 수
      //
      // AI 대화 참여일 ∪ 일상 미션 완료일
      //
      // 같은 날 두 활동을 모두 해도 1일로 계산
      // ======================================================

      final activeDates = <String>{...conversationDates, ...missionDates};

      // ======================================================
      // 최근 AI 대화 참여 날짜
      // ======================================================

      final loadedRecentDays = <String>{};

      for (final record in recentConversations) {
        final date = record['activity_date']?.toString();

        if (date != null && date.isNotEmpty) {
          loadedRecentDays.add(date);
        }
      }

      if (!mounted) return;

      // ======================================================
      // 상태 업데이트
      // ======================================================

      setState(() {
        conversationDayCount = conversationDates.length;

        missionCount = weeklyMissions.length;

        activeDayCount = activeDates.length;

        hasCheckinThisWeek = weeklyCheckins.isNotEmpty;

        latestLifeStatus = lifeStatuses.isNotEmpty ? lifeStatuses[0] : null;

        previousLifeStatus = lifeStatuses.length >= 2 ? lifeStatuses[1] : null;

        recentConversationDays = loadedRecentDays.toList();

        isLoading = false;
      });
    } catch (error) {
      debugPrint('기록 화면 데이터 불러오기 오류: $error');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '기록을 불러오지 못했어요. '
            '잠시 후 다시 시도해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================
  // 생활상태 체크인 화면 열기
  // ==========================================================

  Future<void> _openLifeStatusCheckin() async {
    if (hasCheckinThisWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이번 주 생활상태는 이미 기록했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LifeStatusScreen(isCheckin: true),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadRecords();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이번 주 생활상태를 기록했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================
  // timestamp 날짜 표시
  //
  // 한국 시간으로 변환
  // ==========================================================

  String _displayDate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final koreaDate = date.toUtc().add(const Duration(hours: 9));

    return '${koreaDate.month}월 ${koreaDate.day}일';
  }

  // ==========================================================
  // 날짜만 저장된 activity_date 표시
  // ==========================================================

  String _displayActivityDate(String dateString) {
    final date = DateTime.tryParse(dateString);

    if (date == null) {
      return dateString;
    }

    return '${date.year}년 '
        '${date.month}월 '
        '${date.day}일';
  }

  // ==========================================================
  // 이번 주 날짜 범위
  // ==========================================================

  String _weeklyPeriodText() {
    final monday = _getMonday(_koreaNow());

    final sunday = monday.add(const Duration(days: 6));

    return '${monday.month}월 ${monday.day}일'
        ' ~ '
        '${sunday.month}월 ${sunday.day}일';
  }

  // ==========================================================
  // 숫자 변환
  // ==========================================================

  int _intValue(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;

    final value = data[key];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ==========================================================
  // 메인 화면
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: darkColor,
          ),
        ),
        title: const Text(
          '기록',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),
        centerTitle: true,
      ),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _loadRecords,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),
          child: isLoading
              ? const SizedBox(
                  height: 520,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(),

                    const SizedBox(height: 18),

                    _buildWeeklySummary(),

                    const SizedBox(height: 18),

                    _buildLifeStatusCard(),

                    if (latestLifeStatus != null &&
                        previousLifeStatus != null) ...[
                      const SizedBox(height: 18),

                      _buildLifeChangeCard(),
                    ],

                    const SizedBox(height: 26),

                    _buildRecentConversationSection(),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================
  // 상단 설명
  // ==========================================================

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '나의 기록',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'S-TAP에서 해본 활동과 '
          '생활의 변화를 확인해보세요.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 이번 주 활동 요약
  // ==========================================================

  Widget _buildWeeklySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3EAE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '이번 주 활동',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: darkColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F4),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _weeklyPeriodText(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF69736F),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            '이번 주에 내가 참여한 활동이에요.',
            style: TextStyle(fontSize: 13.5, color: Colors.black54),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              // ------------------------------------------------
              // AI 대화 참여일
              // ------------------------------------------------

              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: primaryColor,
                  value: '$conversationDayCount일',
                  label: 'AI 대화 참여일',
                ),
              ),

              const SizedBox(width: 9),

              // ------------------------------------------------
              // 일상 미션 완료
              // ------------------------------------------------
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.directions_walk_rounded,
                  color: missionColor,
                  value: '$missionCount회',
                  label: '일상 미션',
                ),
              ),

              const SizedBox(width: 9),

              // ------------------------------------------------
              // 전체 활동 날짜
              // ------------------------------------------------
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.calendar_today_rounded,
                  color: activityColor,
                  value: '$activeDayCount일',
                  label: '활동한 날',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 요약 아이템
  // ==========================================================

  Widget _buildSummaryItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 27, color: color),

          const SizedBox(height: 9),

          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: darkColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 생활상태 카드
  //
  // 기존 기능 유지
  // ==========================================================

  Widget _buildLifeStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: primaryColor,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '생활상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: darkColor,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      '최근 7일의 생활을 돌아봐요.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              if (hasCheckinThisWeek)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '이번 주 완료',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),

          // ----------------------------------------------------
          // 최근 생활상태
          // ----------------------------------------------------
          if (latestLifeStatus != null) ...[
            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildLifeMiniItem(
                      label: '외출',
                      value:
                          '${_intValue(latestLifeStatus, 'outing_days_7d')}일',
                    ),
                  ),

                  _buildMiniDivider(),

                  Expanded(
                    child: _buildLifeMiniItem(
                      label: '대면 교류',
                      value:
                          '${_intValue(latestLifeStatus, 'interaction_days_7d')}일',
                    ),
                  ),

                  _buildMiniDivider(),

                  Expanded(
                    child: _buildLifeMiniItem(
                      label: '외출 부담',
                      value:
                          '${_intValue(latestLifeStatus, 'outing_burden')}/10',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              '최근 기록 · '
              '${_displayDate(latestLifeStatus?['completed_at']?.toString())}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
          ] else ...[
            const SizedBox(height: 18),

            const Text(
              '아직 저장된 생활상태 기록이 없어요.',
              style: TextStyle(fontSize: 13.5, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // 이번 주 생활상태 체크인 버튼
          // ----------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: hasCheckinThisWeek ? null : _openLifeStatusCheckin,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD5E5DF),
                disabledForegroundColor: const Color(0xFF73817C),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                hasCheckinThisWeek
                    ? Icons.check_circle_rounded
                    : Icons.edit_calendar_rounded,
                size: 20,
              ),
              label: Text(
                hasCheckinThisWeek ? '이번 주 생활상태 기록 완료' : '이번 주 생활상태 기록하기',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 생활상태 미니 아이템
  // ==========================================================

  Widget _buildLifeMiniItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildMiniDivider() {
    return Container(width: 1, height: 35, color: const Color(0xFFE5ECE9));
  }

  // ==========================================================
  // 최근 생활 변화
  //
  // 기존 기능 유지
  // ==========================================================

  Widget _buildLifeChangeCard() {
    final latest = latestLifeStatus!;
    final previous = previousLifeStatus!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3EAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 생활 변화',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: darkColor,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '${_displayDate(previous['completed_at']?.toString())}'
            ' 기록과 비교했어요.',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),

          const SizedBox(height: 18),

          _buildChangeRow(
            label: '외출한 날',
            before: '${_intValue(previous, 'outing_days_7d')}일',
            after: '${_intValue(latest, 'outing_days_7d')}일',
          ),

          _buildChangeRow(
            label: '평균 외출시간',
            before: '${_intValue(previous, 'avg_outing_minutes_7d')}분',
            after: '${_intValue(latest, 'avg_outing_minutes_7d')}분',
          ),

          _buildChangeRow(
            label: '대면 교류',
            before: '${_intValue(previous, 'interaction_days_7d')}일',
            after: '${_intValue(latest, 'interaction_days_7d')}일',
          ),

          _buildChangeRow(
            label: '외출 부담',
            before: '${_intValue(previous, 'outing_burden')}/10',
            after: '${_intValue(latest, 'outing_burden')}/10',
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 생활상태 비교 행
  // ==========================================================

  Widget _buildChangeRow({
    required String label,
    required String before,
    required String after,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0F3F2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF58625E),
              ),
            ),
          ),

          Text(
            before,
            style: const TextStyle(fontSize: 14, color: Colors.black45),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: primaryColor,
            ),
          ),

          SizedBox(
            width: 52,
            child: Text(
              after,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: darkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 최근 AI 대화 참여 날짜
  //
  // 과거 "최근 대화 리허설" 영역 대체
  //
  // 개인정보 보호를 위해
  // 대화 메시지 내용은 표시하지 않습니다.
  // ==========================================================

  Widget _buildRecentConversationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 AI 대화 참여',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          '최근 AI와 대화에 참여한 날짜를 확인해 보세요.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),

        const SizedBox(height: 13),

        // ----------------------------------------------------
        // 기록 없음
        // ----------------------------------------------------
        if (recentConversationDays.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5EBE9)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 31,
                  color: Colors.black26,
                ),

                SizedBox(height: 11),

                Text(
                  '아직 AI 대화 참여 기록이 없어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Colors.black54),
                ),
              ],
            ),
          )
        else
          // --------------------------------------------------
          // 최근 참여 날짜
          // --------------------------------------------------
          ...recentConversationDays.map((date) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5EBE9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: primaryColor,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 대화에 참여했어요',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: darkColor,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _displayActivityDate(date),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

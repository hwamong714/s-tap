import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'life_status_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ============================================================
  // 색상
  // ============================================================

  static const Color primaryColor = Color(0xFF00A87E);

  static const Color missionColor = Color(0xFFEF8B2C);

  static const Color backgroundColor = Color(0xFFF5FFFB);

  static const Color darkColor = Color(0xFF17201D);

  // ============================================================
  // 상태
  // ============================================================

  bool isLoading = true;

  // 이번 주 대화 리허설 횟수
  int trainingCount = 0;

  // 이번 주 일상 미션 완료 횟수
  int missionCount = 0;

  // 이번 주 활동한 날짜 수
  int activeDayCount = 0;

  // 이번 주 생활상태 체크인 완료 여부
  bool hasCheckinThisWeek = false;

  // 최근 생활상태
  Map<String, dynamic>? latestLifeStatus;

  // 직전 생활상태
  Map<String, dynamic>? previousLifeStatus;

  // 최근 대화 리허설
  List<Map<String, dynamic>> recentTrainings = [];

  // ============================================================
  // 초기화
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadRecords();
  }

  // ============================================================
  // 날짜 → YYYY-MM-DD
  // ============================================================

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // 이번 주 월요일
  // ============================================================

  DateTime _getMonday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  // ============================================================
  // 기록 데이터 불러오기
  // ============================================================

  Future<void> _loadRecords() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        return;
      }

      final now = DateTime.now();

      final monday = _getMonday(now);

      final sunday = monday.add(const Duration(days: 6));

      final nextMonday = monday.add(const Duration(days: 7));

      // ========================================================
      // 필요한 데이터 동시에 조회
      // ========================================================

      final results = await Future.wait([
        // ------------------------------------------------------
        // 1. 이번 주 대화 리허설
        // ------------------------------------------------------

        Supabase.instance.client
            .from('conversation_training_records')
            .select(
              'scenario_code, '
              'scenario_title, '
              'difficulty, '
              'completed_at',
            )
            .eq('user_id', user.id)
            .gte('completed_at', monday.toUtc().toIso8601String())
            .lt('completed_at', nextMonday.toUtc().toIso8601String()),

        // ------------------------------------------------------
        // 2. 이번 주 일상 미션
        // ------------------------------------------------------
        Supabase.instance.client
            .from('mission_records')
            .select('record_date, status')
            .eq('user_id', user.id)
            .eq('status', 'completed')
            .gte('record_date', _dateString(monday))
            .lte('record_date', _dateString(sunday)),

        // ------------------------------------------------------
        // 3. 최근 생활상태 기록
        //
        // 초기 + checkin 모두 포함
        // 최신순 2개
        // ------------------------------------------------------
        Supabase.instance.client
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

        // ------------------------------------------------------
        // 4. 최근 대화 리허설 5개
        // ------------------------------------------------------
        Supabase.instance.client
            .from('conversation_training_records')
            .select(
              'scenario_code, '
              'scenario_title, '
              'difficulty, '
              'completed_at',
            )
            .eq('user_id', user.id)
            .order('completed_at', ascending: false)
            .limit(5),

        // ------------------------------------------------------
        // 5. 이번 주 생활상태 checkin 존재 여부
        // ------------------------------------------------------
        Supabase.instance.client
            .from('life_status_assessments')
            .select('id, completed_at')
            .eq('user_id', user.id)
            .eq('assessment_type', 'checkin')
            .gte('completed_at', monday.toUtc().toIso8601String())
            .lt('completed_at', nextMonday.toUtc().toIso8601String()),
      ]);

      // ========================================================
      // 데이터 변환
      // ========================================================

      final weeklyTrainings = List<Map<String, dynamic>>.from(
        results[0] as List,
      );

      final weeklyMissions = List<Map<String, dynamic>>.from(
        results[1] as List,
      );

      final lifeStatuses = List<Map<String, dynamic>>.from(results[2] as List);

      final loadedRecentTrainings = List<Map<String, dynamic>>.from(
        results[3] as List,
      );

      final weeklyCheckins = List<Map<String, dynamic>>.from(
        results[4] as List,
      );

      // ========================================================
      // 이번 주 활동한 날짜 계산
      // ========================================================

      final activeDates = <String>{};

      // 대화 리허설 날짜
      for (final training in weeklyTrainings) {
        final completedAt = training['completed_at']?.toString();

        if (completedAt == null || completedAt.isEmpty) {
          continue;
        }

        final parsedDate = DateTime.tryParse(completedAt);

        if (parsedDate == null) {
          continue;
        }

        activeDates.add(_dateString(parsedDate.toLocal()));
      }

      // 일상 미션 날짜
      for (final mission in weeklyMissions) {
        final recordDate = mission['record_date']?.toString();

        if (recordDate == null || recordDate.isEmpty) {
          continue;
        }

        activeDates.add(recordDate);
      }

      // ========================================================
      // 상태 반영
      // ========================================================

      if (!mounted) {
        return;
      }

      setState(() {
        trainingCount = weeklyTrainings.length;

        missionCount = weeklyMissions.length;

        activeDayCount = activeDates.length;

        hasCheckinThisWeek = weeklyCheckins.isNotEmpty;

        latestLifeStatus = lifeStatuses.isNotEmpty ? lifeStatuses[0] : null;

        previousLifeStatus = lifeStatuses.length >= 2 ? lifeStatuses[1] : null;

        recentTrainings = loadedRecentTrainings;

        isLoading = false;
      });
    } catch (error) {
      debugPrint('기록 화면 데이터 불러오기 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기록을 불러오지 못했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // 생활상태 기록 화면 열기
  // ============================================================

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

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _loadRecords();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이번 주 생활상태를 기록했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // 날짜 표시
  // ============================================================

  String _displayDate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final local = date.toLocal();

    return '${local.month}월 ${local.day}일';
  }

  // ============================================================
  // 이번 주 날짜 범위
  // ============================================================

  String _weeklyPeriodText() {
    final monday = _getMonday(DateTime.now());

    final sunday = monday.add(const Duration(days: 6));

    return '${monday.month}월 ${monday.day}일'
        ' ~ '
        '${sunday.month}월 ${sunday.day}일';
  }

  // ============================================================
  // 숫자 가져오기
  // ============================================================

  int _intValue(Map<String, dynamic>? data, String key) {
    if (data == null) {
      return 0;
    }

    final value = data[key];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // 화면
  // ============================================================

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

                    _buildRecentTrainingSection(),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // 상단 설명
  // ============================================================

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

  // ============================================================
  // 이번 주 활동 요약
  // ============================================================

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
            '이번 주에 내가 해본 활동이에요.',

            style: TextStyle(fontSize: 13.5, color: Colors.black54),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.chat_bubble_outline_rounded,

                  color: primaryColor,

                  value: '$trainingCount회',

                  label: '대화 리허설',
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.directions_walk_rounded,

                  color: missionColor,

                  value: '$missionCount회',

                  label: '일상 미션',
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.calendar_today_rounded,

                  color: const Color(0xFF5278CE),

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

  // ============================================================
  // 생활상태 카드
  // ============================================================

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

  // ============================================================
  // 최근 생활 변화
  // ============================================================

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

  // ============================================================
  // 최근 대화 리허설
  // ============================================================

  Widget _buildRecentTrainingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          '최근 대화 리허설',

          style: TextStyle(
            fontSize: 19,

            fontWeight: FontWeight.w900,

            color: darkColor,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          '최근 완료한 대화 리허설 기록이에요.',

          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),

        const SizedBox(height: 13),

        if (recentTrainings.isEmpty)
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
                  '아직 완료한 대화 리허설이 없어요.',

                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 13.5, color: Colors.black54),
                ),
              ],
            ),
          )
        else
          ...recentTrainings.map((record) {
            final title = record['scenario_title']?.toString() ?? '대화 리허설';

            final difficulty = record['difficulty']?.toString() ?? '';

            final date = _displayDate(record['completed_at']?.toString());

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
                        Text(
                          title,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 15,

                            fontWeight: FontWeight.w800,

                            color: darkColor,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          [
                            if (difficulty.isNotEmpty) difficulty,

                            if (date.isNotEmpty) date,
                          ].join(' · '),

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

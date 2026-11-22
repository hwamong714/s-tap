import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mission_recommendation_service.dart';

import 'conversation_training_screen.dart';
import 'mission_recommendation_screen.dart';
import 'my_page_screen.dart';
import 'record_screen.dart';

// ============================================================
// S-TAP HOME SCREEN
//
// 기존 홈 화면 디자인 유지
// + 맞춤형 일상 미션 추천 v2.0
// + 주간 생활상태 기반 난이도
// + 미션 수행 피드백 반영
// + AI 대화 참여 날짜 표시
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color missionColor = Color(0xFFEF8B2C);

  // ============================================================
  // 프로필
  // ============================================================

  String nickname = '사용자';
  String avatarType = 'emoji';
  String avatarEmoji = '🌱';

  String? profileImageUrl;

  bool isLoadingProfile = true;

  // ============================================================
  // 주간 활동
  // ============================================================

  bool isLoadingWeeklyProgress = true;

  final Set<String> missionCompletedDates = {};
  final Set<String> conversationActiveDates = {};

  // ============================================================
  // 맞춤형 일상 미션
  // ============================================================

  MissionRecommendationResult? missionRecommendation;

  bool isLoadingMissionRecommendation = true;

  String? missionRecommendationError;

  // ============================================================
  // 초기화
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
    _loadWeeklyProgress();
    _loadMissionRecommendation();
  }

  // ============================================================
  // 날짜 유틸리티
  // ============================================================

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime _koreaNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 9));
  }

  DateTime _getMonday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  // ============================================================
  // 홈 새로고침
  // ============================================================

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadProfile(),
      _loadWeeklyProgress(),
      _loadMissionRecommendation(),
    ]);
  }

  // ============================================================
  // 맞춤형 일상 미션 불러오기
  //
  // MissionRecommendationService v2.0 사용
  //
  // 초기 생활상태
  // → 주간 생활상태
  // → 미션 수행 피드백
  // → 추천 점수 계산
  // ============================================================

  Future<void> _loadMissionRecommendation() async {
    if (mounted) {
      setState(() {
        isLoadingMissionRecommendation = true;
        missionRecommendationError = null;
      });
    }

    try {
      final result = await MissionRecommendationService.load();

      if (!mounted) return;

      setState(() {
        missionRecommendation = result;
        isLoadingMissionRecommendation = false;
        missionRecommendationError = null;
      });
    } catch (error) {
      debugPrint('홈 미션 추천 불러오기 오류: $error');

      if (!mounted) return;

      setState(() {
        missionRecommendation = null;
        isLoadingMissionRecommendation = false;
        missionRecommendationError = '추천 정보를 불러오지 못했어요.';
      });
    }
  }

  // ============================================================
  // 프로필 불러오기
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          nickname = '사용자';
          avatarType = 'emoji';
          avatarEmoji = '🌱';
          profileImageUrl = null;
          isLoadingProfile = false;
        });

        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles_v2')
          .select(
            'nickname, '
            'avatar_type, '
            'avatar_emoji, '
            'profile_image_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final storedProfileImagePath = profile?['profile_image_url']?.toString();

      String? loadedProfileImageUrl;

      if (storedProfileImagePath != null &&
          storedProfileImagePath.trim().isNotEmpty) {
        try {
          if (storedProfileImagePath.startsWith('http://') ||
              storedProfileImagePath.startsWith('https://')) {
            loadedProfileImageUrl = storedProfileImagePath;
          } else {
            loadedProfileImageUrl = await Supabase.instance.client.storage
                .from('profile-images')
                .createSignedUrl(storedProfileImagePath, 60 * 60);
          }
        } catch (_) {
          loadedProfileImageUrl = null;
        }
      }

      if (!mounted) return;

      setState(() {
        nickname = profile?['nickname']?.toString() ?? '사용자';

        avatarType = profile?['avatar_type']?.toString() ?? 'emoji';

        avatarEmoji = profile?['avatar_emoji']?.toString() ?? '🌱';

        profileImageUrl = loadedProfileImageUrl;

        isLoadingProfile = false;
      });
    } catch (error) {
      debugPrint('프로필 불러오기 오류: $error');

      if (!mounted) return;

      setState(() {
        nickname = '사용자';
        avatarType = 'emoji';
        avatarEmoji = '🌱';
        profileImageUrl = null;
        isLoadingProfile = false;
      });
    }
  }

  // ============================================================
  // 이번 주 활동 기록
  //
  // 일상 미션: mission_records
  // AI 대화: ai_conversation_activity_days
  //
  // 한국 날짜 기준 월요일 ~ 일요일
  // ============================================================

  Future<void> _loadWeeklyProgress() async {
    if (mounted) {
      setState(() {
        isLoadingWeeklyProgress = true;
      });
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          missionCompletedDates.clear();
          conversationActiveDates.clear();
          isLoadingWeeklyProgress = false;
        });

        return;
      }

      final now = _koreaNow();
      final monday = _getMonday(now);
      final sunday = monday.add(const Duration(days: 6));

      final mondayString = _dateString(monday);
      final sundayString = _dateString(sunday);

      final results = await Future.wait([
        Supabase.instance.client
            .from('mission_records')
            .select('record_date, status')
            .eq('user_id', user.id)
            .eq('status', 'completed')
            .gte('record_date', mondayString)
            .lte('record_date', sundayString),

        Supabase.instance.client
            .from('ai_conversation_activity_days')
            .select('activity_date')
            .eq('user_id', user.id)
            .gte('activity_date', mondayString)
            .lte('activity_date', sundayString),
      ]);

      final missionRecords = results[0];
      final conversationRecords = results[1];

      final completedMissionDates = <String>{};

      for (final record in missionRecords) {
        final date = record['record_date']?.toString();

        if (date != null && date.isNotEmpty) {
          completedMissionDates.add(date);
        }
      }

      final completedConversationDates = <String>{};

      for (final record in conversationRecords) {
        final date = record['activity_date']?.toString();

        if (date != null && date.isNotEmpty) {
          completedConversationDates.add(date);
        }
      }

      if (!mounted) return;

      setState(() {
        missionCompletedDates
          ..clear()
          ..addAll(completedMissionDates);

        conversationActiveDates
          ..clear()
          ..addAll(completedConversationDates);

        isLoadingWeeklyProgress = false;
      });
    } catch (error) {
      debugPrint('주간 활동 기록 불러오기 오류: $error');

      if (!mounted) return;

      setState(() {
        missionCompletedDates.clear();
        conversationActiveDates.clear();
        isLoadingWeeklyProgress = false;
      });
    }
  }

  // ============================================================
  // 화면 이동
  // ============================================================

  Future<void> _openMyPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyPageScreen()),
    );

    if (!mounted) return;

    // 마이페이지에서 관심영역을 수정했을 수 있음
    await Future.wait([_loadProfile(), _loadMissionRecommendation()]);
  }

  // ============================================================
  // 일상 미션 추천 화면 이동
  // ============================================================

  Future<void> _openMission() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MissionRecommendationScreen()),
    );

    if (!mounted) return;

    // 미션 완료 / 피드백 입력 후 다시 계산
    await Future.wait([_loadWeeklyProgress(), _loadMissionRecommendation()]);
  }

  // ============================================================
  // AI 대화 주제 선택 화면
  // ============================================================

  Future<void> _openConversationTraining() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationTrainingScreen()),
    );

    if (!mounted) return;

    await _loadWeeklyProgress();
  }

  // ============================================================
  // 준비 중 기능
  // ============================================================

  void _showPreparingMessage(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName 기능을 준비하고 있어요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // 메인 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      bottomNavigationBar: _buildBottomNavigation(),

      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: _refreshHome,

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _buildHeader(),
                const SizedBox(height: 28),

                _buildRecommendedActivity(),
                const SizedBox(height: 18),

                _buildDailyMission(),
                const SizedBox(height: 18),

                _buildWeeklyProgress(),
                const SizedBox(height: 18),

                _buildQuickActions(),
                const SizedBox(height: 18),

                _buildTodayMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 홈 상단
  // ============================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            InkWell(
              onTap: _openMyPage,
              borderRadius: BorderRadius.circular(50),

              child: Container(
                width: 56,
                height: 56,

                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,

                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.12),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: _buildProfileAvatar(),
              ),
            ),

            InkWell(
              onTap: () {
                _showPreparingMessage('알림');
              },

              borderRadius: BorderRadius.circular(50),

              child: Container(
                width: 56,
                height: 56,

                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 28,
                        color: Colors.black87,
                      ),
                    ),

                    Positioned(
                      top: 10,
                      right: 10,

                      child: Container(
                        width: 8,
                        height: 8,

                        decoration: const BoxDecoration(
                          color: Color(0xFF12C88A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        if (isLoadingProfile)
          Container(
            width: 230,
            height: 34,

            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),

            child: Text(
              '안녕하세요, $nickname님!',

              textAlign: TextAlign.center,
              maxLines: 2,

              style: const TextStyle(
                fontSize: 27,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF151918),
              ),
            ),
          ),

        const SizedBox(height: 8),

        Text(
          '오늘도 나의 속도로 시작해볼까요?',

          textAlign: TextAlign.center,

          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 프로필 아바타
  // ============================================================

  Widget _buildProfileAvatar() {
    if (isLoadingProfile) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,

          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
        ),
      );
    }

    final hasImage =
        avatarType == 'image' &&
        profileImageUrl != null &&
        profileImageUrl!.trim().isNotEmpty;

    if (hasImage) {
      return ClipOval(
        child: Image.network(
          profileImageUrl!,

          width: 56,
          height: 56,
          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {
            return _buildEmojiAvatar();
          },
        ),
      );
    }

    return _buildEmojiAvatar();
  }

  Widget _buildEmojiAvatar() {
    return Center(
      child: Text(avatarEmoji, style: const TextStyle(fontSize: 28)),
    );
  }

  // ============================================================
  // AI 자유 대화 메인 카드
  // 기존 디자인 유지
  // ============================================================

  Widget _buildRecommendedActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),

        border: Border.all(color: primaryColor.withValues(alpha: 0.12)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
            ),

            child: const Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(Icons.forum_outlined, color: primaryColor, size: 17),
                SizedBox(width: 7),

                Text(
                  'AI와 대화하기',

                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            '오늘은 어떤 이야기를\n나누고 싶나요?',

            style: TextStyle(
              fontSize: 23,
              height: 1.35,
              fontWeight: FontWeight.w900,
              color: Color(0xFF151918),
            ),
          ),

          const SizedBox(height: 11),

          Text(
            '일상 속 작은 이야기부터 미래에 대한 고민까지,\n'
            '자신의 속도로 편하게 이야기해 보세요.',

            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 19),

          const Wrap(
            spacing: 8,
            runSpacing: 8,

            children: [
              Chip(
                avatar: Icon(
                  Icons.wb_sunny_outlined,
                  size: 17,
                  color: primaryColor,
                ),
                label: Text('일상'),
              ),

              Chip(
                avatar: Icon(
                  Icons.auto_stories_outlined,
                  size: 17,
                  color: primaryColor,
                ),
                label: Text('진로'),
              ),

              Chip(
                avatar: Icon(
                  Icons.palette_outlined,
                  size: 17,
                  color: primaryColor,
                ),
                label: Text('취미'),
              ),
            ],
          ),

          const SizedBox(height: 23),

          SizedBox(
            width: double.infinity,
            height: 54,

            child: ElevatedButton.icon(
              onPressed: _openConversationTraining,

              icon: const Icon(Icons.chat_bubble_outline_rounded),

              label: const Text(
                '대화 주제 선택하기',

                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 오늘의 일상 미션
  //
  // 고정 미션 대신 실제 추천 결과 표시
  // ============================================================

  Widget _buildDailyMission() {
    final list = missionRecommendation?.recommended;

    final mission = list != null && list.isNotEmpty ? list.first : null;

    final currentLevel = missionRecommendation?.currentLevel;

    final missionTitle = isLoadingMissionRecommendation
        ? '오늘의 미션을 찾고 있어요...'
        : missionRecommendationError != null
        ? '맞춤 미션을 불러오지 못했어요'
        : mission?.title ?? '나에게 맞는 미션 둘러보기';

    final missionDescription = missionRecommendationError != null
        ? '카드를 눌러 다시 확인해 주세요.'
        : mission == null
        ? '내 마음에 드는 활동을 직접 골라보세요.'
        : '${mission.categoryName} · '
              '${mission.difficulty}단계 · '
              '적합도 ${mission.score}점';

    return InkWell(
      onTap: _openMission,
      borderRadius: BorderRadius.circular(24),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF4),
          borderRadius: BorderRadius.circular(24),

          border: Border.all(color: const Color(0xFFFFE7C5)),
        ),

        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,

              decoration: BoxDecoration(
                color: const Color(0xFFFFF0D9),
                borderRadius: BorderRadius.circular(18),
              ),

              child: const Icon(
                Icons.directions_walk_rounded,
                size: 30,
                color: missionColor,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    '오늘의 일상 미션 · 맞춤 추천',

                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC86B17),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    missionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    missionDescription,
                    maxLines: 2,

                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  if (!isLoadingMissionRecommendation &&
                      currentLevel != null) ...[
                    const SizedBox(height: 7),

                    Text(
                      '현재 추천 기준: $currentLevel단계',

                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC86B17),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 이번 주 나의 걸음
  // ============================================================

  Widget _buildWeeklyProgress() {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    final monday = _getMonday(_koreaNow());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: const Color(0xFFE7ECEA)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            '이번 주 나의 걸음',

            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            isLoadingWeeklyProgress
                ? '이번 주 활동을 불러오고 있어요.'
                : '일상 미션과 AI 대화 참여를 기록했어요.',

            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));

              final dateKey = _dateString(date);

              final hasMission = missionCompletedDates.contains(dateKey);

              final hasConversation = conversationActiveDates.contains(dateKey);

              return Column(
                children: [
                  Text(
                    weekdayLabels[index],

                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 9),

                  _buildActivityDayCircle(
                    hasMission: hasMission,
                    hasConversation: hasConversation,
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 20),

          const Wrap(
            spacing: 16,
            runSpacing: 8,

            children: [
              _ActivityLegend(
                color: missionColor,
                icon: Icons.directions_walk_rounded,
                label: '일상 미션',
              ),

              _ActivityLegend(
                color: primaryColor,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'AI와 대화한 날',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 주간 활동 날짜 표시
  // ============================================================

  Widget _buildActivityDayCircle({
    required bool hasMission,
    required bool hasConversation,
  }) {
    if (isLoadingWeeklyProgress) {
      return Container(
        width: 35,
        height: 35,

        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF3F5F4),

          border: Border.all(color: const Color(0xFFE0E4E2), width: 2),
        ),
      );
    }

    // 일상 미션 + AI 대화
    if (hasConversation && hasMission) {
      return Stack(
        clipBehavior: Clip.none,

        children: [
          Container(
            width: 35,
            height: 35,

            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
            ),

            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),

          Positioned(
            right: -2,
            bottom: -2,

            child: Container(
              width: 13,
              height: 13,

              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: missionColor,
              ),

              child: const Icon(
                Icons.check_rounded,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // AI 대화만 참여
    if (hasConversation) {
      return Container(
        width: 35,
        height: 35,

        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: primaryColor,
        ),

        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 18,
          color: Colors.white,
        ),
      );
    }

    // 일상 미션만 수행
    if (hasMission) {
      return Container(
        width: 35,
        height: 35,

        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: missionColor,
        ),

        child: const Icon(
          Icons.directions_walk_rounded,
          size: 19,
          color: Colors.white,
        ),
      );
    }

    // 기록 없는 날
    return Container(
      width: 35,
      height: 35,

      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,

        border: Border.all(color: const Color(0xFFD8DEDC), width: 2),
      ),
    );
  }

  // ============================================================
  // 바로 시작하기
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          '바로 시작하기',

          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                icon: Icons.chat_bubble_outline_rounded,

                label: 'AI 대화',

                backgroundColor: const Color(0xFFEAFBF5),

                iconColor: primaryColor,

                onTap: _openConversationTraining,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _quickActionCard(
                icon: Icons.directions_walk_rounded,

                label: '일상 미션',

                backgroundColor: const Color(0xFFFFF6E8),

                iconColor: missionColor,

                onTap: _openMission,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _quickActionCard(
                icon: Icons.sentiment_satisfied_alt_rounded,

                label: '감정 기록',

                backgroundColor: const Color(0xFFEDF7FF),

                iconColor: const Color(0xFF4285D4),

                onTap: () {
                  _showPreparingMessage('감정 기록');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),

      child: Container(
        height: 105,

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),

        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, size: 29, color: iconColor),

            const SizedBox(height: 10),

            Text(
              label,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 오늘의 한마디
  // ============================================================

  Widget _buildTodayMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: primaryColor.withValues(alpha: 0.10)),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),

            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 23)),
            ),
          ),

          const SizedBox(width: 15),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  '오늘의 한마디',

                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  '천천히 가도 괜찮아요.',

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 하단 메뉴
  // ============================================================

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 72,
      backgroundColor: Colors.white,

      indicatorColor: primaryColor.withValues(alpha: 0.12),

      selectedIndex: 0,

      onDestinationSelected: (index) async {
        if (index == 0) return;

        switch (index) {
          case 1:
            await _openConversationTraining();
            break;

          case 2:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordScreen()),
            );

            if (!mounted) return;

            // 기록 화면에서 주간 생활상태가 바뀌었을 수 있음
            await Future.wait([
              _loadWeeklyProgress(),
              _loadMissionRecommendation(),
            ]);
            break;

          case 3:
            await _openMyPage();
            break;
        }
      },

      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: primaryColor),
          label: '홈',
        ),

        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          label: '대화',
        ),

        NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '기록'),

        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          label: 'MY',
        ),
      ],
    );
  }
}

// ============================================================
// 주간 활동 범례
// ============================================================

class _ActivityLegend extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _ActivityLegend({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 22,
          height: 22,

          decoration: BoxDecoration(color: color, shape: BoxShape.circle),

          child: Icon(icon, size: 13, color: Colors.white),
        ),

        const SizedBox(width: 7),

        Text(
          label,

          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF686E6B),
          ),
        ),
      ],
    );
  }
}

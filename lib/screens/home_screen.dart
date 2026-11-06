import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/personalization_service.dart';

import 'conversation_training_screen.dart';
import 'mission_detail_screen.dart';
import 'my_page_screen.dart';
import 'record_screen.dart';
import 'voice_conversation_screen.dart';

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

  final Set<String> trainingCompletedDates = {};

  // ============================================================
  // 개인화 추천
  // ============================================================

  bool isLoadingRecommendation = true;

  PersonalizationResult? recommendation;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();

    _loadWeeklyProgress();

    _loadRecommendation();
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
  // 홈 새로고침
  // ============================================================

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadProfile(),
      _loadWeeklyProgress(),
      _loadRecommendation(),
    ]);
  }

  // ============================================================
  // 프로필 불러오기
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

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

      if (!mounted) {
        return;
      }

      // ========================================================
      // Private Storage 프로필 사진
      // ========================================================

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

      if (!mounted) {
        return;
      }

      setState(() {
        nickname = profile?['nickname']?.toString() ?? '사용자';

        avatarType = profile?['avatar_type']?.toString() ?? 'emoji';

        avatarEmoji = profile?['avatar_emoji']?.toString() ?? '🌱';

        profileImageUrl = loadedProfileImageUrl;

        isLoadingProfile = false;
      });
    } catch (error) {
      debugPrint('프로필 불러오기 오류: $error');

      if (!mounted) {
        return;
      }

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
  // 개인화 추천 불러오기
  // ============================================================

  Future<void> _loadRecommendation() async {
    if (mounted) {
      setState(() {
        isLoadingRecommendation = true;
      });
    }

    try {
      final loadedRecommendation =
          await PersonalizationService.loadRecommendationForCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        recommendation = loadedRecommendation;

        isLoadingRecommendation = false;
      });
    } catch (error) {
      debugPrint('개인화 추천 불러오기 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        recommendation = null;

        isLoadingRecommendation = false;
      });
    }
  }

  // ============================================================
  // 이번 주 활동 기록 불러오기
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
        if (!mounted) {
          return;
        }

        setState(() {
          missionCompletedDates.clear();

          trainingCompletedDates.clear();

          isLoadingWeeklyProgress = false;
        });

        return;
      }

      // ========================================================
      // 이번 주 범위
      // 월요일 00:00 ~ 다음 주 월요일 00:00
      // ========================================================

      final now = DateTime.now();

      final monday = _getMonday(now);

      final sunday = monday.add(const Duration(days: 6));

      final nextMonday = monday.add(const Duration(days: 7));

      // ========================================================
      // 일상 미션 + 대화훈련 조회
      // ========================================================

      final results = await Future.wait([
        // ------------------------------------------------------
        // 일상 미션
        // ------------------------------------------------------

        Supabase.instance.client
            .from('mission_records')
            .select('record_date, status')
            .eq('user_id', user.id)
            .eq('status', 'completed')
            .gte('record_date', _dateString(monday))
            .lte('record_date', _dateString(sunday)),

        // ------------------------------------------------------
        // 대화 리허설
        // ------------------------------------------------------
        Supabase.instance.client
            .from('conversation_training_records')
            .select('completed_at')
            .eq('user_id', user.id)
            .gte('completed_at', monday.toUtc().toIso8601String())
            .lt('completed_at', nextMonday.toUtc().toIso8601String()),
      ]);

      final missionRecords = results[0];

      final trainingRecords = results[1];

      // ========================================================
      // 일상 미션 완료 날짜
      // ========================================================

      final completedMissionDates = <String>{};

      for (final record in missionRecords) {
        final date = record['record_date']?.toString();

        if (date != null && date.isNotEmpty) {
          completedMissionDates.add(date);
        }
      }

      // ========================================================
      // 대화 리허설 완료 날짜
      // ========================================================

      final completedTrainingDates = <String>{};

      for (final record in trainingRecords) {
        final completedAt = record['completed_at']?.toString();

        if (completedAt == null || completedAt.isEmpty) {
          continue;
        }

        final parsedDate = DateTime.tryParse(completedAt);

        if (parsedDate == null) {
          continue;
        }

        final localDate = parsedDate.toLocal();

        completedTrainingDates.add(_dateString(localDate));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        missionCompletedDates
          ..clear()
          ..addAll(completedMissionDates);

        trainingCompletedDates
          ..clear()
          ..addAll(completedTrainingDates);

        isLoadingWeeklyProgress = false;
      });
    } catch (error) {
      debugPrint('주간 활동 기록 불러오기 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        missionCompletedDates.clear();

        trainingCompletedDates.clear();

        isLoadingWeeklyProgress = false;
      });
    }
  }

  // ============================================================
  // 마이페이지
  // ============================================================

  Future<void> _openMyPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyPageScreen()),
    );

    if (!mounted) {
      return;
    }

    // 관심 영역이 수정됐을 수 있으므로
    // 프로필 + 개인화 추천 모두 갱신
    await Future.wait([_loadProfile(), _loadRecommendation()]);
  }

  // ============================================================
  // 오늘의 일상 미션
  // ============================================================

  Future<void> _openMission() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MissionDetailScreen()),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _loadWeeklyProgress();
    }
  }

  // ============================================================
  // 전체 대화 연습 화면
  // ============================================================

  Future<void> _openConversationTraining() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationTrainingScreen()),
    );

    if (!mounted) {
      return;
    }

    await _loadWeeklyProgress();
  }

  // ============================================================
  // 개인화 추천 리허설 바로 시작
  // ============================================================

  Future<void> _openRecommendedActivity() async {
    final currentRecommendation = recommendation;

    // 추천 정보가 없으면
    // 전체 대화 연습 화면으로 이동
    if (currentRecommendation == null) {
      await _openConversationTraining();

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceConversationScreen(
          scenarioCode: currentRecommendation.scenarioCode,

          scenarioTitle: currentRecommendation.scenarioTitle,

          difficulty: currentRecommendation.difficulty,

          roleName: currentRecommendation.roleName,

          firstAiMessage: currentRecommendation.firstAiMessage,

          totalGoalSteps: currentRecommendation.totalGoalSteps,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

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
  // BUILD
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
  // 상단
  // ============================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            InkWell(
              onTap: () async {
                await _openMyPage();
              },

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
  // 프로필 이미지
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
  // 오늘의 개인화 추천
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

      child: isLoadingRecommendation
          ? _buildRecommendationLoading()
          : recommendation == null
          ? _buildRecommendationUnavailable()
          : _buildRecommendationContent(),
    );
  }

  // ============================================================
  // 추천 로딩
  // ============================================================

  Widget _buildRecommendationLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildRecommendationBadge('오늘의 추천 활동'),

        const SizedBox(height: 22),

        Row(
          children: [
            Container(
              width: 64,

              height: 64,

              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.07),

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,

                  color: primaryColor,
                ),
              ),
            ),

            const SizedBox(width: 16),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    '맞춤 활동을 찾고 있어요',

                    style: TextStyle(
                      fontSize: 18,

                      fontWeight: FontWeight.w900,

                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 7),

                  Text(
                    '초기 검사와 생활상태를 함께 살펴보고 있어요.',

                    style: TextStyle(
                      fontSize: 12.5,

                      height: 1.5,

                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // 추천 없음
  // ============================================================

  Widget _buildRecommendationUnavailable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildRecommendationBadge('오늘의 추천 활동'),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: 64,

              height: 64,

              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.09),

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Icon(
                Icons.chat_bubble_outline_rounded,

                size: 30,

                color: primaryColor,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    '추천 정보를 확인할 수 없어요',

                    maxLines: 2,

                    style: TextStyle(
                      fontSize: 19,

                      height: 1.3,

                      fontWeight: FontWeight.w900,

                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '전체 대화 연습에서 원하는 상황을 직접 선택할 수 있어요.',

                    style: TextStyle(
                      fontSize: 12.5,

                      height: 1.5,

                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,

          height: 54,

          child: ElevatedButton.icon(
            onPressed: _openConversationTraining,

            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,

              foregroundColor: Colors.white,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),

            icon: const Icon(Icons.arrow_forward_rounded),

            iconAlignment: IconAlignment.end,

            label: const Text(
              '대화 연습 둘러보기',

              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 실제 추천 내용
  // ============================================================

  Widget _buildRecommendationContent() {
    final current = recommendation!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            _buildRecommendationBadge('오늘의 추천 활동'),

            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),

              decoration: BoxDecoration(
                color: _difficultyColor(current.difficulty)
                    .withValues(alpha: 0.10),

                borderRadius: BorderRadius.circular(100),
              ),

              child: Text(
                current.difficulty,

                style: TextStyle(
                  fontSize: 12,

                  fontWeight: FontWeight.w900,

                  color: _difficultyColor(current.difficulty),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: 64,

              height: 64,

              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.09),

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Icon(
                Icons.forum_outlined,

                size: 30,

                color: primaryColor,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    current.recommendedArea,

                    style: const TextStyle(
                      fontSize: 12.5,

                      fontWeight: FontWeight.w800,

                      color: primaryColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    current.scenarioTitle,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 19,

                      height: 1.3,

                      fontWeight: FontWeight.w900,

                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(15),

          decoration: BoxDecoration(
            color: const Color(0xFFF5FAF8),

            borderRadius: BorderRadius.circular(16),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.auto_awesome_outlined,

                size: 19,

                color: primaryColor,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  current.reason,

                  style: TextStyle(
                    fontSize: 12.5,

                    height: 1.55,

                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,

          height: 54,

          child: ElevatedButton.icon(
            onPressed: _openRecommendedActivity,

            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,

              foregroundColor: Colors.white,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),

            icon: const Icon(Icons.arrow_forward_rounded),

            iconAlignment: IconAlignment.end,

            label: const Text(
              '추천 리허설 시작하기',

              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.11),

        borderRadius: BorderRadius.circular(30),
      ),

      child: Text(
        text,

        style: const TextStyle(
          color: primaryColor,

          fontWeight: FontWeight.w800,

          fontSize: 14,
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case '초급':
        return primaryColor;

      case '중급':
        return const Color(0xFFE58A26);

      case '고급':
        return const Color(0xFF526CD9);

      default:
        return primaryColor;
    }
  }

  // ============================================================
  // 일상 미션
  // ============================================================

  Widget _buildDailyMission() {
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
                    '오늘의 일상 미션',

                    style: TextStyle(
                      fontSize: 13,

                      fontWeight: FontWeight.w800,

                      color: Color(0xFFC86B17),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    '집 밖으로 5분 나가보기',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 17,

                      fontWeight: FontWeight.w900,

                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '멀리 가지 않아도 괜찮아요. 가볍게 시작해봐요.',

                    maxLines: 2,

                    style: TextStyle(
                      fontSize: 13,

                      height: 1.45,

                      color: Colors.grey.shade600,
                    ),
                  ),
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

    final monday = _getMonday(DateTime.now());

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
                : '이번 주 활동을 한눈에 확인해보세요.',

            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));

              final dateKey = _dateString(date);

              final hasMission = missionCompletedDates.contains(dateKey);

              final hasTraining = trainingCompletedDates.contains(dateKey);

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

                    hasTraining: hasTraining,
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

                label: '대화 훈련',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDayCircle({
    required bool hasMission,
    required bool hasTraining,
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

    // ========================================================
    // 대화 훈련 + 일상 미션 둘 다
    // ========================================================

    if (hasTraining && hasMission) {
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

    // ========================================================
    // 대화 훈련만
    // ========================================================

    if (hasTraining) {
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

    // ========================================================
    // 일상 미션만
    // ========================================================

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

    // ========================================================
    // 활동 없음
    // ========================================================

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

                label: '대화 연습',

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
        if (index == 0) {
          return;
        }

        switch (index) {
          case 1:
            await _openConversationTraining();

            break;

          case 2:
            await Navigator.push(
              context,

              MaterialPageRoute(builder: (_) => const RecordScreen()),
            );

            if (!mounted) {
              return;
            }

            await _loadWeeklyProgress();

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
          icon: Icon(Icons.menu_book_outlined),

          label: '연습',
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
// 활동 범례
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

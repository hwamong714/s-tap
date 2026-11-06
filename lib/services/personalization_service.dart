import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// S-TAP 초기 개인화 결과
// ============================================================

class PersonalizationResult {
  final String recommendedArea;

  final String difficulty;

  final String scenarioCode;

  final String scenarioTitle;

  final String roleName;

  final String firstAiMessage;

  final int totalGoalSteps;

  final String reason;

  const PersonalizationResult({
    required this.recommendedArea,
    required this.difficulty,
    required this.scenarioCode,
    required this.scenarioTitle,
    required this.roleName,
    required this.firstAiMessage,
    required this.totalGoalSteps,
    required this.reason,
  });
}

// ============================================================
// S-TAP 초기 개인화 서비스
//
// 사용 데이터
//
// 1. HQ-25 초기검사 total_score
//
// 2. 초기 생활상태
// - outing_days_7d
// - avg_outing_minutes_7d
// - interaction_days_7d
// - outing_burden
// - duration_months
//
// 3. profiles_v2.interests
//
// 주의
//
// 이 로직은 진단 또는 임상적 판정이 아니다.
// S-TAP에서 사용자가 시작할 사회적 상황 리허설의
// 초기 난이도와 상황을 추천하기 위한 규칙 기반 로직이다.
// ============================================================

class PersonalizationService {
  PersonalizationService._();

  // ==========================================================
  // 현재 로그인한 사용자의 데이터를 불러와
  // 개인화 추천 생성
  // ==========================================================

  static Future<PersonalizationResult?>
  loadRecommendationForCurrentUser() async {
    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      // ======================================================
      // 필요한 데이터 동시 조회
      // ======================================================

      final results = await Future.wait([
        // ----------------------------------------------------
        // 1. HQ-25 초기검사
        // ----------------------------------------------------

        supabase
            .from('hq25_assessments')
            .select('total_score')
            .eq('user_id', user.id)
            .eq('assessment_type', 'initial')
            .limit(1)
            .maybeSingle(),

        // ----------------------------------------------------
        // 2. 초기 생활상태
        //
        // 주간 checkin이 아니라 반드시 initial 사용
        // ----------------------------------------------------
        supabase
            .from('life_status_assessments')
            .select(
              'outing_days_7d, '
              'avg_outing_minutes_7d, '
              'interaction_days_7d, '
              'outing_burden, '
              'duration_months',
            )
            .eq('user_id', user.id)
            .eq('assessment_type', 'initial')
            .limit(1)
            .maybeSingle(),

        // ----------------------------------------------------
        // 3. 관심 변화 영역
        // ----------------------------------------------------
        supabase
            .from('profiles_v2')
            .select('interests')
            .eq('id', user.id)
            .maybeSingle(),
      ]);

      final hq25 = results[0];

      final lifeStatus = results[1];

      final profile = results[2];

      // ======================================================
      // 초기검사 데이터가 하나라도 없으면
      // 아직 추천하지 않음
      // ======================================================

      if (hq25 == null || lifeStatus == null) {
        return null;
      }

      // ======================================================
      // HQ-25
      // ======================================================

      final hq25Score = _toInt(hq25['total_score']);

      // ======================================================
      // 생활상태
      // ======================================================

      final outingDays7 = _toInt(lifeStatus['outing_days_7d']);

      final averageOutingMinutes = _toInt(lifeStatus['avg_outing_minutes_7d']);

      final interactionDays7 = _toInt(lifeStatus['interaction_days_7d']);

      final outingBurden = _toInt(lifeStatus['outing_burden']);

      final durationMonths = _toInt(lifeStatus['duration_months']);

      // ======================================================
      // 관심영역
      // ======================================================

      final interests = _parseInterests(profile?['interests']);

      // ======================================================
      // 추천 생성
      // ======================================================

      return recommend(
        hq25Score: hq25Score,

        outingDays7: outingDays7,

        averageOutingMinutes: averageOutingMinutes,

        interactionDays7: interactionDays7,

        outingBurden: outingBurden,

        durationMonths: durationMonths,

        interests: interests,
      );
    } catch (error) {
      debugPrint('초기 개인화 데이터 불러오기 오류: $error');

      return null;
    }
  }

  // ==========================================================
  // 개인화 추천
  // ==========================================================

  static PersonalizationResult recommend({
    required int hq25Score,
    required int outingDays7,
    required int averageOutingMinutes,
    required int interactionDays7,
    required int outingBurden,
    required int durationMonths,
    required List<String> interests,
  }) {
    // ========================================================
    // 안전 범위 처리
    // ========================================================

    final safeHq25 = hq25Score.clamp(0, 100);

    final safeOutingDays = outingDays7.clamp(0, 7);

    final safeOutingMinutes = averageOutingMinutes < 0
        ? 0
        : averageOutingMinutes;

    final safeInteractionDays = interactionDays7.clamp(0, 7);

    final safeOutingBurden = outingBurden.clamp(0, 10);

    final safeDurationMonths = durationMonths < 0 ? 0 : durationMonths;

    // ========================================================
    // 내부 부담도 계산
    //
    // 공식 HQ-25 절단점이 아님.
    // S-TAP의 시작 난이도를 정하기 위한 내부 휴리스틱.
    // ========================================================

    int burdenScore = 0;

    // --------------------------------------------------------
    // HQ-25
    // --------------------------------------------------------

    if (safeHq25 >= 75) {
      burdenScore += 3;
    } else if (safeHq25 >= 50) {
      burdenScore += 2;
    } else if (safeHq25 >= 25) {
      burdenScore += 1;
    }

    // --------------------------------------------------------
    // 최근 7일 외출 일수
    // --------------------------------------------------------

    if (safeOutingDays == 0) {
      burdenScore += 3;
    } else if (safeOutingDays <= 2) {
      burdenScore += 2;
    } else if (safeOutingDays <= 4) {
      burdenScore += 1;
    }

    // --------------------------------------------------------
    // 외출한 날 평균 외출시간
    // --------------------------------------------------------

    if (safeOutingDays > 0) {
      if (safeOutingMinutes < 30) {
        burdenScore += 2;
      } else if (safeOutingMinutes < 120) {
        burdenScore += 1;
      }
    }

    // --------------------------------------------------------
    // 최근 7일 대면 교류
    // --------------------------------------------------------

    if (safeInteractionDays == 0) {
      burdenScore += 3;
    } else if (safeInteractionDays == 1) {
      burdenScore += 2;
    } else if (safeInteractionDays <= 3) {
      burdenScore += 1;
    }

    // --------------------------------------------------------
    // 외출 부담
    // --------------------------------------------------------

    if (safeOutingBurden >= 8) {
      burdenScore += 3;
    } else if (safeOutingBurden >= 5) {
      burdenScore += 2;
    } else if (safeOutingBurden >= 3) {
      burdenScore += 1;
    }

    // --------------------------------------------------------
    // 현재 생활상태 지속기간
    //
    // initial에서만 가져옴
    // --------------------------------------------------------

    if (safeDurationMonths >= 24) {
      burdenScore += 2;
    } else if (safeDurationMonths >= 6) {
      burdenScore += 1;
    }

    // ========================================================
    // 시작 난이도 결정
    //
    // 부담도가 높을수록
    // 사회적 요구가 낮은 단계부터 시작
    // ========================================================

    final String difficulty;

    if (burdenScore >= 10) {
      difficulty = '초급';
    } else if (burdenScore >= 5) {
      difficulty = '중급';
    } else {
      difficulty = '고급';
    }

    // ========================================================
    // 관심영역 정리
    // ========================================================

    final normalizedInterests = interests
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    // ========================================================
    // 사람들과 편하게 대화하기
    // ========================================================

    if (_containsInterest(normalizedInterests, '사람들과 편하게 대화')) {
      return _conversationRecommendation(
        difficulty: difficulty,

        recommendedArea: '사회적 대화',

        reasonArea: '사람들과 편하게 대화하는 것',
      );
    }

    // ========================================================
    // 감정을 표현해보기
    // ========================================================

    if (_containsInterest(normalizedInterests, '감정을 표현')) {
      return _expressionRecommendation(difficulty: difficulty);
    }

    // ========================================================
    // 새로운 관계 만들어보기
    // ========================================================

    if (_containsInterest(normalizedInterests, '새로운 관계')) {
      return _relationshipRecommendation(difficulty: difficulty);
    }

    // ========================================================
    // 방 밖으로 나가는 횟수 늘리기
    // ========================================================

    if (_containsInterest(normalizedInterests, '방 밖으로 나가는 횟수')) {
      return _outingRecommendation(difficulty: difficulty);
    }

    // ========================================================
    // 규칙적인 생활 만들기
    //
    // 장기적으로는 일상 미션 추천과 연결
    // 현재는 외부 활동 리허설을 시작점으로 사용
    // ========================================================

    if (_containsInterest(normalizedInterests, '규칙적인 생활')) {
      return _dailyLifeRecommendation(difficulty: difficulty);
    }

    // ========================================================
    // 기타 / 선택 영역 없음
    //
    // 실제 초기 생활상태를 이용해 추천
    // ========================================================

    if (safeInteractionDays <= 1) {
      return _conversationRecommendation(
        difficulty: difficulty,

        recommendedArea: '사회적 대화',

        reasonArea: '사회적 상호작용',
      );
    }

    if (safeOutingDays <= 2 || safeOutingBurden >= 6) {
      return _outingRecommendation(difficulty: difficulty);
    }

    return _conversationRecommendation(
      difficulty: difficulty,

      recommendedArea: '사회적 상황 경험',

      reasonArea: '사회적 상황 경험',
    );
  }

  // ==========================================================
  // 사회적 대화
  // ==========================================================

  static PersonalizationResult _conversationRecommendation({
    required String difficulty,
    required String recommendedArea,
    required String reasonArea,
  }) {
    if (difficulty == '초급') {
      return PersonalizationResult(
        recommendedArea: recommendedArea,

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '상대방의 안부에 답하기',

        roleName: '지인',

        firstAiMessage: '오랜만이야. 요즘 어떻게 지냈어?',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: reasonArea),
      );
    }

    if (difficulty == '중급') {
      return PersonalizationResult(
        recommendedArea: recommendedArea,

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '지인과 대화를 이어가기',

        roleName: '지인',

        firstAiMessage: '오랜만이네. 요즘 뭐 하면서 지내?',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: reasonArea),
      );
    }

    return PersonalizationResult(
      recommendedArea: recommendedArea,

      difficulty: difficulty,

      scenarioCode: 'acquaintance_talk',

      scenarioTitle: '먼저 안부를 묻고 대화 시작하기',

      roleName: '지인',

      firstAiMessage: '어, 오랜만이다!',

      totalGoalSteps: 3,

      reason: _buildReason(difficulty: difficulty, area: reasonArea),
    );
  }

  // ==========================================================
  // 감정 표현
  // ==========================================================

  static PersonalizationResult _expressionRecommendation({
    required String difficulty,
  }) {
    if (difficulty == '초급') {
      return PersonalizationResult(
        recommendedArea: '자기표현',

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '내 상태를 짧게 표현하기',

        roleName: '지인',

        firstAiMessage: '요즘은 좀 어때?',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '내 생각과 감정을 표현하는 것'),
      );
    }

    if (difficulty == '중급') {
      return PersonalizationResult(
        recommendedArea: '자기표현',

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '내 생각과 기분을 이야기하기',

        roleName: '지인',

        firstAiMessage: '요즘 무슨 생각을 가장 많이 해?',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '내 생각과 감정을 표현하는 것'),
      );
    }

    return PersonalizationResult(
      recommendedArea: '자기표현',

      difficulty: difficulty,

      scenarioCode: 'acquaintance_talk',

      scenarioTitle: '먼저 내 생각을 이야기하기',

      roleName: '지인',

      firstAiMessage: '응, 듣고 있어.',

      totalGoalSteps: 3,

      reason: _buildReason(difficulty: difficulty, area: '내 생각과 감정을 표현하는 것'),
    );
  }

  // ==========================================================
  // 새로운 관계
  // ==========================================================

  static PersonalizationResult _relationshipRecommendation({
    required String difficulty,
  }) {
    if (difficulty == '초급') {
      return PersonalizationResult(
        recommendedArea: '관계 형성',

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '상대방의 인사에 답하기',

        roleName: '처음 만난 사람',

        firstAiMessage: '안녕하세요. 처음 뵙네요.',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '새로운 관계를 만들어보는 것'),
      );
    }

    if (difficulty == '중급') {
      return PersonalizationResult(
        recommendedArea: '관계 형성',

        difficulty: difficulty,

        scenarioCode: 'acquaintance_talk',

        scenarioTitle: '처음 만난 사람과 대화 이어가기',

        roleName: '처음 만난 사람',

        firstAiMessage: '안녕하세요. 오늘 처음 오셨어요?',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '새로운 관계를 만들어보는 것'),
      );
    }

    return PersonalizationResult(
      recommendedArea: '관계 형성',

      difficulty: difficulty,

      scenarioCode: 'acquaintance_talk',

      scenarioTitle: '먼저 대화를 시작해보기',

      roleName: '처음 만난 사람',

      firstAiMessage: '안녕하세요.',

      totalGoalSteps: 3,

      reason: _buildReason(difficulty: difficulty, area: '새로운 관계를 만들어보는 것'),
    );
  }

  // ==========================================================
  // 외부 활동
  // ==========================================================

  static PersonalizationResult _outingRecommendation({
    required String difficulty,
  }) {
    if (difficulty == '초급') {
      return PersonalizationResult(
        recommendedArea: '외부 활동',

        difficulty: difficulty,

        scenarioCode: 'convenience_store',

        scenarioTitle: '직원의 말에 짧게 응답하기',

        roleName: '편의점 직원',

        firstAiMessage: '안녕하세요. 필요한 것 있으시면 말씀해주세요.',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '밖에서 활동하는 것'),
      );
    }

    if (difficulty == '중급') {
      return PersonalizationResult(
        recommendedArea: '외부 활동',

        difficulty: difficulty,

        scenarioCode: 'convenience_store',

        scenarioTitle: '필요한 것을 직원에게 문의하기',

        roleName: '편의점 직원',

        firstAiMessage: '어서오세요.',

        totalGoalSteps: 3,

        reason: _buildReason(difficulty: difficulty, area: '밖에서 활동하는 것'),
      );
    }

    return PersonalizationResult(
      recommendedArea: '외부 활동',

      difficulty: difficulty,

      scenarioCode: 'convenience_store',

      scenarioTitle: '먼저 도움을 요청해보기',

      roleName: '편의점 직원',

      firstAiMessage: '어서오세요.',

      totalGoalSteps: 3,

      reason: _buildReason(difficulty: difficulty, area: '밖에서 활동하는 것'),
    );
  }

  // ==========================================================
  // 생활 활동
  // ==========================================================

  static PersonalizationResult _dailyLifeRecommendation({
    required String difficulty,
  }) {
    return PersonalizationResult(
      recommendedArea: '생활 활동',

      difficulty: difficulty,

      scenarioCode: 'convenience_store',

      scenarioTitle: difficulty == '초급'
          ? '짧은 외출 상황 경험하기'
          : difficulty == '중급'
          ? '외출 중 필요한 것을 문의하기'
          : '외부 활동에서 먼저 상호작용하기',

      roleName: '편의점 직원',

      firstAiMessage: difficulty == '초급' ? '안녕하세요. 천천히 둘러보세요.' : '어서오세요.',

      totalGoalSteps: 3,

      reason: _buildReason(difficulty: difficulty, area: '규칙적인 생활과 외부 활동'),
    );
  }

  // ==========================================================
  // 추천 이유
  // ==========================================================

  static String _buildReason({
    required String difficulty,
    required String area,
  }) {
    if (difficulty == '초급') {
      return '초기 검사와 생활상태를 함께 고려해 '
          '$area에서 부담이 비교적 적은 상황부터 '
          '경험할 수 있도록 추천했어요.';
    }

    if (difficulty == '중급') {
      return '초기 검사와 생활상태를 함께 고려해 '
          '$area에서 짧은 상호작용을 이어가는 수준부터 '
          '시작하도록 추천했어요.';
    }

    return '초기 검사와 생활상태를 함께 고려해 '
        '$area에서 직접 상호작용을 시작해보는 수준을 '
        '추천했어요.';
  }

  // ==========================================================
  // 관심영역 포함 여부
  // ==========================================================

  static bool _containsInterest(List<String> interests, String keyword) {
    for (final interest in interests) {
      if (interest.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================
  // DB 숫자 안전 변환
  // ==========================================================

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ==========================================================
  // Supabase interests 안전 변환
  // ==========================================================

  static List<String> _parseInterests(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    return [];
  }
}

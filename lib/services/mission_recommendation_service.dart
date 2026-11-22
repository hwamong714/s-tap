import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// S-TAP 일상 미션 추천 v2.1
//
// 초기 생활상태 + 주간 체크인 + 미션 피드백
//
// 적합도 = 관심사(30) + 실행 가능성(30)
//        + 난이도(25) + 과거 피드백(15)
//
// 실행 가능성 평가:
// category가 아닌 실제 활동 조건 사용
// place_level / interaction_level / time_level
//
// 서비스 자체 휴리스틱. 임상 점수 아님.
// ============================================================

class RecommendedMission {
  final String id;
  final String code;
  final String title;
  final String description;
  final String category;

  final int difficulty;
  final int estimatedMinutes;

  final int interestScore;
  final int feasibilityScore;
  final int difficultyScore;
  final int historyScore;

  const RecommendedMission({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.interestScore,
    required this.feasibilityScore,
    required this.difficultyScore,
    required this.historyScore,
  });

  int get score =>
      interestScore + feasibilityScore + difficultyScore + historyScore;

  String get categoryName {
    switch (category) {
      case 'outing':
        return '외출';
      case 'social':
        return '사회적 교류';
      case 'routine':
        return '생활 루틴';
      case 'emotion':
        return '감정';
      case 'self_care':
        return '자기관리';
      case 'community':
        return '사회참여';
      default:
        return '일상';
    }
  }
}

class MissionRecommendationResult {
  final bool hasInitialAssessment;

  final int? burdenScore;
  final int initialLevel;
  final int currentLevel;

  final int? weeklyBurdenScore;
  final DateTime? latestCheckinAt;

  final List<RecommendedMission> recommended;
  final List<RecommendedMission> allMissions;

  final RecommendedMission? optionalChallenge;

  const MissionRecommendationResult({
    required this.hasInitialAssessment,
    required this.burdenScore,
    required this.initialLevel,
    required this.currentLevel,
    required this.weeklyBurdenScore,
    required this.latestCheckinAt,
    required this.recommended,
    required this.allMissions,
    required this.optionalChallenge,
  });
}

class MissionRecommendationService {
  MissionRecommendationService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static String get _userId {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user.id;
  }

  // ============================================================
  // 공통 유틸리티
  // ============================================================

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime _koreaNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 9));
  }

  static String _dateString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _today() {
    return _dateString(_koreaNow());
  }

  static String _weekKey(DateTime instant) {
    final kst = instant.toUtc().add(const Duration(hours: 9));

    final monday = DateTime.utc(
      kst.year,
      kst.month,
      kst.day,
    ).subtract(Duration(days: kst.weekday - 1));

    return _dateString(monday);
  }

  // ============================================================
  // 1. 최초 생활상태 부담지표 0~13점
  // ============================================================

  static int? calculateBurden(Map<String, dynamic>? life) {
    if (life == null) return null;

    final outing = _asInt(life['outing_days_7d']);
    final minutes = _asInt(life['avg_outing_minutes_7d']);
    final contact = _asInt(life['interaction_days_7d']);
    final burden = _asInt(life['outing_burden']);
    final months = _asInt(life['duration_months']);

    if (outing == null ||
        contact == null ||
        burden == null ||
        months == null ||
        (outing > 0 && minutes == null)) {
      return null;
    }

    if (outing < 0 ||
        outing > 7 ||
        contact < 0 ||
        contact > 7 ||
        burden < 0 ||
        burden > 10 ||
        months < 0 ||
        (minutes != null && minutes < 0)) {
      return null;
    }

    int score = 0;

    score += outing == 0
        ? 3
        : outing <= 2
        ? 2
        : outing <= 4
        ? 1
        : 0;

    if (outing > 0) {
      score += minutes! < 30
          ? 2
          : minutes < 120
          ? 1
          : 0;
    }

    score += contact == 0
        ? 3
        : contact == 1
        ? 2
        : contact <= 3
        ? 1
        : 0;

    score += burden >= 8
        ? 3
        : burden >= 5
        ? 2
        : burden >= 3
        ? 1
        : 0;

    score += months >= 24
        ? 2
        : months >= 6
        ? 1
        : 0;

    return score;
  }

  static int levelForBurden(int? score) {
    if (score == null || score >= 8) return 1;
    if (score >= 4) return 2;
    return 3;
  }

  // ============================================================
  // 2. 주간 생활상태 부담지표 0~9점
  // ============================================================

  static int? calculateWeeklyBurden(Map<String, dynamic> row) {
    final outing = _asInt(row['outing_days_7d']);
    final contact = _asInt(row['interaction_days_7d']);
    final burden = _asInt(row['outing_burden']);

    if (outing == null ||
        contact == null ||
        burden == null ||
        outing < 0 ||
        outing > 7 ||
        contact < 0 ||
        contact > 7 ||
        burden < 0 ||
        burden > 10) {
      return null;
    }

    final o = outing == 0
        ? 3
        : outing <= 2
        ? 2
        : outing <= 4
        ? 1
        : 0;

    final c = contact == 0
        ? 3
        : contact == 1
        ? 2
        : contact <= 3
        ? 1
        : 0;

    final b = burden >= 8
        ? 3
        : burden >= 5
        ? 2
        : burden >= 3
        ? 1
        : 0;

    return o + c + b;
  }

  static int _weeklyTarget(int score) {
    if (score >= 6) return 1;
    if (score >= 3) return 2;
    return 3;
  }

  // ============================================================
  // 3. 주간 체크인에 따라 기본 난이도 조정
  //
  // 같은 주의 가장 최근 기록 하나만 반영
  // 주당 최대 1단계 변화
  // ============================================================

  static ({int level, int? score, DateTime? at, Map<String, dynamic>? life})
  _applyCheckins(
    int initialLevel,
    DateTime? initialAt,
    List<Map<String, dynamic>> checkins,
  ) {
    final byWeek = <String, Map<String, dynamic>>{};

    final sorted = [...checkins]
      ..sort((a, b) {
        return (a['completed_at'] ?? '').toString().compareTo(
          (b['completed_at'] ?? '').toString(),
        );
      });

    for (final row in sorted) {
      final at = DateTime.tryParse(row['completed_at']?.toString() ?? '');

      if (at == null || at.isAfter(DateTime.now())) {
        continue;
      }

      if (initialAt != null && !at.isAfter(initialAt)) {
        continue;
      }

      if (calculateWeeklyBurden(row) == null) {
        continue;
      }

      byWeek[_weekKey(at)] = row;
    }

    int level = initialLevel;
    int? latestScore;
    DateTime? latestAt;
    Map<String, dynamic>? latestLife;

    final weeks = byWeek.keys.toList()..sort();

    for (final week in weeks) {
      final row = byWeek[week]!;

      final score = calculateWeeklyBurden(row)!;

      final target = _weeklyTarget(score);

      if (target > level) {
        level++;
      } else if (target < level) {
        level--;
      }

      latestScore = score;
      latestAt = DateTime.tryParse(row['completed_at'].toString());
      latestLife = row;
    }

    return (level: level, score: latestScore, at: latestAt, life: latestLife);
  }

  // ============================================================
  // 4. 관심영역 적합도 (0~30점)
  // ============================================================

  static int _interestScore(String category, List<String> interests) {
    if (interests.isEmpty || interests.every((x) => x == '기타')) {
      return 15;
    }

    int best = 0;

    for (final interest in interests) {
      if (interest.contains('편하게 대화') || interest.contains('새로운 관계')) {
        if (category == 'social') {
          best = 30;
        } else if (category == 'community') {
          if (best < 15) best = 15;
        }
      }

      if (interest.contains('규칙적인 생활')) {
        if (category == 'routine') {
          best = 30;
        } else if (category == 'self_care') {
          if (best < 15) best = 15;
        }
      }

      if (interest.contains('방 밖으로')) {
        if (category == 'outing') {
          best = 30;
        } else if (category == 'community') {
          if (best < 15) best = 15;
        }
      }

      if (interest.contains('감정을 표현')) {
        if (category == 'emotion') {
          best = 30;
        } else if (category == 'self_care') {
          if (best < 15) best = 15;
        }
      }
    }

    return best;
  }

  // ============================================================
  // 5. 실행 가능성 (0~30점)
  //
  // 개선 사항:
  // category 대신 실제 활동 특성 평가
  //
  // 장소 요구 수준 0~2
  // 교류 요구 수준 0~2
  // 소요시간 수준 0~2
  //
  // 실행 가능성 0점:
  // 기본 추천에서 제외하되,
  // 전체 목록에서 사용자가 직접 선택할 수 있음
  //
  // 사용자별 실제 접근성·건강상태·이동수단까지
  // 확인한 점수는 아니므로 보수적 휴리스틱임
  // ============================================================

  static int _feasibilityScore({
    required int placeLevel,
    required int interactionLevel,
    required int timeLevel,
    required Map<String, dynamic>? life,
  }) {
    if (life == null) {
      return placeLevel == 0 ? 30 : 15;
    }

    final outingDays = _asInt(life['outing_days_7d']);
    final interactionDays = _asInt(life['interaction_days_7d']);
    final burden = _asInt(life['outing_burden']);
    final averageMinutes = _asInt(life['avg_outing_minutes_7d']);

    int score = 30;

    // ------------------------------------------
    // 장소와 외출 부담도
    // ------------------------------------------

    if (placeLevel >= 1) {
      if (burden == null) {
        score = 15;
      } else if (burden >= 8) {
        // 외출 부담이 매우 큰 경우
        return 0;
      } else if (burden >= 5) {
        score = 15;
      }

      if (outingDays == null || outingDays == 0) {
        if (score > 15) score = 15;
      }

      // 외부 시설 방문은 추가적인 준비가 필요할 수 있음
      if (placeLevel == 2 && outingDays != null && outingDays <= 2) {
        if (score > 15) score = 15;
      }
    }

    // ------------------------------------------
    // 사회적 상호작용 경험
    // ------------------------------------------

    if (interactionLevel >= 1) {
      if (interactionDays == null || interactionDays == 0) {
        if (score > 15) score = 15;
      }

      if (interactionLevel == 2 &&
          interactionDays != null &&
          interactionDays <= 1) {
        if (score > 15) score = 15;
      }
    }

    // ------------------------------------------
    // 긴 외출 활동과 최근 외출시간
    // ------------------------------------------

    if (placeLevel >= 1 && timeLevel == 2) {
      if (averageMinutes == null || averageMinutes < 16) {
        if (score > 15) score = 15;
      }
    }

    return score;
  }

  // ============================================================
  // 6. 기존 미션 수행 피드백 (0~15점)
  // ============================================================

  static int _historyScore({
    required String missionId,
    required String category,
    required int difficulty,
    required String sevenDaysAgo,
    required Map<String, Map<String, dynamic>> latestRecords,
    required Map<String, Map<String, dynamic>> latestFeedbackByCategory,
  }) {
    final record = latestRecords[missionId];

    if (record?['status'] == 'difficult') {
      return 0;
    }

    // 최근 7일 내 완료한 동일 미션은 반복 추천 감소
    if (record?['status'] == 'completed') {
      final recordDate = record?['record_date']?.toString() ?? '';

      if (recordDate.compareTo(sevenDaysAgo) >= 0) {
        return 0;
      }
    }

    final feedback = latestFeedbackByCategory[category];

    if (feedback != null) {
      final level = _asInt(feedback['mission_difficulty']) ?? 1;

      final rating = feedback['rating']?.toString();

      final wantsChallenge = feedback['wants_more_challenge'] == true;

      if (rating == 'hard') {
        return difficulty < level ? 15 : 0;
      }

      if (rating == 'okay') {
        return difficulty == level ? 15 : 8;
      }

      if (rating == 'easy') {
        if (wantsChallenge) {
          return difficulty > level
              ? 15
              : difficulty == level
              ? 8
              : 0;
        }

        return difficulty <= level ? 15 : 8;
      }
    }

    if (record?['status'] == 'completed') {
      return 15;
    }

    return 8;
  }

  // ============================================================
  // 날짜 기반 동점 정렬
  // ============================================================

  static int _tieKey(String code, String date) {
    int value = 17;

    for (final unit in '$code-$date'.codeUnits) {
      value = (value * 31 + unit) % 2147483647;
    }

    return value;
  }

  // ============================================================
  // 7. 미션 추천 전체 계산
  // ============================================================

  static Future<MissionRecommendationResult> load() async {
    final userId = _userId;
    final today = _today();

    final thirtyDaysAgo = _dateString(
      _koreaNow().subtract(const Duration(days: 30)),
    );

    final sevenDaysAgo = _dateString(
      _koreaNow().subtract(const Duration(days: 7)),
    );

    // ------------------------------------------
    // 데이터 조회
    // ------------------------------------------

    final results = await Future.wait<dynamic>([
      _db
          .from('life_status_assessments')
          .select(
            'outing_days_7d,'
            'avg_outing_minutes_7d,'
            'interaction_days_7d,'
            'outing_burden,'
            'duration_months,'
            'completed_at',
          )
          .eq('user_id', userId)
          .eq('assessment_type', 'initial')
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle(),

      _db
          .from('life_status_assessments')
          .select(
            'outing_days_7d,'
            'avg_outing_minutes_7d,'
            'interaction_days_7d,'
            'outing_burden,'
            'completed_at',
          )
          .eq('user_id', userId)
          .eq('assessment_type', 'checkin')
          .order('completed_at', ascending: false)
          .limit(200),

      _db
          .from('profiles_v2')
          .select('interests')
          .eq('id', userId)
          .maybeSingle(),

      // v2.1: 실제 활동 조건 필드 추가
      _db
          .from('missions')
          .select(
            'id,code,category,title,'
            'description,difficulty,'
            'estimated_minutes,'
            'place_level,'
            'interaction_level,'
            'time_level',
          )
          .eq('is_active', true)
          .eq('mission_kind', 'daily'),

      _db
          .from('mission_records')
          .select('mission_id,record_date,status')
          .eq('user_id', userId)
          .gte('record_date', thirtyDaysAgo)
          .order('record_date', ascending: false)
          .limit(500),

      _db
          .from('mission_feedback')
          .select(
            'mission_id,category,'
            'mission_difficulty,rating,'
            'wants_more_challenge,created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100),
    ]);

    final initial = results[0] == null
        ? null
        : Map<String, dynamic>.from(results[0] as Map);

    final checkins = List<Map<String, dynamic>>.from(results[1] as List);

    final profile = results[2] == null
        ? null
        : Map<String, dynamic>.from(results[2] as Map);

    final missions = List<Map<String, dynamic>>.from(results[3] as List);

    final records = List<Map<String, dynamic>>.from(results[4] as List);

    final feedbacks = List<Map<String, dynamic>>.from(results[5] as List);

    // ------------------------------------------
    // 초기 난이도
    // ------------------------------------------

    final initialBurden = calculateBurden(initial);

    final initialLevel = levelForBurden(initialBurden);

    final initialAt = DateTime.tryParse(
      initial?['completed_at']?.toString() ?? '',
    );

    // ------------------------------------------
    // 주간 기록 반영
    // ------------------------------------------

    final weekly = _applyCheckins(initialLevel, initialAt, checkins);

    final currentLevel = weekly.level;

    // 최신 생활상태를 실행 가능성 평가에 사용
    final Map<String, dynamic>? currentLife =
        weekly.life ?? (initialBurden != null ? initial : null);

    // ------------------------------------------
    // 관심영역
    // ------------------------------------------

    final rawInterests = profile?['interests'];

    final interests = rawInterests is List
        ? rawInterests.map((x) => x.toString().trim()).toList()
        : <String>[];

    // ------------------------------------------
    // 최근 미션 기록
    // ------------------------------------------

    final latestRecords = <String, Map<String, dynamic>>{};

    for (final row in records) {
      latestRecords.putIfAbsent(row['mission_id'].toString(), () => row);
    }

    // ------------------------------------------
    // 카테고리별 최근 피드백
    // ------------------------------------------

    final latestFeedbackByCategory = <String, Map<String, dynamic>>{};

    for (final row in feedbacks) {
      latestFeedbackByCategory.putIfAbsent(
        row['category'].toString(),
        () => row,
      );
    }

    // ------------------------------------------
    // 미션 적합도 계산
    // ------------------------------------------

    final all = <RecommendedMission>[];

    for (final row in missions) {
      final id = row['id'].toString();

      // 오늘 이미 기록한 미션 제외
      if (latestRecords[id]?['record_date']?.toString() == today) {
        continue;
      }

      final place = _asInt(row['place_level']);

      final interaction = _asInt(row['interaction_level']);

      final time = _asInt(row['time_level']);

      // 활동 조건이 누락되었거나 잘못된 미션은
      // 자동 추천에서 제외
      if (place == null ||
          interaction == null ||
          time == null ||
          place < 0 ||
          place > 2 ||
          interaction < 0 ||
          interaction > 2 ||
          time < 0 ||
          time > 2) {
        debugPrint('미션 분류 누락/오류: ${row['code']}');
        continue;
      }

      final category = row['category']?.toString() ?? '';

      final difficulty = (_asInt(row['difficulty']) ?? 1).clamp(1, 3).toInt();

      final difference = (difficulty - currentLevel).abs();

      final feasibility = _feasibilityScore(
        placeLevel: place,
        interactionLevel: interaction,
        timeLevel: time,
        life: currentLife,
      );

      all.add(
        RecommendedMission(
          id: id,
          code: row['code'].toString(),
          title: row['title']?.toString() ?? '일상 미션',
          description: row['description']?.toString() ?? '',
          category: category,
          difficulty: difficulty,
          estimatedMinutes: _asInt(row['estimated_minutes']) ?? 5,

          interestScore: _interestScore(category, interests),

          feasibilityScore: feasibility,

          difficultyScore: difference == 0
              ? 25
              : difference == 1
              ? 15
              : 0,

          historyScore: _historyScore(
            missionId: id,
            category: category,
            difficulty: difficulty,
            sevenDaysAgo: sevenDaysAgo,
            latestRecords: latestRecords,
            latestFeedbackByCategory: latestFeedbackByCategory,
          ),
        ),
      );
    }

    // ------------------------------------------
    // 적합도 기준 정렬
    // ------------------------------------------

    all.sort((a, b) {
      final comparison = b.score.compareTo(a.score);

      if (comparison != 0) {
        return comparison;
      }

      return _tieKey(a.code, today).compareTo(_tieKey(b.code, today));
    });

    // ------------------------------------------
    // 기본 추천 3개
    //
    // 현재 난이도 이하만 선택
    // 실행 가능성 0점은 기본 추천에서 제외
    // 카테고리 다양성 고려
    // ------------------------------------------

    final eligible = all.where((mission) {
      return mission.difficulty <= currentLevel && mission.feasibilityScore > 0;
    }).toList();

    final recommended = <RecommendedMission>[];

    final usedCategories = <String>{};

    // 가능하면 서로 다른 분야의 미션 제시
    for (final mission in eligible) {
      if (usedCategories.add(mission.category)) {
        recommended.add(mission);
      }

      if (recommended.length == 3) {
        break;
      }
    }

    // 분야가 부족하면 다른 미션으로 채움
    if (recommended.length < 3) {
      for (final mission in eligible) {
        if (recommended.length == 3) {
          break;
        }

        if (!recommended.any((x) => x.id == mission.id)) {
          recommended.add(mission);
        }
      }
    }

    // ------------------------------------------
    // 선택형 도전 미션
    // 최근 두 번 모두 쉬움 + 도전 희망
    // ------------------------------------------

    final challengeUnlocked =
        feedbacks.length >= 2 &&
        feedbacks
            .take(2)
            .every(
              (f) => f['rating'] == 'easy' && f['wants_more_challenge'] == true,
            );

    RecommendedMission? optionalChallenge;

    if (challengeUnlocked && currentLevel < 3) {
      for (final mission in all) {
        if (mission.difficulty == currentLevel + 1 &&
            mission.feasibilityScore > 0) {
          optionalChallenge = mission;
          break;
        }
      }
    }

    debugPrint(
      'S-TAP 추천 v2.1: '
      '초기=$initialBurden / '
      '초기단계=$initialLevel / '
      '주간=${weekly.score} / '
      '현재단계=$currentLevel / '
      '추천=${recommended.length}개',
    );

    return MissionRecommendationResult(
      hasInitialAssessment: initialBurden != null,
      burdenScore: initialBurden,
      initialLevel: initialLevel,
      currentLevel: currentLevel,
      weeklyBurdenScore: weekly.score,
      latestCheckinAt: weekly.at,
      recommended: recommended,
      allMissions: all,
      optionalChallenge: optionalChallenge,
    );
  }

  // ============================================================
  // 8. 오늘 기록한 미션 확인
  // ============================================================

  static Future<Map<String, dynamic>?> todayRecord(String missionId) async {
    return await _db
        .from('mission_records')
        .select('id,mission_id,status')
        .eq('user_id', _userId)
        .eq('mission_id', missionId)
        .eq('record_date', _today())
        .maybeSingle();
  }

  // ============================================================
  // 9. 미션 수행 후 피드백 저장
  // ============================================================

  static Future<void> saveFeedback({
    required RecommendedMission mission,
    required String recordId,
    required String rating,
    required bool wantsMoreChallenge,
  }) async {
    if (!{'easy', 'okay', 'hard'}.contains(rating)) {
      throw ArgumentError('잘못된 피드백 값입니다.');
    }

    final record = await _db
        .from('mission_records')
        .select('id,status,mission_id')
        .eq('id', recordId)
        .eq('user_id', _userId)
        .single();

    if (record['status'] != 'completed' ||
        record['mission_id'].toString() != mission.id) {
      throw StateError('완료한 미션만 평가할 수 있어요.');
    }

    await _db.from('mission_feedback').upsert({
      'mission_record_id': recordId,
      'user_id': _userId,
      'mission_id': mission.id,
      'category': mission.category,
      'mission_difficulty': mission.difficulty,
      'rating': rating,
      'wants_more_challenge': rating == 'easy' && wantsMoreChallenge,
    }, onConflict: 'mission_record_id');
  }
}

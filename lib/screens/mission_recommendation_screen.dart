import 'package:flutter/material.dart';

import '../services/mission_recommendation_service.dart';
import 'mission_detail_screen.dart';

// ============================================================
// S-TAP 일상 미션 추천 화면 v2.0
//
// - 초기검사 + 주간 체크인 기준 난이도
// - 추천 미션 3개 및 전체 목록
// - 기존 상세 화면의 완료 / 어려움 기능 유지
// - 완료 후 체감 난이도 피드백
// - 선택형 도전 미션 추가
// ============================================================

class MissionRecommendationScreen extends StatefulWidget {
  const MissionRecommendationScreen({super.key});

  @override
  State<MissionRecommendationScreen> createState() =>
      _MissionRecommendationScreenState();
}

// ============================================================
// 사용자가 선택한 피드백
// ============================================================

class _MissionFeedbackChoice {
  final String rating;
  final bool wantsMoreChallenge;

  const _MissionFeedbackChoice(this.rating, this.wantsMoreChallenge);
}

// ============================================================
// 화면 상태
// ============================================================

class _MissionRecommendationScreenState
    extends State<MissionRecommendationScreen> {
  static const Color green = Color(0xFF00A87E);

  static const Color bg = Color(0xFFF5FFFB);

  MissionRecommendationResult? _data;

  bool _loading = true;
  bool _showAll = false;
  bool _openingMission = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // 추천 데이터 불러오기
  // ============================================================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await MissionRecommendationService.load();

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      debugPrint('미션 추천 조회 실패: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            '추천을 불러오지 못했어요.\n'
            '미션 피드백 테이블과 네트워크 연결을 확인해 주세요.';
      });
    }
  }

  // ============================================================
  // 안내 메시지
  // ============================================================

  void _notice(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // 미션 카테고리 아이콘
  // ============================================================

  IconData _icon(String category) {
    switch (category) {
      case 'outing':
        return Icons.directions_walk_rounded;

      case 'social':
        return Icons.people_outline_rounded;

      case 'routine':
        return Icons.wb_sunny_outlined;

      case 'emotion':
        return Icons.favorite_border_rounded;

      case 'self_care':
        return Icons.self_improvement_rounded;

      case 'community':
        return Icons.location_city_rounded;

      default:
        return Icons.spa_outlined;
    }
  }

  // ============================================================
  // 미션 완료 후 체감 난이도 질문
  //
  // 사용자가 원하면 건너뛸 수 있음
  // ============================================================

  Future<_MissionFeedbackChoice?> _askFeedback(RecommendedMission mission) {
    String? chosen;
    bool wantsChallenge = false;

    return showModalBottomSheet<_MissionFeedbackChoice>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, change) {
            // 피드백 선택 항목
            Widget option(String value, String title, String description) {
              final selected = chosen == value;

              return InkWell(
                onTap: () {
                  change(() {
                    chosen = value;

                    if (value != 'easy') {
                      wantsChallenge = false;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAFBF5)
                        : const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? green : const Color(0xFFE4E9E7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? green : Colors.grey,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  18 + MediaQuery.viewInsetsOf(innerContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번 미션은 어떠셨나요?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      mission.title,
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 15),

                    option('easy', '😊 쉬웠어요', '부담 없이 할 수 있었어요.'),

                    option('okay', '🙂 적당했어요', '지금 나에게 알맞았어요.'),

                    option('hard', '😥 부담스러웠어요', '다음에는 쉬운 대안이 좋아요.'),

                    if (chosen == 'easy')
                      CheckboxListTile(
                        value: wantsChallenge,
                        onChanged: (value) {
                          change(() {
                            wantsChallenge = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '다음에는 조금 더 도전해보고 싶어요',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: chosen == null
                            ? null
                            : () {
                                Navigator.pop(
                                  sheetContext,
                                  _MissionFeedbackChoice(
                                    chosen!,
                                    wantsChallenge,
                                  ),
                                );
                              },
                        child: const Text('피드백 저장하기'),
                      ),
                    ),

                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('건너뛰기'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 기존 미션 상세 화면으로 이동
  //
  // 기록 결과가 completed이면 피드백 질문
  // difficult이면 기존 사유 기록만 사용
  // ============================================================

  Future<void> _openMission(RecommendedMission mission) async {
    if (_openingMission) return;

    setState(() {
      _openingMission = true;
    });

    try {
      final recorded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MissionDetailScreen(missionCode: mission.code),
        ),
      );

      if (!mounted) return;

      // 기록하지 않고 나왔을 경우
      if (recorded != true) {
        await _load();
        return;
      }

      // 완료 기록 확인
      try {
        final record = await MissionRecommendationService.todayRecord(
          mission.id,
        );

        if (!mounted) return;

        if (record != null && record['status'] == 'completed') {
          final feedback = await _askFeedback(mission);

          if (!mounted) return;

          // 건너뛰기 선택 시 피드백 미저장
          if (feedback != null) {
            await MissionRecommendationService.saveFeedback(
              mission: mission,
              recordId: record['id'].toString(),
              rating: feedback.rating,
              wantsMoreChallenge: feedback.wantsMoreChallenge,
            );
          }
        }
      } catch (error) {
        debugPrint('미션 피드백 저장 오류: $error');

        _notice(
          '미션 완료는 기록됐지만 '
          '피드백 저장은 실패했어요.',
        );
      }

      // 홈으로 돌아가 주간 활동 새로고침
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingMission = false;
        });
      }
    }
  }

  // ============================================================
  // 미션 카드
  // ============================================================

  Widget _missionCard(RecommendedMission mission, {bool featured = false}) {
    return InkWell(
      onTap: _openingMission
          ? null
          : () {
              _openMission(mission);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: featured ? green : const Color(0xFFE1E9E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAFBF5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_icon(mission.category), color: green),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mission.categoryName} · '
                        '${mission.difficulty}단계 · '
                        '약 ${mission.estimatedMinutes}분',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B7770),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${mission.score}점',
                      style: const TextStyle(
                        color: green,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const Text(
                      '적합도',
                      style: TextStyle(fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 11),

            Text(
              mission.description,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF606D67)),
            ),

            const SizedBox(height: 9),

            // 점수 구성 공개
            Text(
              '관심 ${mission.interestScore}/30 · '
              '실행 ${mission.feasibilityScore}/30 · '
              '난이도 ${mission.difficultyScore}/25 · '
              '피드백 ${mission.historyScore}/15',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7B8781),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 7),

            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(color: green, fontWeight: FontWeight.w700),
                ),

                SizedBox(width: 4),

                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 추천 단계 안내 카드
  // ============================================================

  Widget _sourceCard(MissionRecommendationResult data) {
    final recent = data.latestCheckinAt;

    final localDate = recent == null
        ? ''
        : '${recent.toLocal().year}.'
              '${recent.toLocal().month}.'
              '${recent.toLocal().day}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F9F2),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 추천 기준: ${data.currentLevel}단계',
            style: const TextStyle(
              color: Color(0xFF257662),
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            data.hasInitialAssessment
                ? '초기 생활상태 '
                      '${data.burdenScore}/13점 · '
                      '시작 ${data.initialLevel}단계'
                : '초기검사 정보 없음 · '
                      '1단계부터 시작',
            style: const TextStyle(fontSize: 12.5),
          ),

          if (recent != null)
            Text(
              '최근 주간 기록: $localDate · '
              '${data.weeklyBurdenScore}/9점',
              style: const TextStyle(fontSize: 12.5),
            ),

          if (recent == null)
            const Text(
              '주간 기록 전이므로 '
              '초기검사 기준을 사용해요.',
              style: TextStyle(fontSize: 12.5),
            ),

          const SizedBox(height: 7),

          const Text(
            '주간 기록으로 기본 단계를 조정하고, '
            '수행 피드백으로 미션별 추천을 다듬어요. '
            '단계와 점수는 진단 결과가 아니에요.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF5E756C),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 메인 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final data = _data;

    final visible = data == null
        ? <RecommendedMission>[]
        : _showAll
        ? data.allMissions
        : data.recommended;

    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        title: const Text(
          '일상 미션 추천',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),

                  const SizedBox(height: 12),

                  FilledButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            )
          : RefreshIndicator(
              color: green,
              onRefresh: _load,

              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),

                children: [
                  const Text(
                    '오늘은 어떤 작은 활동을 해볼까요?',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '추천은 선택지예요. '
                    '원하는 미션을 직접 골라도 괜찮아요.',
                    style: TextStyle(fontSize: 13.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 18),

                  _sourceCard(data!),

                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _showAll ? '전체 미션' : '오늘의 추천 미션 3개',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAll = !_showAll;
                          });
                        },
                        child: Text(_showAll ? '추천만 보기' : '다른 미션 보기'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('오늘 추천할 새 미션이 없어요.')),
                    )
                  else
                    for (int i = 0; i < visible.length; i++)
                      _missionCard(visible[i], featured: !_showAll && i == 0),

                  // ----------------------------------------
                  // 선택형 한 단계 높은 미션
                  // ----------------------------------------
                  if (!_showAll && data.optionalChallenge != null) ...[
                    const SizedBox(height: 8),

                    const Text(
                      '원한다면, 조금 더 도전해볼까요?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      '최근 두 번의 피드백에서 '
                      '더 도전하고 싶다고 선택했기 때문에 '
                      '추가로 제안해요. '
                      '선택하지 않아도 괜찮아요.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _missionCard(data.optionalChallenge!),
                  ],

                  const SizedBox(height: 12),

                  const Text(
                    '완료하지 못한 날도 괜찮아요. '
                    '미션을 완료하면 짧은 피드백을 '
                    '남길 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

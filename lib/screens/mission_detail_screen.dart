import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionDetailScreen extends StatefulWidget {
  final String missionCode;

  const MissionDetailScreen({super.key, this.missionCode = 'walk_5min'});

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color orangeColor = Color(0xFFEF8B2C);
  static const Color backgroundColor = Color(0xFFF5FFFB);

  Map<String, dynamic>? mission;
  Map<String, dynamic>? todayRecord;

  bool isLoadingMission = true;
  bool isSaving = false;

  String? loadError;

  @override
  void initState() {
    super.initState();

    _loadMissionAndRecord();
  }

  // ============================================================
  // 오늘 날짜
  // ============================================================

  String _localDateString(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // 미션 + 오늘 기록 불러오기
  // ============================================================

  Future<void> _loadMissionAndRecord() async {
    setState(() {
      isLoadingMission = true;
      loadError = null;
    });

    try {
      final currentMission = await Supabase.instance.client
          .from('missions')
          .select(
            'id, code, mission_kind, category, title, description, '
            'reason, instructions, difficulty, estimated_minutes, '
            'is_active',
          )
          .eq('code', widget.missionCode)
          .eq('is_active', true)
          .maybeSingle();

      if (currentMission == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          mission = null;
          todayRecord = null;
          isLoadingMission = false;
          loadError = '미션을 찾을 수 없어요.';
        });

        return;
      }

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          mission = null;
          todayRecord = null;
          isLoadingMission = false;
          loadError = '로그인 정보를 확인할 수 없어요.';
        });

        return;
      }

      final today = _localDateString(DateTime.now());

      final existingRecord = await Supabase.instance.client
          .from('mission_records')
          .select(
            'id, user_id, mission_id, record_date, status, '
            'difficulty_reason, completed_at, created_at, updated_at',
          )
          .eq('user_id', user.id)
          .eq('mission_id', currentMission['id'])
          .eq('record_date', today)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      setState(() {
        mission = currentMission;
        todayRecord = existingRecord;
        isLoadingMission = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('미션 불러오기 오류: $error');

      setState(() {
        mission = null;
        todayRecord = null;
        isLoadingMission = false;
        loadError = '미션을 불러오지 못했어요.\n\n$error';
      });
    }
  }

  // ============================================================
  // 미션 결과 저장
  //
  // 이제 upsert가 아니라 insert
  // 오늘 결과가 이미 존재하면 덮어쓰지 않음
  // ============================================================

  Future<bool> _saveMissionRecord({
    required String status,
    String? difficultyReason,
  }) async {
    if (isSaving) {
      return false;
    }

    if (todayRecord != null) {
      _showErrorMessage('오늘의 미션은 이미 기록되어 있어요.');

      return false;
    }

    final currentMission = mission;

    if (currentMission == null) {
      _showErrorMessage('미션 정보를 확인할 수 없어요.');

      return false;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showErrorMessage('로그인 정보를 확인할 수 없어요.');

      return false;
    }

    final missionId = currentMission['id']?.toString();

    if (missionId == null || missionId.trim().isEmpty) {
      _showErrorMessage('미션 정보를 확인할 수 없어요.');

      return false;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      final insertedRecord = await Supabase.instance.client
          .from('mission_records')
          .insert({
            'user_id': user.id,
            'mission_id': missionId,
            'record_date': _localDateString(now),
            'status': status,
            'difficulty_reason': difficultyReason,
            'completed_at': status == 'completed'
                ? now.toUtc().toIso8601String()
                : null,
            'updated_at': now.toUtc().toIso8601String(),
          })
          .select(
            'id, user_id, mission_id, record_date, status, '
            'difficulty_reason, completed_at, created_at, updated_at',
          )
          .single();

      if (!mounted) {
        return false;
      }

      setState(() {
        todayRecord = insertedRecord;
        isSaving = false;
      });

      return true;
    } on PostgrestException catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        isSaving = false;
      });

      // 같은 날 같은 미션이 이미 존재하는 경우
      if (error.code == '23505') {
        await _loadMissionAndRecord();

        if (!mounted) {
          return false;
        }

        _showErrorMessage('오늘의 미션은 이미 기록되어 있어요.');

        return false;
      }

      debugPrint('미션 기록 저장 오류: ${error.message}');

      _showErrorMessage('기록을 저장하지 못했어요.\n${error.message}');

      return false;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        isSaving = false;
      });

      debugPrint('미션 기록 저장 오류: $error');

      _showErrorMessage('기록을 저장하지 못했어요.\n$error');

      return false;
    }
  }

  // ============================================================
  // 오류 메시지
  // ============================================================

  void _showErrorMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // 완료
  // ============================================================

  Future<void> _completeMission() async {
    final saved = await _saveMissionRecord(status: 'completed');

    if (!saved || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8FFF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: primaryColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '오늘의 한 걸음을 완료했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF151918),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '오늘 미션은 완료로 기록되었어요.\n'
                '이 기록은 오늘 동안 변경되지 않아요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFF666C69),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 오늘은 어려워요
  // ============================================================

  Future<void> _showDifficultySheet() async {
    if (todayRecord != null) {
      return;
    }

    String? selectedReason;
    bool isSheetSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final reasons = [
              '기분이나 컨디션이 좋지 않았어요',
              '밖에 나가는 것이 부담스러웠어요',
              '사람을 마주치는 것이 부담스러웠어요',
              '시간이 부족했어요',
              '미션이 너무 어려웠어요',
              '기타',
            ];

            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                14,
                22,
                22 + MediaQuery.of(innerContext).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DDDB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '오늘은 어떤 점이 어려웠나요?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF151918),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '괜찮아요. 오늘의 상태를 기록해두면 '
                    '앞으로 활동을 조절하는 데 도움이 될 수 있어요.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF707572),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...reasons.map((reason) {
                    final selected = selectedReason == reason;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: InkWell(
                        onTap: isSheetSaving
                            ? null
                            : () {
                                setSheetState(() {
                                  selectedReason = reason;
                                });
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFF3E4)
                                : const Color(0xFFF8FAF9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFF6B46F)
                                  : const Color(0xFFE1E6E4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? orangeColor
                                    : const Color(0xFF9A9F9D),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: const Color(0xFF353938),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: selectedReason == null || isSheetSaving
                          ? null
                          : () async {
                              setSheetState(() {
                                isSheetSaving = true;
                              });

                              final saved = await _saveMissionRecord(
                                status: 'difficult',
                                difficultyReason: selectedReason,
                              );

                              if (!mounted) {
                                return;
                              }

                              if (!saved) {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isSheetSaving = false;
                                  });
                                }

                                return;
                              }

                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('오늘은 어려웠던 미션으로 기록했어요.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              Navigator.of(context).pop(true);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: orangeColor,
                        disabledBackgroundColor: const Color(0xFFE4E7E6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: isSheetSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '기록하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 미션 데이터
  // ============================================================

  String get _missionTitle {
    return mission?['title']?.toString() ?? '오늘의 일상 미션';
  }

  String get _missionDescription {
    return mission?['description']?.toString() ?? '';
  }

  String get _missionReason {
    return mission?['reason']?.toString() ?? '';
  }

  String get _missionInstructions {
    return mission?['instructions']?.toString() ?? '';
  }

  int get _difficulty {
    final value = mission?['difficulty'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  int? get _estimatedMinutes {
    final value = mission?['estimated_minutes'];

    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  String get _difficultyLabel {
    switch (_difficulty) {
      case 1:
        return '가볍게 시작하기';

      case 2:
        return '조금 도전해보기';

      case 3:
        return '도전해보기';

      default:
        return '가볍게 시작하기';
    }
  }

  String get _estimatedTimeLabel {
    final minutes = _estimatedMinutes;

    if (minutes == null) {
      return '자유롭게';
    }

    return '약 $minutes분';
  }

  String get _categoryLabel {
    final category = mission?['category']?.toString();

    switch (category) {
      case 'outing':
        return '외출 · 일상 활동';

      case 'social':
        return '대인관계';

      case 'routine':
        return '생활 루틴';

      case 'emotion':
        return '감정 표현';

      case 'self_care':
        return '자기관리';

      case 'community':
        return '사회 활동';

      default:
        return '일상 활동';
    }
  }

  IconData get _missionIcon {
    final category = mission?['category']?.toString();

    switch (category) {
      case 'outing':
        return Icons.directions_walk_rounded;

      case 'social':
        return Icons.people_alt_outlined;

      case 'routine':
        return Icons.schedule_rounded;

      case 'emotion':
        return Icons.sentiment_satisfied_alt_rounded;

      case 'self_care':
        return Icons.self_improvement_rounded;

      case 'community':
        return Icons.location_city_rounded;

      default:
        return Icons.directions_walk_rounded;
    }
  }

  // ============================================================
  // 오늘 기록 상태
  // ============================================================

  String? get _todayStatus {
    return todayRecord?['status']?.toString();
  }

  bool get _isCompletedToday {
    return _todayStatus == 'completed';
  }

  bool get _isDifficultToday {
    return _todayStatus == 'difficult';
  }

  String? get _difficultyReason {
    return todayRecord?['difficulty_reason']?.toString();
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
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          '오늘의 일상 미션',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF151918),
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (isLoadingMission) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (loadError != null || mission == null) {
      return _buildErrorScreen();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMissionMainCard(),

          const SizedBox(height: 18),

          _buildMissionInfoCard(),

          const SizedBox(height: 18),

          _buildReasonCard(),

          if (_missionInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildInstructionsCard(),
          ],

          const SizedBox(height: 26),

          if (todayRecord == null)
            _buildActionButtons()
          else
            _buildRecordedStatusCard(),
        ],
      ),
    );
  }

  // ============================================================
  // 오류 화면
  // ============================================================

  Widget _buildErrorScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0D9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: orangeColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              loadError ?? '미션을 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF151918),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loadMissionAndRecord,
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 메인 미션 카드
  // ============================================================

  Widget _buildMissionMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFE1B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEED7),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '오늘의 일상 미션',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFC86B17),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEED7),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(_missionIcon, size: 46, color: orangeColor),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _missionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                height: 1.3,
                fontWeight: FontWeight.w900,
                color: Color(0xFF151918),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Text(
              _missionDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF666C69),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 미션 정보
  // ============================================================

  Widget _buildMissionInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '미션 정보',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF151918),
            ),
          ),
          const SizedBox(height: 18),
          _MissionInfoRow(
            icon: Icons.speed_rounded,
            title: '난이도',
            value: _difficultyLabel,
          ),
          const SizedBox(height: 16),
          _MissionInfoRow(
            icon: Icons.schedule_rounded,
            title: '예상 시간',
            value: _estimatedTimeLabel,
          ),
          const SizedBox(height: 16),
          _MissionInfoRow(
            icon: Icons.category_outlined,
            title: '활동 영역',
            value: _categoryLabel,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 미션 이유
  // ============================================================

  Widget _buildReasonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9E7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: primaryColor,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '왜 이 미션을 하나요?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151918),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _missionReason,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: Color(0xFF666C69),
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
  // 수행 방법
  // ============================================================

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9E7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checklist_rounded, color: primaryColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이렇게 해봐요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151918),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _missionInstructions,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: Color(0xFF666C69),
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
  // 아직 기록이 없을 때 버튼
  // ============================================================

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: isSaving ? null : _completeMission,
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: primaryColor.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              isSaving ? '저장 중...' : '완료했어요',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: isSaving ? null : _showDifficultySheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF777D7A),
              side: const BorderSide(color: Color(0xFFD8DEDC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              '오늘은 어려워요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            '완료하지 못해도 괜찮아요. 나에게 맞는 속도로 진행해요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF919795),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 이미 기록된 미션 상태
  // ============================================================

  Widget _buildRecordedStatusCard() {
    if (_isCompletedToday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFEFFFF8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryColor.withValues(alpha: 0.24)),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_rounded, size: 48, color: primaryColor),
            SizedBox(height: 14),
            Text(
              '이미 완료한 미션이에요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF151918),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '오늘의 한 걸음이 정상적으로 기록되어 있어요.\n'
              '내일 새로운 미션에서 다시 만나요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF66706C),
              ),
            ),
          ],
        ),
      );
    }

    if (_isDifficultToday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7EC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFD7A5)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.favorite_outline_rounded,
              size: 46,
              color: orangeColor,
            ),
            const SizedBox(height: 14),
            const Text(
              '오늘은 어려웠던 미션이에요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF151918),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '오늘의 상태도 중요한 기록이에요.\n'
              '무리하지 않고 다음 활동을 이어가면 돼요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF706A63),
              ),
            ),
            if (_difficultyReason != null &&
                _difficultyReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      '기록한 이유',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF97918A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _difficultyReason!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3D3A37),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9E7)),
      ),
      child: const Text(
        '오늘의 미션 기록이 이미 저장되어 있어요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666C69),
        ),
      ),
    );
  }
}

// ============================================================
// 미션 정보 행
// ============================================================

class _MissionInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MissionInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FBF7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF00A87E), size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF888E8B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2B302E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

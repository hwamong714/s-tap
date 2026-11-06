import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';

class LifeStatusScreen extends StatefulWidget {
  /// false:
  /// 온보딩 최초 생활상태 검사
  /// assessment_type = initial
  ///
  /// true:
  /// 기록 탭에서 진행하는 주간 생활상태 기록
  /// assessment_type = checkin
  final bool isCheckin;

  const LifeStatusScreen({super.key, this.isCheckin = false});

  @override
  State<LifeStatusScreen> createState() => _LifeStatusScreenState();
}

class _LifeStatusScreenState extends State<LifeStatusScreen> {
  static const Color primaryColor = Color(0xFF00A87E);

  static const Color errorColor = Color(0xFFE5484D);

  int currentStep = 0;

  bool showError = false;

  bool isSaving = false;

  // ==========================================================
  // 검사 문항 수
  //
  // 초기검사: 5문항
  // 주간 체크인: 4문항
  // ==========================================================

  int get _totalSteps => widget.isCheckin ? 4 : 5;

  int get _lastStep => _totalSteps - 1;

  // ==========================================================
  // 1. 최근 7일 외출 일수
  // ==========================================================

  final TextEditingController outingDaysController = TextEditingController();

  // ==========================================================
  // 2. 외출한 날 하루 평균 외출시간
  // ==========================================================

  final TextEditingController outingHoursController = TextEditingController();

  final TextEditingController outingMinutesController = TextEditingController();

  // ==========================================================
  // 3. 최근 7일 대면 교류 일수
  // ==========================================================

  final TextEditingController interactionDaysController =
      TextEditingController();

  // ==========================================================
  // 4. 외출 부담도
  // ==========================================================

  int? outingBurden;

  // ==========================================================
  // 5. 현재 생활상태 지속기간
  //
  // 초기검사에서만 사용
  // ==========================================================

  final TextEditingController durationMonthsController =
      TextEditingController();

  // ==========================================================
  // Dispose
  // ==========================================================

  @override
  void dispose() {
    outingDaysController.dispose();
    outingHoursController.dispose();
    outingMinutesController.dispose();
    interactionDaysController.dispose();
    durationMonthsController.dispose();

    super.dispose();
  }

  // ==========================================================
  // Getter
  // ==========================================================

  int get _outingDays {
    return int.tryParse(outingDaysController.text.trim()) ?? 0;
  }

  int get _averageOutingMinutes {
    if (_outingDays == 0) {
      return 0;
    }

    final hours = int.tryParse(outingHoursController.text.trim()) ?? 0;

    final minutes = int.tryParse(outingMinutesController.text.trim()) ?? 0;

    return (hours * 60) + minutes;
  }

  // ==========================================================
  // 현재 단계 유효성 검사
  // ==========================================================

  bool _isCurrentStepValid() {
    switch (currentStep) {
      case 0:
        final days = int.tryParse(outingDaysController.text.trim());

        return days != null && days >= 0 && days <= 7;

      case 1:
        if (_outingDays == 0) {
          return true;
        }

        final hours = int.tryParse(outingHoursController.text.trim()) ?? 0;

        final minutes = int.tryParse(outingMinutesController.text.trim()) ?? 0;

        final hoursValid = hours >= 0 && hours <= 23;

        final minutesValid = minutes >= 0 && minutes <= 59;

        return hoursValid && minutesValid && ((hours * 60) + minutes > 0);

      case 2:
        final days = int.tryParse(interactionDaysController.text.trim());

        return days != null && days >= 0 && days <= 7;

      case 3:
        return outingBurden != null;

      case 4:
        // 체크인에서는 5번 문항 자체가 없음
        if (widget.isCheckin) {
          return true;
        }

        final months = int.tryParse(durationMonthsController.text.trim());

        return months != null && months >= 0;

      default:
        return false;
    }
  }

  // ==========================================================
  // 다음
  // ==========================================================

  void _goNext() {
    FocusScope.of(context).unfocus();

    if (!_isCurrentStepValid()) {
      setState(() {
        showError = true;
      });

      return;
    }

    if (currentStep < _lastStep) {
      setState(() {
        currentStep++;
        showError = false;
      });
    } else {
      _finishAssessment();
    }
  }

  // ==========================================================
  // 이전
  // ==========================================================

  void _goPrevious() {
    if (isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (currentStep == 0) {
      Navigator.pop(context);

      return;
    }

    setState(() {
      currentStep--;
      showError = false;
    });
  }

  // ==========================================================
  // Supabase 저장
  // ==========================================================

  Future<void> _finishAssessment() async {
    if (isSaving) {
      return;
    }

    if (!_isCurrentStepValid()) {
      setState(() {
        showError = true;
      });

      return;
    }

    FocusScope.of(context).unfocus();

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));

      return;
    }

    final outingDays = int.parse(outingDaysController.text.trim());

    final averageOutingMinutes = _averageOutingMinutes;

    final interactionDays = int.parse(interactionDaysController.text.trim());

    final burden = outingBurden!;

    // 초기검사에서만 지속기간 사용
    final int? durationMonths = widget.isCheckin
        ? null
        : int.parse(durationMonthsController.text.trim());

    setState(() {
      isSaving = true;
      showError = false;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // ======================================================
      // CHECKIN
      //
      // 지속기간은 저장하지 않음
      // ======================================================

      if (widget.isCheckin) {
        await Supabase.instance.client.from('life_status_assessments').insert({
          'user_id': user.id,

          'assessment_type': 'checkin',

          'outing_days_7d': outingDays,

          'avg_outing_minutes_7d': averageOutingMinutes,

          'interaction_days_7d': interactionDays,

          'outing_burden': burden,

          'completed_at': now,
        });

        if (!mounted) {
          return;
        }

        Navigator.pop(context, true);

        return;
      }

      // ======================================================
      // INITIAL
      //
      // 사용자당 초기 기록 1개 유지
      // ======================================================

      final existingAssessment = await Supabase.instance.client
          .from('life_status_assessments')
          .select('id')
          .eq('user_id', user.id)
          .eq('assessment_type', 'initial')
          .limit(1)
          .maybeSingle();

      final initialData = {
        'user_id': user.id,

        'assessment_type': 'initial',

        'outing_days_7d': outingDays,

        'avg_outing_minutes_7d': averageOutingMinutes,

        'interaction_days_7d': interactionDays,

        'outing_burden': burden,

        'duration_months': durationMonths,

        'completed_at': now,
      };

      if (existingAssessment == null) {
        await Supabase.instance.client
            .from('life_status_assessments')
            .insert(initialData);
      } else {
        await Supabase.instance.client
            .from('life_status_assessments')
            .update({
              'outing_days_7d': outingDays,

              'avg_outing_minutes_7d': averageOutingMinutes,

              'interaction_days_7d': interactionDays,

              'outing_burden': burden,

              'duration_months': durationMonths,

              'completed_at': now,
            })
            .eq('id', existingAssessment['id']);
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('생활상태 저장 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isCheckin
                ? '생활상태 기록 중 오류가 발생했습니다.\n$error'
                : '생활상태 저장 중 오류가 발생했습니다.\n$error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ==========================================================
  // 오류 문구
  // ==========================================================

  String get _errorMessage {
    switch (currentStep) {
      case 0:
        return '0일부터 7일 사이의 숫자를 입력해주세요.';

      case 1:
        return '평균 외출시간을 확인해주세요. '
            '분은 0~59 사이로 입력해주세요.';

      case 2:
        return '0일부터 7일 사이의 숫자를 입력해주세요.';

      case 3:
        return '현재 느끼는 외출 부담도를 선택해주세요.';

      case 4:
        return '지속기간을 개월 단위로 입력해주세요.';

      default:
        return '내용을 확인해주세요.';
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        elevation: 0,

        leading: IconButton(
          onPressed: isSaving ? null : _goPrevious,

          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 21,
            color: Colors.black87,
          ),
        ),

        title: Text(
          widget.isCheckin ? '이번 주 생활상태 기록' : '현재 생활상태 확인',

          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // 진행 상황
                    // ==========================================

                    Row(
                      children: [
                        Text(
                          '${currentStep + 1}',

                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),

                        Text(
                          ' / $_totalSteps',

                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          '${(progress * 100).round()}%',

                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),

                      child: LinearProgressIndicator(
                        value: progress,

                        minHeight: 7,

                        backgroundColor: const Color(0xFFE9EFED),

                        valueColor: const AlwaysStoppedAnimation<Color>(
                          primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 34),

                    // ==========================================
                    // 체크인 안내
                    // ==========================================
                    if (widget.isCheckin) ...[
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.06),

                          borderRadius: BorderRadius.circular(16),
                        ),

                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: primaryColor,
                            ),

                            SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                '최근 7일의 생활을 돌아보며 '
                                '현재 상태를 기록해보세요.',

                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),
                    ],

                    _buildCurrentQuestion(),

                    if (showError) ...[
                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),

                        decoration: BoxDecoration(
                          color: errorColor.withValues(alpha: 0.07),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: errorColor,
                              size: 19,
                            ),

                            const SizedBox(width: 9),

                            Expanded(
                              child: Text(
                                _errorMessage,

                                style: const TextStyle(
                                  color: errorColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ================================================
            // 하단 버튼
            // ================================================
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),

              decoration: BoxDecoration(
                color: Colors.white,

                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,

                      child: OutlinedButton(
                        onPressed: isSaving ? null : _goPrevious,

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,

                          side: const BorderSide(color: Color(0xFFD8DEDC)),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),

                        child: Text(
                          currentStep == 0 ? '나가기' : '이전',

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,

                    child: SizedBox(
                      height: 56,

                      child: ElevatedButton(
                        onPressed: isSaving ? null : _goNext,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,

                          foregroundColor: Colors.white,

                          disabledBackgroundColor: primaryColor.withValues(
                            alpha: 0.55,
                          ),

                          disabledForegroundColor: Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),

                        child: isSaving
                            ? const SizedBox(
                                width: 23,
                                height: 23,

                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                currentStep == _lastStep
                                    ? widget.isCheckin
                                          ? '기록하기'
                                          : '완료하기'
                                    : '다음',

                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
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

  // ==========================================================
  // 현재 질문
  // ==========================================================

  Widget _buildCurrentQuestion() {
    switch (currentStep) {
      case 0:
        return _buildOutingDaysQuestion();

      case 1:
        return _buildOutingTimeQuestion();

      case 2:
        return _buildInteractionDaysQuestion();

      case 3:
        return _buildOutingBurdenQuestion();

      case 4:
        if (!widget.isCheckin) {
          return _buildDurationQuestion();
        }

        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================
  // 질문 공통 헤더
  // ==========================================================

  Widget _buildQuestionHeader({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(
            fontSize: 25,
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          description,

          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 1. 최근 7일 외출 일수
  // ==========================================================

  Widget _buildOutingDaysQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildQuestionHeader(
          title: '최근 7일 동안\n밖에 나간 날은 며칠인가요?',

          description: '잠깐이라도 집 밖으로 나간 날을 기준으로 입력해주세요.',
        ),

        const SizedBox(height: 38),

        _daysInput(controller: outingDaysController),

        const SizedBox(height: 22),

        _infoBox(
          '예: 월요일과 금요일에 외출했다면 '
          '2일로 입력해주세요.',
        ),
      ],
    );
  }

  // ==========================================================
  // 2. 하루 평균 외출시간
  // ==========================================================

  Widget _buildOutingTimeQuestion() {
    final noOuting = _outingDays == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildQuestionHeader(
          title: '외출한 날에는 하루 평균\n얼마나 오래 밖에 있었나요?',

          description:
              '최근 7일 동안 외출했던 날의 '
              '평균적인 시간을 입력해주세요.',
        ),

        const SizedBox(height: 38),

        if (noOuting)
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(22),

            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F7),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: const Color(0xFFE1E7E5)),
            ),

            child: const Column(
              children: [
                Icon(Icons.schedule_rounded, size: 38, color: primaryColor),

                SizedBox(height: 14),

                Text(
                  '최근 7일 외출이 0일이에요.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  '평균 외출시간은 자동으로 '
                  '0분으로 기록할게요.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _timeInput(
                  controller: outingHoursController,

                  suffix: '시간',

                  maxLength: 2,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _timeInput(
                  controller: outingMinutesController,

                  suffix: '분',

                  maxLength: 2,
                ),
              ),
            ],
          ),

        const SizedBox(height: 22),

        if (!noOuting)
          _infoBox(
            '예: 평균 1시간 30분 정도 외출했다면 '
            '1시간 / 30분으로 입력해주세요.',
          ),
      ],
    );
  }

  // ==========================================================
  // 3. 대면교류 일수
  // ==========================================================

  Widget _buildInteractionDaysQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildQuestionHeader(
          title: '최근 7일 동안\n사람과 직접 교류한 날은 며칠인가요?',

          description:
              '직접 만나 대화하거나 함께 시간을 보낸 날을 '
              '기준으로 입력해주세요.',
        ),

        const SizedBox(height: 38),

        _daysInput(controller: interactionDaysController),

        const SizedBox(height: 22),

        _infoBox(
          '같은 날 여러 사람을 만났더라도 '
          '1일로 계산해주세요.',
        ),
      ],
    );
  }

  // ==========================================================
  // 4. 외출 부담도
  // ==========================================================

  Widget _buildOutingBurdenQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildQuestionHeader(
          title: '요즘 외출하는 것은\n얼마나 부담스럽게 느껴지나요?',

          description:
              '현재 느끼는 정도와 가장 가까운 숫자를 '
              '선택해주세요.',
        ),

        const SizedBox(height: 34),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),

          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),

            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: outingBurden != null
                  ? primaryColor
                  : const Color(0xFFE1E7E5),

              width: outingBurden != null ? 1.5 : 1,
            ),
          ),

          child: Column(
            children: [
              if (outingBurden != null) ...[
                Text(
                  '$outingBurden',

                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _burdenLabel(outingBurden!),

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 14),
              ] else ...[
                Text(
                  '숫자를 선택해주세요',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),

                const SizedBox(height: 18),
              ],

              Slider(
                value: (outingBurden ?? 5).toDouble(),

                min: 0,
                max: 10,
                divisions: 10,

                activeColor: primaryColor,

                onChanged: (value) {
                  setState(() {
                    outingBurden = value.round();

                    showError = false;
                  });
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Text(
                      '0\n전혀 부담 없음',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),

                    Text(
                      '10\n매우 부담됨',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _infoBox(
          '정답은 없어요. 지금 실제로 느껴지는 부담을 '
          '기준으로 선택해주세요.',
        ),
      ],
    );
  }

  // ==========================================================
  // 5. 지속기간
  // 초기검사 전용
  // ==========================================================

  Widget _buildDurationQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildQuestionHeader(
          title: '현재와 비슷한 생활은\n약 몇 개월 동안 지속됐나요?',

          description:
              '정확하지 않아도 괜찮아요. '
              '대략적인 기간을 입력해주세요.',
        ),

        const SizedBox(height: 38),

        Center(
          child: SizedBox(
            width: 220,

            child: TextField(
              controller: durationMonthsController,

              keyboardType: TextInputType.number,

              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,

                LengthLimitingTextInputFormatter(3),
              ],

              onChanged: (_) {
                if (showError) {
                  setState(() {
                    showError = false;
                  });
                }
              },

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: primaryColor,
              ),

              decoration: InputDecoration(
                hintText: '0',

                suffixText: '개월',

                suffixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),

                filled: true,

                fillColor: const Color(0xFFF8FAF9),

                counterText: '',

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 25,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),

                  borderSide: const BorderSide(color: Color(0xFFE1E7E5)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),

                  borderSide: const BorderSide(color: primaryColor, width: 1.8),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        _infoBox(
          '1년은 12개월, 2년은 24개월로 입력해주세요.\n'
          '1개월 미만이라면 0으로 입력하면 돼요.',
        ),
      ],
    );
  }

  // ==========================================================
  // 일수 입력
  // ==========================================================

  Widget _daysInput({required TextEditingController controller}) {
    return Center(
      child: SizedBox(
        width: 190,

        child: TextField(
          controller: controller,

          keyboardType: TextInputType.number,

          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,

            LengthLimitingTextInputFormatter(1),
          ],

          onChanged: (_) {
            if (showError) {
              setState(() {
                showError = false;
              });
            }
          },

          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: primaryColor,
          ),

          decoration: InputDecoration(
            hintText: '0',

            suffixText: '일',

            suffixStyle: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),

            filled: true,

            fillColor: const Color(0xFFF8FAF9),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 26,
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),

              borderSide: const BorderSide(color: Color(0xFFE1E7E5)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),

              borderSide: const BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // 시간 입력
  // ==========================================================

  Widget _timeInput({
    required TextEditingController controller,
    required String suffix,
    required int maxLength,
  }) {
    return TextField(
      controller: controller,

      keyboardType: TextInputType.number,

      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,

        LengthLimitingTextInputFormatter(maxLength),
      ],

      onChanged: (_) {
        if (showError) {
          setState(() {
            showError = false;
          });
        }
      },

      textAlign: TextAlign.center,

      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        color: primaryColor,
      ),

      decoration: InputDecoration(
        hintText: '0',

        suffixText: suffix,

        suffixStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),

        filled: true,

        fillColor: const Color(0xFFF8FAF9),

        counterText: '',

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 23,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: const BorderSide(color: Color(0xFFE1E7E5)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
    );
  }

  // ==========================================================
  // 안내 박스
  // ==========================================================

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: primaryColor),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              text,

              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 부담도 문구
  // ==========================================================

  String _burdenLabel(int value) {
    if (value <= 2) {
      return '부담이 거의 없어요';
    }

    if (value <= 4) {
      return '조금 부담스러워요';
    }

    if (value <= 6) {
      return '어느 정도 부담스러워요';
    }

    if (value <= 8) {
      return '많이 부담스러워요';
    }

    return '매우 부담스러워요';
  }
}

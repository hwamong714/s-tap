import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hq25_result_screen.dart';

class Hq25Screen extends StatefulWidget {
  const Hq25Screen({super.key});

  @override
  State<Hq25Screen> createState() => _Hq25ScreenState();
}

class _Hq25ScreenState extends State<Hq25Screen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color errorColor = Color(0xFFE5484D);

  int currentIndex = 0;

  bool showAnswerError = false;
  bool midpointShown = false;
  bool isSaving = false;

  // HQ-25 한국어판 25문항
  final List<String> questions = const [
    '사람과 거리를 둔다.',
    '하루 종일 거의 집에서 보낸다.',
    '중요한 일에 대해 의논할 사람이 정말로 아무도 없다.',
    '모르는 사람과 만나는 것을 아주 좋아한다.',
    '나의 방에 틀어 박혀 있다.',
    '사람이 귀찮다.',
    '나의 생활에 있어서 나를 이해해 주려고 하는 사람들이 있다.',
    '누군가와 함께 있는 것이 불편하게 느껴진다.',
    '하루 종일 거의 혼자서 지낸다.',
    '몇몇 사람들에게 개인적인 생각을 털어놓을 수 있다.',
    '사람들에게 보여지는 것이 싫다.',
    '사람과 직접 만나는 것이 거의 없다.',
    '집단에 들어가는 것이 서투르다.',
    '중요한 문제에 대해서 의논할 사람이 별로 없다.',
    '사람과의 교류는 즐겁다.',
    '사회의 규칙과 가치관에 맞춰서 살고 있지 않다.',
    '자신의 인생에 있어서 소중한 사람이 정말로 아무도 없다.',
    '사람과 이야기하는 것을 피한다.',
    '누군가와 연락을 하는 일은 별로 없다. (말하기, 글쓰기 등)',
    '누군가와 함께 있는 것 보다 혼자 있는 것이 훨씬 좋다.',
    '자신이 안고 있는 문제에 대해서 안심하고 상담할 수 있는 사람이 있다.',
    '혼자서 시간을 보내는 것은 거의 없다.',
    '사람을 사귀는 것은 즐겁지 않다.',
    '사람과 교류하는 것이 거의 없다.',
    '혼자 있는 것 보다도 누군가와 함께 있는 편이 훨씬 좋다.',
  ];

  // null = 아직 응답하지 않음
  final List<int?> answers = List<int?>.filled(25, null);

  // 응답하지 않고 지나간 문항
  final Set<int> skippedQuestions = {};

  final List<String> answerLabels = const [
    '해당되지 않는다',
    '별로 해당되지 않는다',
    '어느 쪽도 아니다',
    '조금 해당된다',
    '해당된다',
  ];

  // HQ-25 역채점 문항
  static const Set<int> reverseScoredQuestions = {
    4,
    7,
    10,
    15,
    21,
    22,
    25,
  };

  // HQ-25 하위요인 문항
  static const Set<int> socializationQuestions = {
    1,
    4,
    6,
    8,
    11,
    15,
    18,
    20,
    23,
    25,
  };

  static const Set<int> isolationQuestions = {
    2,
    5,
    9,
    12,
    13,
    16,
    19,
    22,
    24,
  };

  static const Set<int> emotionalSupportQuestions = {
    3,
    7,
    10,
    14,
    17,
    21,
  };

  double get progress => (currentIndex + 1) / questions.length;

  int _getScoredAnswer(int questionNumber, int rawAnswer) {
    if (reverseScoredQuestions.contains(questionNumber)) {
      return 4 - rawAnswer;
    }

    return rawAnswer;
  }

  int _calculateTotalScore() {
    int totalScore = 0;

    for (int i = 0; i < answers.length; i++) {
      final rawAnswer = answers[i];

      if (rawAnswer == null) {
        continue;
      }

      final questionNumber = i + 1;

      totalScore += _getScoredAnswer(
        questionNumber,
        rawAnswer,
      );
    }

    return totalScore;
  }

  int _calculateSubscaleScore(Set<int> questionNumbers) {
    int score = 0;

    for (final questionNumber in questionNumbers) {
      final rawAnswer = answers[questionNumber - 1];

      if (rawAnswer == null) {
        continue;
      }

      score += _getScoredAnswer(
        questionNumber,
        rawAnswer,
      );
    }

    return score;
  }

  void _selectAnswer(int score) {
    setState(() {
      answers[currentIndex] = score;
      skippedQuestions.remove(currentIndex);
      showAnswerError = false;
    });
  }

  Future<void> _goNext() async {
    if (answers[currentIndex] == null) {
      setState(() {
        showAnswerError = true;
        skippedQuestions.add(currentIndex);
      });

      return;
    }

    // 13번 문항 완료 후 중간 안내
    if (currentIndex == 12 && !midpointShown) {
      midpointShown = true;

      await _showMidpointDialog();

      if (!mounted) return;
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        showAnswerError = false;
      });
    } else {
      await _finishAssessment();
    }
  }

  void _goPrevious() {
    if (currentIndex == 0) {
      return;
    }

    setState(() {
      currentIndex--;
      showAnswerError = false;
    });
  }

  Future<void> _showMidpointDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            30,
            24,
            24,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: primaryColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '절반 정도 완료했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '지금처럼 최근 6개월 동안의 모습을\n'
                '떠올리며 천천히 답해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '계속하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishAssessment() async {
  // 저장 버튼 중복 클릭 방지
  if (isSaving) {
    return;
  }

  final missingIndexes = <int>[];

  for (int i = 0; i < answers.length; i++) {
    if (answers[i] == null) {
      missingIndexes.add(i);
    }
  }

  // 미응답 문항이 있으면 완료하지 않음
  if (missingIndexes.isNotEmpty) {
    setState(() {
      skippedQuestions.addAll(missingIndexes);
      currentIndex = missingIndexes.first;
      showAnswerError = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '응답하지 않은 문항이 ${missingIndexes.length}개 있어요.',
        ),
      ),
    );

    return;
  }

  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '로그인 정보를 확인할 수 없습니다.',
        ),
      ),
    );

    return;
  }

  setState(() {
    isSaving = true;
  });

  String? createdAssessmentId;

  try {
    // ========================================================
    // 1. 이미 initial HQ-25 기록이 있는지 먼저 확인
    // ========================================================

    final existingAssessment =
        await Supabase.instance.client
            .from('hq25_assessments')
            .select(
              'id, total_score',
            )
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'assessment_type',
              'initial',
            )
            .limit(1)
            .maybeSingle();

    // ========================================================
    // 이미 초기검사가 있다면 새로 저장하지 않음
    // 기존 결과 화면으로 이동
    // ========================================================

    if (existingAssessment != null) {
      if (!mounted) {
        return;
      }

      final existingTotalScore =
          (existingAssessment['total_score'] as num).toInt();

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '이미 초기 상태 확인을 완료했어요. '
            '기존 결과를 보여드릴게요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Hq25ResultScreen(
            totalScore: existingTotalScore,
          ),
        ),
      );

      return;
    }

    // ========================================================
    // 2. 점수 계산
    // ========================================================

    final totalScore =
        _calculateTotalScore();

    final socializationScore =
        _calculateSubscaleScore(
      socializationQuestions,
    );

    final isolationScore =
        _calculateSubscaleScore(
      isolationQuestions,
    );

    final emotionalSupportScore =
        _calculateSubscaleScore(
      emotionalSupportQuestions,
    );

    // ========================================================
    // 3. 검사 전체 결과 저장
    // ========================================================

    final assessment =
        await Supabase.instance.client
            .from('hq25_assessments')
            .insert({
              'user_id':
                  user.id,

              'assessment_type':
                  'initial',

              'total_score':
                  totalScore,

              'socialization_score':
                  socializationScore,

              'isolation_score':
                  isolationScore,

              'emotional_support_score':
                  emotionalSupportScore,

              'scoring_version':
                  'hq25_ko_2022_v1',
            })
            .select('id')
            .single();

    createdAssessmentId =
        assessment['id'] as String;

    // ========================================================
    // 4. 25개 문항별 응답 저장
    // ========================================================

    final responseRows =
        List.generate(
      25,
      (index) {
        final questionNumber =
            index + 1;

        final rawAnswer =
            answers[index]!;

        return {
          'assessment_id':
              createdAssessmentId,

          'question_number':
              questionNumber,

          'raw_answer':
              rawAnswer,

          'scored_answer':
              _getScoredAnswer(
            questionNumber,
            rawAnswer,
          ),
        };
      },
    );

    await Supabase.instance.client
        .from('hq25_responses')
        .insert(responseRows);

    if (!mounted) {
      return;
    }

    setState(() {
      isSaving = false;
    });

    // ========================================================
    // 5. 저장 성공 후 결과 화면 이동
    // ========================================================

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Hq25ResultScreen(
          totalScore:
              totalScore,
        ),
      ),
    );
  } catch (error) {
    // ========================================================
    // 검사 전체 결과는 저장됐지만
    // 문항 저장 과정에서 오류가 발생한 경우
    // 생성했던 검사 기록까지 삭제
    // ========================================================

    if (createdAssessmentId != null) {
      try {
        await Supabase.instance.client
            .from('hq25_assessments')
            .delete()
            .eq(
              'id',
              createdAssessmentId,
            );
      } catch (_) {
        // 정리 과정 오류는 별도 처리하지 않음
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '검사 결과 저장 중 오류가 발생했습니다.\n$error',
        ),
      ),
    );
  }
}
  void _openQuestionNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              22,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Text(
                      '문항 바로가기',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '응답하지 않고 지나간 문항은 빨간색으로 표시돼요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: questions.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final bool isCurrent =
                        index == currentIndex;

                    final bool isAnswered =
                        answers[index] != null;

                    final bool isSkipped =
                        skippedQuestions.contains(index) &&
                        !isAnswered;

                    Color backgroundColor = Colors.white;
                    Color borderColor =
                        const Color(0xFFDDE3E1);
                    Color textColor = Colors.black87;

                    if (isAnswered) {
                      backgroundColor =
                          primaryColor.withValues(
                            alpha: 0.10,
                          );

                      borderColor = primaryColor;
                      textColor = primaryColor;
                    }

                    if (isSkipped) {
                      backgroundColor =
                          errorColor.withValues(
                            alpha: 0.07,
                          );

                      borderColor = errorColor;
                      textColor = errorColor;
                    }

                    if (isCurrent) {
                      borderColor = primaryColor;

                      backgroundColor =
                          primaryColor.withValues(
                            alpha: 0.16,
                          );

                      textColor = primaryColor;
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(
                          bottomSheetContext,
                        );

                        if (answers[currentIndex] == null &&
                            index != currentIndex) {
                          skippedQuestions.add(
                            currentIndex,
                          );
                        }

                        setState(() {
                          currentIndex = index;
                          showAnswerError = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: borderColor,
                            width: isCurrent ? 2 : 1.2,
                          ),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAnswer = answers[currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          onPressed: isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 21,
            color: Colors.black87,
          ),
        ),

        title: const Text(
          '초기 상태 확인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip: '문항 바로가기',
            onPressed:
                isSaving ? null : _openQuestionNavigator,
            icon: const Icon(
              Icons.grid_view_rounded,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  10,
                  24,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${currentIndex + 1}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),

                        Text(
                          ' / ${questions.length}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
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
                      borderRadius:
                          BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor:
                            const Color(0xFFE9EFED),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 34),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(100),
                      ),
                      child: const Text(
                        '최근 6개월을 기준으로 답해주세요',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Q${currentIndex + 1}.',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      questions[currentIndex],
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.45,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 38),

                    const Text(
                      '나의 상태와 가장 가까운 점수를 선택해주세요.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: List.generate(
                        5,
                        (score) {
                          final bool isSelected =
                              selectedAnswer == score;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left:
                                    score == 0 ? 0 : 5,
                                right:
                                    score == 4 ? 0 : 5,
                              ),
                              child: InkWell(
                                onTap: isSaving
                                    ? null
                                    : () =>
                                        _selectAnswer(
                                          score,
                                        ),
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(
                                    milliseconds: 160,
                                  ),
                                  height: 62,
                                  alignment:
                                      Alignment.center,
                                  decoration:
                                      BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(
                                      16,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : const Color(
                                              0xFFDDE3E1,
                                            ),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Text(
                                    '$score',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 180),
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: selectedAnswer == null
                            ? const Color(0xFFF6F8F8)
                            : primaryColor.withValues(
                                alpha: 0.08,
                              ),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Text(
                        selectedAnswer == null
                            ? '점수를 선택하면 의미가 여기에 표시돼요.'
                            : '$selectedAnswer · ${answerLabels[selectedAnswer]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selectedAnswer == null
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                          color:
                              selectedAnswer == null
                                  ? Colors.grey.shade500
                                  : primaryColor,
                        ),
                      ),
                    ),

                    if (showAnswerError) ...[
                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: errorColor.withValues(
                            alpha: 0.07,
                          ),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: errorColor,
                              size: 19,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '답변을 선택해주세요.',
                                style: TextStyle(
                                  color: errorColor,
                                  fontSize: 13.5,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: Colors.grey.shade500,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : _openQuestionNavigator,
                          child: const Text(
                            '문항 바로가기',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                18,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            currentIndex == 0 ||
                                    isSaving
                                ? null
                                : _goPrevious,
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.black87,
                          side: BorderSide(
                            color:
                                currentIndex == 0
                                    ? Colors
                                        .grey.shade200
                                    : const Color(
                                        0xFFD8DEDC,
                                      ),
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              17,
                            ),
                          ),
                        ),
                        child: const Text(
                          '이전',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
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
                        onPressed:
                            isSaving ? null : _goNext,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primaryColor,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              17,
                            ),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                currentIndex ==
                                        questions.length -
                                            1
                                    ? '검사 완료하기'
                                    : '다음',
                                style:
                                    const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w700,
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
}
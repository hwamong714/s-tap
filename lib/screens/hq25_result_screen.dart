import 'package:flutter/material.dart';

import 'life_status_screen.dart';

class Hq25ResultScreen extends StatelessWidget {
  final int totalScore;

  const Hq25ResultScreen({
    super.key,
    required this.totalScore,
  });

  static const Color primaryColor = Color(0xFF00A87E);
  static const Color darkColor = Color(0xFF171717);

  // 한국어판 HQ-25 연구에서 제안된 선별 기준
  static const int screeningCutoff = 41;

  bool get isAboveScreeningCutoff =>
      totalScore >= screeningCutoff;

  String get resultTitle {
    if (isAboveScreeningCutoff) {
      return '조금 더 살펴볼 필요가 있어요';
    }

    return '현재 상태를 확인했어요';
  }

  String get resultDescription {
    if (isAboveScreeningCutoff) {
      return '한국어판 HQ-25 연구에서 제안된 '
          '선별 기준인 41점 이상으로 나타났어요.\n\n'
          '이 결과만으로 은둔 상태를 진단할 수는 없어요. '
          '현재 생활과 관계에서 어떤 부분이 어렵고, '
          '어떤 변화부터 시작하고 싶은지 함께 살펴볼게요.';
    }

    return '한국어판 HQ-25 연구에서 제안된 '
        '선별 기준인 41점보다 낮게 나타났어요.\n\n'
        '점수가 기준보다 낮더라도 현재 느끼는 어려움이나 '
        '생활에서 바꾸고 싶은 부분이 있다면 '
        'S-TAP 활동을 통해 천천히 살펴볼 수 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FCFA),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FCFA),
        surfaceTintColor: const Color(0xFFF8FCFA),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '초기 상태 확인 결과',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            20,
            24,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  '검사를 완료했어요!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: darkColor,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  '지금의 상태를 이해하는 데 참고해볼게요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ======================================================
              // 점수 카드
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    24,
                  ),
                  border: Border.all(
                    color: const Color(
                      0xFFE4ECE9,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'HQ-25 총점',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalScore',
                          style: const TextStyle(
                            fontSize: 62,
                            height: 1,
                            fontWeight:
                                FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(width: 7),

                        const Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 7,
                          ),
                          child: Text(
                            '/ 100',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color:
                            primaryColor.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          100,
                        ),
                      ),
                      child: const Text(
                        '한국어판 연구의 선별 참고 기준 · 41점',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ======================================================
              // 결과 설명
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    22,
                  ),
                  border: Border.all(
                    color: const Color(
                      0xFFE4ECE9,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: primaryColor,
                            size: 23,
                          ),
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Text(
                            resultTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w800,
                              color: darkColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(
                      resultDescription,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.65,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ======================================================
              // 진단 아님 안내
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF1F5F4,
                  ),
                  borderRadius: BorderRadius.circular(
                    18,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 21,
                      color:
                          Colors.grey.shade700,
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Text(
                        'HQ-25 결과는 현재 상태를 이해하기 위한 '
                        '선별 참고자료예요. 이 점수만으로 '
                        '은둔 여부나 정신건강 상태를 진단하지 않아요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color:
                              Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ======================================================
              // 다음 단계 버튼
              // ======================================================

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LifeStatusScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryColor,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
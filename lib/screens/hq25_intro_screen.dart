import 'package:flutter/material.dart';
import 'hq25_screen.dart';

class Hq25IntroScreen extends StatelessWidget {
  const Hq25IntroScreen({super.key});

  static const Color primaryColor = Color(0xFF00A87E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 21,
          ),
        ),
        title: const Text(
          '초기 상태 확인',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: primaryColor,
                            size: 58,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        '지금의 상태를\n천천히 알아볼게요',
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'HQ-25 검사를 통해 최근 6개월 동안의 경험을 '
                        '돌아보고, S-TAP에서 어떤 활동부터 시작하면 좋을지 '
                        '함께\n' 
                        '알아볼 수 있어요.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 28),

                      _infoCard(
                        icon: Icons.format_list_numbered_rounded,
                        title: '총 25문항',
                        description: '각 문항에 0점부터 4점까지 응답해요.',
                      ),

                      const SizedBox(height: 12),

                      _infoCard(
                        icon: Icons.history_rounded,
                        title: '최근 6개월을 기준으로',
                        description: '하루가 아닌 최근 6개월의 상태를 떠올려 주세요.',
                      ),

                      const SizedBox(height: 12),

                      _infoCard(
                        icon: Icons.edit_note_rounded,
                        title: '정답은 없어요',
                        description: '지금 나와 가장 가까운 답을 선택해주세요.',
                      ),

                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.grey.shade700,
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '이 검사는 진단을 확정하기 위한 것이 아니라,\n '
                                '현재의 상태를 이해하고 나에게 맞는 활동을\n '
                                '찾는 데 활용돼요.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                 onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const Hq25Screen(),
    ),
  );
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '검사 시작하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8ECEB),
        ),
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
            child: Icon(
              icon,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
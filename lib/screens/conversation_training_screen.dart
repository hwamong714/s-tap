import 'package:flutter/material.dart';

import 'voice_conversation_screen.dart';

class ConversationTrainingScreen extends StatelessWidget {
  const ConversationTrainingScreen({super.key});

  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          '대화 훈련',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF151918),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '어떤 상황을 연습해볼까요?',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF151918),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '부담되지 않는 상황부터 천천히 시작해봐요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 26),

              // ==================================================
              // 카페
              // ==================================================
              _buildTrainingCard(
                context,
                icon: Icons.local_cafe_outlined,
                title: '카페',
                description: '직원에게 음료를 주문하는 상황을 연습해요.',
                difficultyLabel: '가볍게 시작하기',

                scenarioCode: 'cafe_order',
                scenarioTitle: '카페에서 주문하기',
                voiceDifficulty: '초급',
                roleName: '직원',
                firstAiMessage: '안녕하세요.\n주문 도와드릴까요?',
                totalGoalSteps: 3,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // 편의점
              // ==================================================
              _buildTrainingCard(
                context,
                icon: Icons.shopping_cart_outlined,
                title: '편의점',
                description: '물건을 구매하고 필요한 말을 해보는 연습이에요.',
                difficultyLabel: '가볍게 시작하기',

                scenarioCode: 'convenience_store',
                scenarioTitle: '편의점에서 구매하기',
                voiceDifficulty: '초급',
                roleName: '직원',
                firstAiMessage: '안녕하세요.\n필요하신 거 있으세요?',
                totalGoalSteps: 3,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // 병원
              // ==================================================
              _buildTrainingCard(
                context,
                icon: Icons.local_hospital_outlined,
                title: '병원',
                description: '접수하거나 필요한 내용을 설명하는 상황을 연습해요.',
                difficultyLabel: '조금 도전해보기',

                scenarioCode: 'hospital_reception',
                scenarioTitle: '병원에서 접수하기',
                voiceDifficulty: '초급',
                roleName: '접수 직원',
                firstAiMessage: '안녕하세요.\n어떤 일로 오셨을까요?',
                totalGoalSteps: 3,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // 지인과 대화
              // ==================================================
              _buildTrainingCard(
                context,
                icon: Icons.people_outline_rounded,
                title: '지인과 대화',
                description: '먼저 인사하고 간단한 대화를 이어가는 연습이에요.',
                difficultyLabel: '조금 도전해보기',

                scenarioCode: 'acquaintance_talk',
                scenarioTitle: '지인과 대화하기',
                voiceDifficulty: '초급',
                roleName: '지인',
                firstAiMessage: '안녕!\n오늘 하루는 어땠어?',
                totalGoalSteps: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 훈련 카드
  // ============================================================

  Widget _buildTrainingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String difficultyLabel,

    required String scenarioCode,
    required String scenarioTitle,
    required String voiceDifficulty,
    required String roleName,
    required String firstAiMessage,
    required int totalGoalSteps,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceConversationScreen(
              scenarioCode: scenarioCode,
              scenarioTitle: scenarioTitle,
              difficulty: voiceDifficulty,
              roleName: roleName,
              firstAiMessage: firstAiMessage,
              totalGoalSteps: totalGoalSteps,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4E9E7)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 29, color: primaryColor),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF151918),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF707572),
                    ),
                  ),

                  const SizedBox(height: 9),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      difficultyLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
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
}

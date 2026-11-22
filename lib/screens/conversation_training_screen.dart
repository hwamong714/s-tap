
import 'package:flutter/material.dart';

import 'ai_conversation_screen.dart';

class ConversationTrainingScreen extends StatelessWidget {
  const ConversationTrainingScreen({super.key});

  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color textColor = Color(0xFF151918);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'AI와 대화하기',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20, 12, 20, 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘은 어떤 이야기를\n나누고 싶나요?',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                '정해진 답은 없어요. 마음이 가는 주제부터\n'
                '편안하게 이야기해 보세요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 26),

              _buildConversationCard(
                context,
                domainCode: 'daily',
                icon: Icons.wb_sunny_outlined,
                title: '일상 대화',
                description:
                    '오늘 하루, 요즘 기분, 작은 고민을\n'
                    '자유롭게 이야기해요.',
                example: '예: 오늘 있었던 일, 요즘 드는 생각',
              ),

              const SizedBox(height: 14),

              _buildConversationCard(
                context,
                domainCode: 'career',
                icon: Icons.auto_stories_outlined,
                title: '진로 대화',
                description:
                    '공부, 일, 앞으로의 방향에 대한\n'
                    '생각을 함께 정리해요.',
                example: '예: 하고 싶은 일, 미래에 대한 고민',
              ),

              const SizedBox(height: 14),

              _buildConversationCard(
                context,
                domainCode: 'hobby',
                icon: Icons.palette_outlined,
                title: '취미 대화',
                description:
                    '좋아하는 것과 관심 있는 활동을\n'
                    '부담 없이 이야기해요.',
                example: '예: 음악, 게임, 운동, 새로운 취미',
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(
                    alpha: 0.07,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      color: primaryColor,
                      size: 21,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        '대화를 잘해야 할 필요는 없어요.\n'
                        '내 속도에 맞춰 편하게 이야기해요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: Color(0xFF347B68),
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ============================================================
  // 대화 주제 카드
  // ============================================================

  Widget _buildConversationCard(
    BuildContext context, {
    required String domainCode,
    required IconData icon,
    required String title,
    required String description,
    required String example,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiConversationScreen(
                domainCode: domainCode,
                domainTitle: title,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE4E9E7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  size: 27,
                  color: primaryColor,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Color(0xFF707572),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      example,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF347B68),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Padding(
                padding: EdgeInsets.only(top: 15),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

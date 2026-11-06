import 'package:flutter/material.dart';

import '../services/conversation_feedback_service.dart';

class ConversationFeedbackScreen extends StatefulWidget {
  final String scenarioCode;
  final String scenarioTitle;
  final String difficulty;

  final List<Map<String, dynamic>> messages;

  const ConversationFeedbackScreen({
    super.key,
    required this.scenarioCode,
    required this.scenarioTitle,
    required this.difficulty,
    required this.messages,
  });

  @override
  State<ConversationFeedbackScreen> createState() =>
      _ConversationFeedbackScreenState();
}

class _ConversationFeedbackScreenState
    extends State<ConversationFeedbackScreen> {
  static const Color primaryColor = Color(0xFF00A87E);

  static const Color backgroundColor = Color(0xFFF7FFFC);

  bool _isLoading = true;

  String? _errorMessage;

  ConversationFeedbackResult? _feedback;

  @override
  void initState() {
    super.initState();

    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ConversationFeedbackService.getFeedback(
        scenarioCode: widget.scenarioCode,
        scenarioTitle: widget.scenarioTitle,
        difficulty: widget.difficulty,
        messages: widget.messages,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _feedback = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '피드백을 불러오지 못했어요.\n잠시 후 다시 시도해주세요.';

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '훈련 피드백',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 18),
            Text(
              '대화를 살펴보고 있어요...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '잠시만 기다려주세요.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.black45,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadFeedback,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final feedback = _feedback;

    if (feedback == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          const SizedBox(height: 24),

          _buildFeedbackCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: '잘 이어간 점',
            text: feedback.strength,
          ),

          const SizedBox(height: 14),

          _buildFeedbackCard(
            icon: Icons.lightbulb_outline_rounded,
            title: '다음에 시도해볼 점',
            text: feedback.nextTry,
          ),

          const SizedBox(height: 14),

          _buildFeedbackCard(
            icon: Icons.directions_walk_rounded,
            title: '실제 상황에서의 작은 행동',
            text: feedback.realWorldAction,
          ),

          const SizedBox(height: 26),

          const Text(
            '이 피드백은 대화를 채점하기 위한 것이 아니라 '
            '다음 사회적 상황을 조금 더 편하게 경험할 수 있도록 돕기 위한 안내예요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.scenarioTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '이번 리허설을 함께 돌아봤어요.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: Colors.black87,
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

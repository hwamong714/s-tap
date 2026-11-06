import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/conversation_ai_service.dart';
import 'conversation_feedback_screen.dart';

enum VoiceConversationState {
  aiSpeaking,
  waitingForUser,
  userSpeaking,
  sttResult,
  aiThinking,
  completed,
}

class VoiceConversationScreen extends StatefulWidget {
  final String scenarioCode;
  final String scenarioTitle;
  final String difficulty;
  final String roleName;
  final String firstAiMessage;
  final int totalGoalSteps;

  const VoiceConversationScreen({
    super.key,
    this.scenarioCode = 'cafe_order',
    this.scenarioTitle = '카페에서 주문하기',
    this.difficulty = '초급',
    this.roleName = '직원',
    this.firstAiMessage = '안녕하세요.\n주문 도와드릴까요?',
    this.totalGoalSteps = 3,
  });

  @override
  State<VoiceConversationScreen> createState() =>
      _VoiceConversationScreenState();
}

class _VoiceConversationScreenState extends State<VoiceConversationScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF7FFFC);
  static const Color darkColor = Color(0xFF17201D);

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceConversationState _state = VoiceConversationState.aiSpeaking;

  bool _speechAvailable = false;
  bool _isInitializing = true;
  bool _isRecordSaved = false;

  String? _koreanLocaleId;

  String _recognizedText = '';
  String _currentAiMessage = '';

  int _goalStep = 1;

  final List<ConversationMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _currentAiMessage = widget.firstAiMessage;

    _initializeVoiceTraining();
  }

  String? get _backgroundAsset {
    switch (widget.scenarioCode) {
      case 'cafe_order':
        return 'assets/conversation/backgrounds/cafe_bg.png';

      case 'acquaintance_talk':
        return 'assets/conversation/backgrounds/acquaintance_bg.png';

      default:
        return null;
    }
  }

  String? get _characterAsset {
    switch (widget.scenarioCode) {
      case 'cafe_order':
        return 'assets/conversation/characters/cafe_staff.png';

      case 'acquaintance_talk':
        return 'assets/conversation/characters/acquaintance_female.png';

      default:
        return null;
    }
  }

  Future<void> _initializeVoiceTraining() async {
    await _initializeSpeechToText();
    await _initializeTts();

    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
    });

    _messages.add(
      ConversationMessage(
        speaker: widget.roleName,
        text: widget.firstAiMessage,
        isUser: false,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) {
      return;
    }

    await _speakAiMessage(widget.firstAiMessage);
  }

  Future<void> _initializeSpeechToText() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      String? localeId;

      if (available) {
        final locales = await _speech.locales();

        for (final locale in locales) {
          final id = locale.localeId.toLowerCase();

          if (id.startsWith('ko')) {
            localeId = locale.localeId;

            break;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _speechAvailable = available;

        _koreanLocaleId = localeId;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _speechAvailable = false;
      });
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('ko-KR');

      await _tts.setSpeechRate(0.46);

      await _tts.setPitch(1.0);

      await _tts.awaitSpeakCompletion(true);

      final voices = await _tts.getVoices;

      debugPrint('========================================');

      debugPrint('S-TAP 한국어 TTS 음성 목록');

      debugPrint('========================================');

      if (voices is List) {
        for (final voice in voices) {
          if (voice is Map) {
            final locale = voice['locale']?.toString() ?? '';

            if (locale.toLowerCase().startsWith('ko')) {
              debugPrint(
                'VOICE → '
                'name: ${voice['name']} / '
                'locale: ${voice['locale']}',
              );
            }
          }
        }
      }

      debugPrint('========================================');
    } catch (error) {
      debugPrint('TTS 초기화 오류: $error');
    }
  }

  Future<void> _speakAiMessage(
    String message, {
    bool completeAfterSpeaking = false,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _state = VoiceConversationState.aiSpeaking;

      _currentAiMessage = message;
    });

    try {
      await _tts.stop();

      await _tts.speak(message.replaceAll('\n', ' '));
    } catch (_) {}

    if (!mounted) {
      return;
    }

    if (completeAfterSpeaking) {
      await _saveTrainingRecord();

      if (!mounted) {
        return;
      }

      setState(() {
        _state = VoiceConversationState.completed;
      });

      return;
    }

    setState(() {
      _state = VoiceConversationState.waitingForUser;
    });
  }

  Future<void> _saveTrainingRecord() async {
    if (_isRecordSaved) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint(
        '대화 훈련 기록 저장 실패: '
        '로그인된 사용자가 없습니다.',
      );

      return;
    }

    try {
      final userTurnCount = _messages.where((message) {
        return message.isUser;
      }).length;

      await Supabase.instance.client
          .from('conversation_training_records')
          .insert({
            'user_id': user.id,

            'scenario_code': widget.scenarioCode,

            'scenario_title': widget.scenarioTitle,

            'difficulty': widget.difficulty,

            'role_name': widget.roleName,

            'turn_count': userTurnCount,

            'completed_at': DateTime.now().toUtc().toIso8601String(),
          });

      _isRecordSaved = true;

      debugPrint(
        '대화 훈련 기록 저장 완료: '
        '${widget.scenarioCode}',
      );
    } catch (error) {
      debugPrint(
        '대화 훈련 기록 저장 실패: '
        '$error',
      );
    }
  }

  Future<void> _startListening() async {
    if (_state != VoiceConversationState.waitingForUser) {
      return;
    }

    if (!_speechAvailable) {
      _showMessage(
        '음성 인식을 사용할 수 없습니다.\n'
        '마이크 권한 또는 음성 인식 서비스를 확인해주세요.',
      );

      return;
    }

    await _tts.stop();

    setState(() {
      _recognizedText = '';

      _state = VoiceConversationState.userSpeaking;
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,

        listenOptions: stt.SpeechListenOptions(
          localeId: _koreanLocaleId,

          listenFor: const Duration(seconds: 40),

          pauseFor: const Duration(seconds: 3),

          partialResults: true,
          cancelOnError: true,

          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _state = VoiceConversationState.waitingForUser;
      });

      _showMessage('음성 인식을 시작하지 못했습니다.');
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    if (_recognizedText.trim().isEmpty) {
      setState(() {
        _state = VoiceConversationState.waitingForUser;
      });

      _showMessage('음성을 인식하지 못했어요. 다시 말해볼까요?');

      return;
    }

    setState(() {
      _state = VoiceConversationState.sttResult;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    setState(() {
      _recognizedText = result.recognizedWords.trim();
    });

    if (result.finalResult && _recognizedText.isNotEmpty) {
      setState(() {
        _state = VoiceConversationState.sttResult;
      });
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    if (_state != VoiceConversationState.userSpeaking) {
      return;
    }

    if (status == 'done' || status == 'notListening') {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) {
          return;
        }

        if (_state != VoiceConversationState.userSpeaking) {
          return;
        }

        if (_recognizedText.trim().isEmpty) {
          setState(() {
            _state = VoiceConversationState.waitingForUser;
          });
        } else {
          setState(() {
            _state = VoiceConversationState.sttResult;
          });
        }
      });
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }

    if (_state == VoiceConversationState.userSpeaking) {
      setState(() {
        _state = VoiceConversationState.waitingForUser;
      });
    }

    if (error.permanent) {
      _showMessage('마이크 또는 음성 인식 서비스를 확인해주세요.');
    }
  }

  Future<void> _retrySpeaking() async {
    try {
      await _speech.cancel();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _recognizedText = '';

      _state = VoiceConversationState.waitingForUser;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) {
      return;
    }

    await _startListening();
  }

  List<Map<String, dynamic>> _buildAiHistory() {
    const maxHistoryMessages = 10;

    final startIndex = _messages.length > maxHistoryMessages
        ? _messages.length - maxHistoryMessages
        : 0;

    final recentMessages = _messages.sublist(startIndex);

    return recentMessages.map((message) {
      return {'isUser': message.isUser, 'text': message.text};
    }).toList();
  }

  Future<void> _sendRecognizedText() async {
    final userText = _recognizedText.trim();

    if (userText.isEmpty) {
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {}

    final history = _buildAiHistory();

    setState(() {
      _state = VoiceConversationState.aiThinking;
    });

    try {
      final aiResult = await ConversationAiService.getReply(
        scenarioCode: widget.scenarioCode,

        scenarioTitle: widget.scenarioTitle,

        difficulty: widget.difficulty,

        roleName: widget.roleName,

        goalStep: _goalStep,

        totalGoalSteps: widget.totalGoalSteps,

        userMessage: userText,

        history: history,
      );

      if (!mounted) {
        return;
      }

      final aiReply = aiResult.reply;

      final shouldComplete = aiResult.shouldComplete;

      final nextGoalStep = aiResult.goalStep;

      _messages.add(
        ConversationMessage(speaker: '나', text: userText, isUser: true),
      );

      _messages.add(
        ConversationMessage(
          speaker: widget.roleName,

          text: aiReply,

          isUser: false,
        ),
      );

      setState(() {
        _goalStep = nextGoalStep;

        _recognizedText = '';

        _currentAiMessage = aiReply;
      });

      debugPrint(
        '현재 S-TAP 목표 단계: '
        '$_goalStep / '
        '${widget.totalGoalSteps}',
      );

      debugPrint(
        '현재 S-TAP 종료 판단: '
        '$shouldComplete',
      );

      await _speakAiMessage(aiReply, completeAfterSpeaking: shouldComplete);
    } catch (error) {
      debugPrint('AI 대화 요청 실패: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _state = VoiceConversationState.sttResult;
      });

      _showMessage(
        'AI 응답을 불러오지 못했어요.\n'
        '잠시 후 다시 시도해주세요.',
      );
    }
  }

  void _openFeedback() {
    final feedbackMessages = _messages.map((message) {
      return {'isUser': message.isUser, 'text': message.text};
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConversationFeedbackScreen(
          scenarioCode: widget.scenarioCode,

          scenarioTitle: widget.scenarioTitle,

          difficulty: widget.difficulty,

          messages: feedbackMessages,
        ),
      ),
    );
  }

  void _finishTraining() {
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleBack() async {
    try {
      await _speech.cancel();
    } catch (_) {}

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: backgroundColor,

        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_state == VoiceConversationState.completed) {
      return _buildCompletedScreen();
    }

    return Scaffold(
      backgroundColor: backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            _buildProgress(),

            Expanded(child: _buildConversationArea()),

            _buildBottomControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),

      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,

            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),

          Expanded(
            child: Text(
              '${widget.scenarioTitle} · '
              '${widget.difficulty}',

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 15,

                fontWeight: FontWeight.w800,

                color: darkColor,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            '$_goalStep / '
            '${widget.totalGoalSteps}',

            style: const TextStyle(
              fontSize: 14,

              fontWeight: FontWeight.w800,

              color: Color(0xFF49534F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final progress = _goalStep / widget.totalGoalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),

        child: LinearProgressIndicator(
          value: progress,

          minHeight: 3,

          backgroundColor: const Color(0xFFE1ECE8),

          valueColor: const AlwaysStoppedAnimation(primaryColor),
        ),
      ),
    );
  }

  Widget _buildConversationArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),

          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),

            child: Column(
              children: [
                _buildCharacterArea(),

                const SizedBox(height: 14),

                if (_state == VoiceConversationState.aiSpeaking ||
                    _state == VoiceConversationState.waitingForUser)
                  _buildAiMessageCard(),

                if (_state == VoiceConversationState.userSpeaking)
                  _buildSpeakingArea(),

                if (_state == VoiceConversationState.sttResult)
                  _buildSttResultArea(),

                if (_state == VoiceConversationState.aiThinking)
                  _buildThinkingArea(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacterArea() {
    final aiSpeaking = _state == VoiceConversationState.aiSpeaking;

    final backgroundAsset = _backgroundAsset;

    final characterAsset = _characterAsset;

    if (backgroundAsset == null || characterAsset == null) {
      return Container(
        width: double.infinity,

        height: 285,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),

          gradient: const LinearGradient(
            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

            colors: [Color(0xFFE4F4EE), Color(0xFFCCE8DF)],
          ),
        ),

        child: Stack(
          alignment: Alignment.center,

          children: [
            Container(
              width: 175,
              height: 175,

              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.person_rounded,

                size: 122,

                color: Color(0xFF8BC9B7),
              ),
            ),

            if (aiSpeaking)
              Positioned(
                left: 30,
                right: 30,
                top: 130,

                child: _buildVoiceWave(color: primaryColor),
              ),

            Positioned(left: 18, bottom: 16, child: _buildRoleBadge()),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),

      child: SizedBox(
        width: double.infinity,

        height: 315,

        child: Stack(
          fit: StackFit.expand,

          children: [
            Image.asset(
              backgroundAsset,

              fit: BoxFit.cover,

              alignment: Alignment.center,
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,

                  end: Alignment.bottomCenter,

                  colors: [
                    Colors.white.withValues(alpha: 0.02),

                    Colors.transparent,

                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 28,
              right: 10,
              bottom: -8,

              child: Image.asset(
                characterAsset,

                height: 285,

                fit: BoxFit.contain,

                alignment: Alignment.bottomCenter,
              ),
            ),

            if (aiSpeaking)
              Positioned(
                left: 26,
                right: 26,
                top: 150,

                child: _buildVoiceWave(color: Colors.white),
              ),

            Positioned(left: 16, bottom: 14, child: _buildRoleBadge()),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),

      decoration: BoxDecoration(
        color: const Color(0xFFD7FFF2),

        borderRadius: BorderRadius.circular(100),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),

            blurRadius: 8,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Text(
        widget.roleName,

        style: const TextStyle(
          fontSize: 12.5,

          fontWeight: FontWeight.w900,

          color: Color(0xFF087D60),
        ),
      ),
    );
  }

  Widget _buildVoiceWave({required Color color}) {
    const heights = [
      12.0,
      20.0,
      34.0,
      22.0,
      42.0,
      27.0,
      17.0,
      37.0,
      24.0,
      31.0,
      16.0,
      40.0,
      25.0,
      34.0,
      18.0,
      28.0,
      14.0,
      22.0,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: List.generate(heights.length, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),

            height: heights[index],

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.92),

              borderRadius: BorderRadius.circular(100),

              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.22),

                  blurRadius: 5,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAiMessageCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),

            blurRadius: 16,

            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Text(
        _currentAiMessage,

        style: const TextStyle(
          fontSize: 17,

          height: 1.5,

          fontWeight: FontWeight.w700,

          color: darkColor,
        ),
      ),
    );
  }

  Widget _buildSpeakingArea() {
    return Column(
      children: [
        const SizedBox(height: 6),

        const Text(
          '말씀해주세요...',

          style: TextStyle(
            fontSize: 19,

            fontWeight: FontWeight.w800,

            color: darkColor,
          ),
        ),

        const SizedBox(height: 24),

        Container(
          width: 138,
          height: 138,

          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),

            shape: BoxShape.circle,
          ),

          child: Center(
            child: Container(
              width: 98,
              height: 98,

              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.20),

                shape: BoxShape.circle,
              ),

              child: Center(
                child: Container(
                  width: 72,
                  height: 72,

                  decoration: const BoxDecoration(
                    color: primaryColor,

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.mic_rounded,

                    color: Colors.white,

                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (_recognizedText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Text(
              _recognizedText,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 14,

                height: 1.5,

                color: Color(0xFF6B7571),
              ),
            ),
          ),

        const SizedBox(height: 22),

        OutlinedButton.icon(
          onPressed: _stopListening,

          icon: const Icon(Icons.close_rounded),

          label: const Text('말하기 종료'),

          style: OutlinedButton.styleFrom(
            foregroundColor: darkColor,

            side: const BorderSide(color: Color(0xFFDDE6E2)),

            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildSttResultArea() {
    return Column(
      children: [
        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(19),

          decoration: BoxDecoration(
            color: const Color(0xFFE9FBF5),

            borderRadius: BorderRadius.circular(21),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                '내가 말한 내용',

                style: TextStyle(
                  fontSize: 13,

                  fontWeight: FontWeight.w900,

                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                _recognizedText,

                style: const TextStyle(
                  fontSize: 16,

                  height: 1.5,

                  fontWeight: FontWeight.w700,

                  color: darkColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retrySpeaking,

                icon: const Icon(Icons.refresh_rounded, size: 20),

                label: const Text('다시 말하기'),

                style: OutlinedButton.styleFrom(
                  foregroundColor: darkColor,

                  side: const BorderSide(color: Color(0xFFDDE6E2)),

                  padding: const EdgeInsets.symmetric(vertical: 15),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: FilledButton.icon(
                onPressed: _sendRecognizedText,

                icon: const Icon(Icons.arrow_forward_rounded, size: 20),

                label: const Text('확인하고 보내기'),

                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 15),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThinkingArea() {
    return Column(
      children: [
        const SizedBox(height: 28),

        Container(
          width: 110,
          height: 88,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(50),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),

                blurRadius: 14,
              ),
            ],
          ),

          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                ThinkingDot(delay: 0),

                SizedBox(width: 7),

                ThinkingDot(delay: 150),

                SizedBox(width: 7),

                ThinkingDot(delay: 300),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          '답변을 생각하고 있어요...',

          style: TextStyle(
            fontSize: 16,

            fontWeight: FontWeight.w700,

            color: Color(0xFF59635F),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControl() {
    if (_state == VoiceConversationState.userSpeaking) {
      return const SizedBox.shrink();
    }

    if (_state == VoiceConversationState.sttResult ||
        _state == VoiceConversationState.aiThinking) {
      return const SizedBox(height: 22);
    }

    final aiSpeaking = _state == VoiceConversationState.aiSpeaking;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),

      child: Column(
        children: [
          GestureDetector(
            onTap: aiSpeaking ? null : _startListening,

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),

              width: 72,
              height: 72,

              decoration: BoxDecoration(
                color: aiSpeaking ? const Color(0xFFAFC2BC) : primaryColor,

                shape: BoxShape.circle,

                boxShadow: aiSpeaking
                    ? []
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),

                          blurRadius: 22,

                          spreadRadius: 3,
                        ),
                      ],
              ),

              child: const Icon(
                Icons.mic_rounded,

                size: 34,

                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            aiSpeaking ? '잠시 들어주세요...' : '이제 편하게 말씀해보세요',

            style: const TextStyle(
              fontSize: 14,

              fontWeight: FontWeight.w700,

              color: Color(0xFF65706C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen() {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 105,
                height: 105,

                decoration: const BoxDecoration(
                  color: primaryColor,

                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.check_rounded,

                  size: 58,

                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                '훈련이 완료되었어요!',

                style: TextStyle(
                  fontSize: 25,

                  fontWeight: FontWeight.w900,

                  color: darkColor,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '${widget.scenarioTitle}\n'
                '수고했어요!',

                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 15,

                  height: 1.55,

                  color: Color(0xFF67726E),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,

                height: 55,

                child: FilledButton(
                  onPressed: _openFeedback,

                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),

                  child: const Text(
                    '피드백 보기',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,

                height: 55,

                child: OutlinedButton(
                  onPressed: _finishTraining,

                  style: OutlinedButton.styleFrom(
                    foregroundColor: darkColor,

                    side: const BorderSide(color: Color(0xFFD5E6E0)),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),

                  child: const Text(
                    '돌아가기',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.cancel();

    _tts.stop();

    super.dispose();
  }
}

class ConversationMessage {
  final String speaker;
  final String text;
  final bool isUser;

  const ConversationMessage({
    required this.speaker,
    required this.text,
    required this.isUser,
  });
}

class ThinkingDot extends StatefulWidget {
  final int delay;

  const ThinkingDot({super.key, required this.delay});

  @override
  State<ThinkingDot> createState() => _ThinkingDotState();
}

class _ThinkingDotState extends State<ThinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 700),
    );

    _animation = Tween<double>(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (!mounted) {
        return;
      }

      _controller.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,

      child: Container(
        width: 10,
        height: 10,

        decoration: const BoxDecoration(
          color: Color(0xFF98AAA4),

          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}

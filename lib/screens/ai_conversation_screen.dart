import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/conversation_ai_service.dart';
import '../services/ai_conversation_storage_service.dart';

// ============================================================
// S-TAP AI 자유 대화 화면
// - 일상 / 진로 / 취미 자유 대화
// - STT 음성 인식
// - Gemini AI 응답
// - TTS 음성 출력
// - 대화 기록 저장 및 이어하기
// - 새 대화 시작 및 기록 삭제
// ============================================================

class AiConversationScreen extends StatefulWidget {
  final String domainCode;
  final String domainTitle;

  const AiConversationScreen({
    super.key,
    required this.domainCode,
    required this.domainTitle,
  });

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

// ============================================================
// 채팅 메시지 모델
// ============================================================

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

// ============================================================
// 화면 상태
// ============================================================

class _AiConversationScreenState extends State<AiConversationScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final TextEditingController _inputController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isWaiting = false;
  bool _isSpeaking = false;
  bool _autoSending = false;

  // 대화 선택 화면 표시 여부
  bool _isChoosingConversation = true;

  // 대화 원문 저장 동의 여부
  bool _historySavingEnabled = false;

  // 현재 대화 세션
  String? _sessionId;

  // 한국어 음성 인식 언어
  String? _koreanLocaleId;

  // STT/TTS 초기화
  late final Future<void> _voiceInitFuture;

  // 기존 ConversationAiService와 호환
  int _legacyGoalStep = 1;
  static const int _legacyTotalSteps = 100000;

  // ============================================================
  // 대화 영역별 첫 인사
  // ============================================================

  String get _openingMessage {
    switch (widget.domainCode) {
      case 'daily':
        return '안녕! 오늘은 어떤 하루를 보냈어? '
            '특별한 일이 없어도 괜찮아. '
            '편하게 이야기해 줘.';

      case 'career':
        return '안녕! 오늘은 진로나 앞으로의 방향에 '
            '대해 이야기해 볼까? '
            '요즘 관심 있는 일이나 고민이 있어?';

      case 'hobby':
        return '안녕! 요즘 좋아하거나 관심 있는 게 있어? '
            '음악이나 게임, 운동처럼 '
            '어떤 이야기든 좋아!';

      default:
        return '안녕! 만나서 반가워. '
            '오늘은 어떤 이야기를 나누고 싶어?';
    }
  }

  // ============================================================
  // 화면 초기화
  // ============================================================

  @override
  void initState() {
    super.initState();

    _messages.add(_ChatMessage(text: _openingMessage, isUser: false));

    _voiceInitFuture = _initializeVoice();

    // 첫 진입 시 기존 대화 / 새 대화 선택
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_chooseConversation(initial: true));
      }
    });
  }

  // ============================================================
  // 대화 원문 저장 동의
  // ============================================================

  Future<bool?> _askHistoryConsent() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('대화 내용을 저장할까요?'),
            content: const SingleChildScrollView(
              child: Text(
                '대화 저장에 동의하면 대화 내용이 '
                '내 계정의 Supabase에 보관됩니다.\n\n'
                '나중에 이전 대화를 이어서 이야기하거나 '
                '직접 기록을 삭제할 수 있어요.\n\n'
                '저장하지 않아도 AI와 자유롭게 대화할 수 있습니다. '
                '다만 화면을 나가면 해당 대화는 사라집니다.\n\n'
                '어느 방식을 선택하더라도 AI 응답을 생성하기 위해 '
                '메시지는 Google Gemini API에 전송됩니다.\n\n'
                '대화에 참여한 날짜는 원문 저장 여부와 '
                '관계없이 기록됩니다.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('기록 없이 시작'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('동의하고 저장'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 새로운 대화 시작
  // ============================================================

  Future<void> _startNewConversation() async {
    final saveHistory = await _askHistoryConsent();

    if (!mounted) return;

    if (saveHistory == null) {
      await _chooseConversation(initial: true);
      return;
    }

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _historySavingEnabled = saveHistory;
      _sessionId = null;
      _legacyGoalStep = 1;

      _messages
        ..clear()
        ..add(_ChatMessage(text: _openingMessage, isUser: false));

      _inputController.clear();

      _isChoosingConversation = false;
      _isListening = false;
      _isSpeaking = false;
    });

    _scrollToBottom();

    await _voiceInitFuture;

    if (mounted) {
      unawaited(_speakAiMessage(_openingMessage));
    }
  }

  // ============================================================
  // 이전 대화 이어하기
  // ============================================================

  Future<void> _resumeConversation(String sessionId) async {
    try {
      final rows = await AiConversationStorageService.getMessages(sessionId);

      if (!mounted) return;

      setState(() {
        _sessionId = sessionId;
        _historySavingEnabled = true;
        _legacyGoalStep = 1;

        _messages.clear();

        if (rows.isEmpty) {
          _messages.add(_ChatMessage(text: _openingMessage, isUser: false));
        } else {
          _messages.addAll(
            rows.map(
              (row) => _ChatMessage(
                text: (row['content'] ?? '').toString(),
                isUser: row['role'] == 'user',
              ),
            ),
          );
        }

        _inputController.clear();
        _isChoosingConversation = false;
        _isListening = false;
      });

      _scrollToBottom();
    } catch (error) {
      debugPrint('대화 불러오기 오류: $error');

      if (!mounted) return;

      _showMessage('대화 기록을 불러오지 못했어요.');

      // 불러오기 실패 시 이전 대화를 임의로 덮어쓰지 않음
      await _chooseConversation(initial: true);
    }
  }

  // ============================================================
  // 삭제 확인창
  // ============================================================

  Future<bool> _confirmDeleteConversation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('이 대화를 삭제할까요?'),
          content: const Text(
            '저장된 대화 내용은 삭제되며 '
            '복구할 수 없어요.\n\n'
            '대화에 참여한 날짜 기록은 '
            '별도로 유지됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ============================================================
  // 대화 선택
  //
  // 새 대화 시작 / 이전 대화 이어하기 / 삭제
  // ============================================================

  Future<void> _chooseConversation({bool initial = false}) async {
    if (_isWaiting || _isListening) return;

    if (!initial && _messages.any((message) => message.isUser)) {
      final switchConfirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('다른 대화로 이동할까요?'),
            content: const Text(
              '저장하지 않은 대화 내용은 '
              '다른 대화로 이동하면 사라질 수 있어요.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('계속 대화하기'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('대화 선택'),
              ),
            ],
          );
        },
      );

      if (!mounted || switchConfirmed != true) {
        return;
      }
    }

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isChoosingConversation = true;
      _isSpeaking = false;
    });

    List<Map<String, dynamic>> sessions = [];

    try {
      sessions = await AiConversationStorageService.getSessions(
        widget.domainCode,
      );
    } catch (error) {
      debugPrint('대화 목록 조회 오류: $error');

      if (mounted) {
        _showMessage('저장된 대화 목록을 불러오지 못했어요.');
      }
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.65,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'AI 대화 기록',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${widget.domainTitle} · 저장한 대화'),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: primaryColor,
                  ),
                  title: const Text('새로운 대화 시작하기'),
                  subtitle: const Text('대화 기록 저장 여부를 선택할 수 있어요'),
                  onTap: () {
                    Navigator.pop(sheetContext, '__new__');
                  },
                ),

                const Divider(),

                Expanded(
                  child: sessions.isEmpty
                      ? const Center(child: Text('저장된 대화가 아직 없어요.'))
                      : ListView.builder(
                          itemCount: sessions.length,
                          itemBuilder: (itemContext, index) {
                            final session = sessions[index];

                            final id = session['id'].toString();

                            final title = (session['title'] ?? '지난 대화')
                                .toString();

                            final lastAt = DateTime.tryParse(
                              (session['last_message_at'] ?? '').toString(),
                            );

                            String dateText = '';

                            if (lastAt != null) {
                              final local = lastAt.toLocal();

                              dateText =
                                  '${local.year}.'
                                  '${local.month}.'
                                  '${local.day}';
                            }

                            return ListTile(
                              leading: const Icon(Icons.chat_bubble_outline),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(dateText),

                              // 대화 이어하기
                              onTap: () {
                                Navigator.pop(sheetContext, id);
                              },

                              // 대화 삭제
                              trailing: IconButton(
                                tooltip: '대화 삭제',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirmed =
                                      await _confirmDeleteConversation();

                                  if (!confirmed) return;

                                  try {
                                    await AiConversationStorageService.deleteSession(
                                      id,
                                    );

                                    if (!mounted) return;

                                    if (_sessionId == id) {
                                      _sessionId = null;
                                      _historySavingEnabled = false;
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.pop(
                                        sheetContext,
                                        '__refresh__',
                                      );
                                    }
                                  } catch (error) {
                                    debugPrint('대화 삭제 오류: $error');

                                    if (mounted) {
                                      _showMessage('대화를 삭제하지 못했어요.');
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    // 삭제 후 목록 새로고침
    if (selected == '__refresh__') {
      await _chooseConversation(initial: true);
      return;
    }

    // 새 대화 선택
    if (selected == '__new__' || (selected == null && initial)) {
      await _startNewConversation();
      return;
    }

    // 선택 취소
    if (selected == null) {
      setState(() {
        _isChoosingConversation = false;
      });
      return;
    }

    // 이전 대화 이어하기
    await _resumeConversation(selected);
  }

  // ============================================================
  // STT 및 TTS 초기화
  // ============================================================

  Future<void> _initializeVoice() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      String? koreanLocale;

      if (available) {
        final locales = await _speech.locales();

        for (final locale in locales) {
          if (locale.localeId.toLowerCase().startsWith('ko')) {
            koreanLocale = locale.localeId;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _speechAvailable = available;
          _koreanLocaleId = koreanLocale;
        });
      }
    } catch (error) {
      debugPrint('STT 초기화 오류: $error');
    }

    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (error) {
      debugPrint('TTS 초기화 오류: $error');
    }
  }

  // ============================================================
  // AI 음성 출력
  // ============================================================

  Future<void> _speakAiMessage(String text) async {
    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      await _tts.stop();

      await _tts.speak(text.replaceAll('\n', ' '));
    } catch (error) {
      debugPrint('TTS 재생 오류: $error');
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  // ============================================================
  // 음성 인식 시작
  // ============================================================

  Future<void> _startListening() async {
    if (_isChoosingConversation || _isWaiting || _isListening) {
      return;
    }

    if (!_speechAvailable) {
      _showMessage(
        '음성 인식을 사용할 수 없어요. '
        '마이크 권한을 확인하거나 '
        '텍스트로 이야기해 주세요.',
      );
      return;
    }

    try {
      await _tts.stop();

      _inputController.clear();

      if (!mounted) return;

      setState(() {
        _isListening = true;
        _isSpeaking = false;
      });

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
    } catch (error) {
      debugPrint('음성 인식 시작 오류: $error');

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      _showMessage('음성 인식을 시작하지 못했어요.');
    }
  }

  // ============================================================
  // 음성 인식 결과
  // ============================================================

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || _isWaiting || _autoSending || _isChoosingConversation) {
      return;
    }

    final recognized = result.recognizedWords.trim();

    _inputController.value = TextEditingValue(
      text: recognized,
      selection: TextSelection.collapsed(offset: recognized.length),
    );

    if (result.finalResult && recognized.isNotEmpty) {
      unawaited(_stopListeningAndSend());
    }
  }

  // ============================================================
  // 음성 인식 상태 변화
  // ============================================================

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'done' || status == 'notListening') {
      setState(() {
        _isListening = false;
      });
    }
  }

  // ============================================================
  // 음성 인식 오류
  // ============================================================

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('음성인식 오류: ${error.errorMsg}');

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    if (error.permanent) {
      _showMessage(
        '음성 인식 서비스를 확인해 주세요. '
        '텍스트 대화도 이용할 수 있어요.',
      );
    }
  }

  // ============================================================
  // 음성 인식을 종료한 후 메시지 전송
  // ============================================================

  Future<void> _stopListeningAndSend() async {
    if (_autoSending || _isWaiting) return;

    _autoSending = true;

    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    try {
      await _speech.stop();

      if (!mounted) return;

      await _sendMessage();
    } finally {
      _autoSending = false;
    }
  }

  // ============================================================
  // Gemini에 전달할 최근 대화 기록
  //
  // 전체 저장 기록이 길어도 최근 10개 메시지만 전송
  // ============================================================

  List<Map<String, dynamic>> _buildHistory() {
    const maxMessages = 10;

    final start = _messages.length > maxMessages
        ? _messages.length - maxMessages
        : 0;

    return _messages
        .skip(start)
        .map((message) => {'isUser': message.isUser, 'text': message.text})
        .toList();
  }

  // ============================================================
  // 메시지 전송
  // ============================================================

  Future<void> _sendMessage() async {
    if (_isChoosingConversation || _isWaiting) {
      return;
    }

    final userText = _inputController.text.trim();

    if (userText.isEmpty) return;

    if (userText.length > 2000) {
      _showMessage('한 번에 2,000자까지만 보낼 수 있어요.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    // 중복 전송 방지
    setState(() {
      _isWaiting = true;
    });

    try {
      await _speech.stop();
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    // 지금 보낼 사용자 메시지는 제외한 이전 대화
    final history = _buildHistory();

    setState(() {
      _isListening = false;
      _isSpeaking = false;

      _messages.add(_ChatMessage(text: userText, isUser: true));

      _inputController.clear();
    });

    _scrollToBottom();

    try {
      // ======================================================
      // AI 응답 요청
      //
      // ConversationAiService가 daily/career/hobby를
      // free-conversation-ai 함수로 전달하도록
      // 이미 설정되어 있어야 합니다.
      // ======================================================

      final result = await ConversationAiService.getReply(
        scenarioCode: widget.domainCode,
        scenarioTitle: widget.domainTitle,
        difficulty: '기본',
        roleName: 'S-TAP',
        goalStep: _legacyGoalStep,
        totalGoalSteps: _legacyTotalSteps,
        userMessage: userText,
        history: history,
      );

      if (!mounted) return;

      // AI 응답을 화면에 표시
      setState(() {
        _legacyGoalStep = result.goalStep;

        _messages.add(_ChatMessage(text: result.reply, isUser: false));
      });

      _scrollToBottom();

      bool historySaveFailed = false;
      bool activitySaveFailed = false;

      // ======================================================
      // 대화 원문 저장
      //
      // 사용자가 저장에 동의한 경우에만 실행
      // ======================================================

      if (_historySavingEnabled) {
        try {
          // 처음 AI 응답이 성공하면 세션 생성
          final id =
              _sessionId ??
              await AiConversationStorageService.createSession(
                domainCode: widget.domainCode,
                title:
                    '${widget.domainTitle} · '
                    '${DateTime.now().year}.'
                    '${DateTime.now().month}.'
                    '${DateTime.now().day}',
              );

          _sessionId = id;

          await AiConversationStorageService.saveExchange(
            sessionId: id,
            userText: userText,
            aiText: result.reply,
          );
        } catch (error) {
          historySaveFailed = true;

          debugPrint('AI 대화 저장 오류: $error');
        }
      }

      // ======================================================
      // 대화 참여 날짜 기록
      //
      // 원문 저장 여부와 관계없이 기록
      // ======================================================

      try {
        await AiConversationStorageService.recordConversationDay();
      } catch (error) {
        activitySaveFailed = true;

        debugPrint('대화 참여 날짜 기록 오류: $error');
      }

      if (!mounted) return;

      setState(() {
        _isWaiting = false;
      });

      if (historySaveFailed) {
        _showMessage('AI 답변은 받았지만 대화 기록 저장에 실패했어요.');
      } else if (activitySaveFailed) {
        _showMessage(
          'AI 답변은 받았지만 '
          '활동 날짜 기록에 실패했어요.',
        );
      }

      // 기존 TTS 기능 유지
      unawaited(_speakAiMessage(result.reply));
    } catch (error) {
      debugPrint('AI 응답 오류: $error');

      if (!mounted) return;

      setState(() {
        _isWaiting = false;
      });

      _showMessage(
        'AI와 연결하지 못했어요. '
        '잠시 후 다시 시도해 주세요.',
      );
    }
  }

  // ============================================================
  // 자동 스크롤
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // 안내 메시지
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // 리소스 정리
  // ============================================================

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_tts.stop());

    _inputController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // 화면 구성
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final statusText = _isChoosingConversation
        ? '대화 기록을 확인하고 있어요...'
        : _isWaiting
        ? '답변을 준비하고 있어요...'
        : _isListening
        ? '듣고 있어요. 편하게 말씀해 주세요.'
        : _isSpeaking
        ? 'S-TAP이 이야기하고 있어요.'
        : '음성이나 텍스트로 이야기해 주세요.';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        title: Text(
          widget.domainTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          // 저장된 대화 목록
          IconButton(
            tooltip: '지난 대화 보기 / 새 대화',
            onPressed: (_isWaiting || _isListening || _isChoosingConversation)
                ? null
                : () {
                    unawaited(_chooseConversation());
                  },
            icon: const Icon(Icons.history_rounded),
          ),

          // 마지막 AI 응답 다시 듣기
          IconButton(
            tooltip: 'AI 음성 다시 듣기',
            onPressed: () {
              final aiMessages = _messages
                  .where((message) => !message.isUser)
                  .toList();

              if (aiMessages.isEmpty) return;

              unawaited(_speakAiMessage(aiMessages.last.text));
            },
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // 대화 상태 안내
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: primaryColor.withValues(alpha: 0.07),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    color: primaryColor,
                    size: 19,
                  ),
                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      '$statusText\n'
                      '${_historySavingEnabled ? "기록 저장 켜짐" : "원문 기록 저장 안 함"}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF347B68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // 채팅 메시지 목록
            // ==================================================
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];

                  return _buildMessageBubble(message);
                },
              ),
            ),

            // ==================================================
            // AI 응답 대기 표시
            // ==================================================
            if (_isWaiting)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),

            // ==================================================
            // 음성 / 텍스트 입력 영역
            // ==================================================
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5EDE9))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 마이크 버튼
                  IconButton.filledTonal(
                    tooltip: _isListening ? '음성 입력 마치기' : '음성으로 대화하기',
                    onPressed: (_isWaiting || _isChoosingConversation)
                        ? null
                        : () {
                            if (_isListening) {
                              unawaited(_stopListeningAndSend());
                            } else {
                              unawaited(_startListening());
                            }
                          },
                    icon: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 텍스트 입력
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isWaiting && !_isChoosingConversation,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        unawaited(_sendMessage());
                      },
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? '음성을 인식하고 있어요...'
                            : '편하게 이야기해 주세요',
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 메시지 전송
                  IconButton.filled(
                    tooltip: '메시지 보내기',
                    onPressed: (_isWaiting || _isChoosingConversation)
                        ? null
                        : () {
                            unawaited(_sendMessage());
                          },
                    style: IconButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 메시지 말풍선
  // ============================================================

  Widget _buildMessageBubble(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.83,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: message.isUser ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: message.isUser
              ? null
              : Border.all(color: const Color(0xFFE6ECE9)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.55,
            color: message.isUser ? Colors.white : const Color(0xFF25312B),
          ),
        ),
      ),
    );
  }
}

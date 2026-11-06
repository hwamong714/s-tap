import 'package:flutter/material.dart';

class TermsScreen extends StatefulWidget {
  final bool viewOnly;

  const TermsScreen({
    super.key,
    this.viewOnly = false,
  });

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  static const Color primary = Color(0xFF00A87E);
  static const Color dark = Color(0xFF151515);
  static const Color background = Color(0xFFF5FFFB);

  final ScrollController _scrollController = ScrollController();

  bool hasReachedBottom = false;

  @override
  void initState() {
    super.initState();

    // 온보딩에서 동의를 받을 때만
    // 끝까지 읽었는지 확인합니다.
    if (!widget.viewOnly) {
      _scrollController.addListener(_checkScrollPosition);
    }
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    // 문서 맨 아래 근처까지 도달하면 동의 버튼 활성화
    if (position.pixels >= position.maxScrollExtent - 20) {
      if (!hasReachedBottom) {
        setState(() {
          hasReachedBottom = true;
        });
      }
    }
  }

  @override
  void dispose() {
    if (!widget.viewOnly) {
      _scrollController.removeListener(_checkScrollPosition);
    }

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (widget.viewOnly) {
              Navigator.pop(context);
            } else {
              Navigator.pop(context, false);
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: dark,
          ),
        ),
        title: const Text(
          '서비스 이용약관',
          style: TextStyle(
            color: dark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'S-TAP 서비스 이용약관',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'S-TAP을 이용하기 전에 아래 내용을 확인해주세요.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF6B716E),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _noticeBox(),

                    const SizedBox(height: 28),

                    _section(
                      number: '제1조',
                      title: '목적',
                      content:
                          '본 약관은 S-TAP 서비스 이용과 관련하여 '
                          '서비스와 이용자 간의 기본적인 권리와 의무, '
                          '이용 조건을 정하는 것을 목적으로 합니다.',
                    ),

                    _section(
                      number: '제2조',
                      title: '서비스의 내용',
                      content:
                          'S-TAP은 사용자의 일상 회복과 사회적 활동 연습을 지원하기 위해 '
                          '프로필 설정, 활동 기록, 미션, 대화 연습, '
                          '맞춤형 연습 추천 등의 기능을 제공할 수 있습니다.',
                    ),

                    _section(
                      number: '제3조',
                      title: '회원가입 및 계정',
                      content:
                          '이용자는 Google 계정 또는 이메일 인증 등을 통해 '
                          'S-TAP에 가입할 수 있습니다.\n\n'
                          '이용자는 자신의 계정을 안전하게 관리해야 하며 '
                          '타인의 계정을 무단으로 사용해서는 안 됩니다.',
                    ),

                    _section(
                      number: '제4조',
                      title: '이용자의 의무',
                      content:
                          '이용자는 다른 이용자에게 피해를 주거나 '
                          '서비스 운영을 방해하는 행위를 해서는 안 됩니다.\n\n'
                          '욕설, 괴롭힘, 개인정보 침해, 타인 사칭, '
                          '불법적인 정보의 공유 등은 제한될 수 있습니다.',
                    ),

                    _section(
                      number: '제5조',
                      title: '서비스 이용 및 변경',
                      content:
                          'S-TAP은 안정적인 서비스 제공을 위해 기능을 '
                          '추가하거나 변경할 수 있습니다.\n\n'
                          '점검이나 시스템 장애 등 불가피한 사유가 있는 경우 '
                          '일부 서비스 이용이 일시적으로 제한될 수 있습니다.',
                    ),

                    _section(
                      number: '제6조',
                      title: '서비스의 성격',
                      content:
                          'S-TAP에서 제공하는 연습, 추천 및 피드백은 '
                          '사용자의 일상 활동을 지원하기 위한 목적으로 제공됩니다.\n\n'
                          '의료적 진단이나 전문적인 치료를 대신하지 않습니다.',
                    ),

                    _section(
                      number: '제7조',
                      title: '회원 탈퇴',
                      content:
                          '이용자는 언제든지 S-TAP 이용을 중단하고 '
                          '회원 탈퇴를 요청할 수 있습니다.\n\n'
                          '탈퇴 시 개인정보와 서비스 이용 기록은 '
                          '관련 정책 및 법령에 따라 처리됩니다.',
                    ),

                    _section(
                      number: '제8조',
                      title: '약관의 변경',
                      content:
                          '서비스 운영 또는 관련 정책의 변경에 따라 '
                          '본 약관이 수정될 수 있습니다.\n\n'
                          '중요한 변경사항이 있는 경우 서비스 내 안내 등을 통해 '
                          '이용자에게 알릴 수 있습니다.',
                    ),

                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE1E5E3),
                        ),
                      ),
                      child: const Text(
                        '※ 현재 내용은 S-TAP 프로토타입 개발을 위한 초안입니다. '
                        '실제 서비스 배포 전에는 최종 서비스 구조와 관련 법령에 맞춰 '
                        '내용을 검토하고 확정해야 합니다.',
                        style: TextStyle(
                          color: Color(0xFF6A716E),
                          height: 1.6,
                        ),
                      ),
                    ),

                    // 맨 아래 감지를 조금 더 자연스럽게 하기 위한 여백
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ==================================================
            // 온보딩 동의 모드에서만 표시
            // ==================================================

            if (!widget.viewOnly)
              Container(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  20,
                ),
                decoration: const BoxDecoration(
                  color: background,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFE4E8E6),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    if (!hasReachedBottom)
                      const Padding(
                        padding: EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF7A817E),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '내용을 끝까지 확인해주세요',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7A817E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: hasReachedBottom
                            ? () {
                                // true를 온보딩 화면으로 전달
                                Navigator.pop(
                                  context,
                                  true,
                                );
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: dark,
                          disabledBackgroundColor:
                              const Color(0xFFD8DCDA),
                          disabledForegroundColor:
                              const Color(0xFF8F9693),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          hasReachedBottom
                              ? '동의하고 돌아가기'
                              : '내용을 확인해주세요',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
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

  Widget _noticeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FFF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primary,
            size: 22,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              '아래 약관은 S-TAP 서비스를 이용할 때 적용되는 '
              '기본적인 이용 규칙을 설명하고 있어요.',
              style: TextStyle(
                color: Color(0xFF4F605A),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String number,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.65,
              color: Color(0xFF5F6663),
            ),
          ),
        ],
      ),
    );
  }
}
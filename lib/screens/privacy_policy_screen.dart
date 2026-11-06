import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool viewOnly;

  const PrivacyPolicyScreen({
    super.key,
    this.viewOnly = false,
  });

  @override
  State<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState
    extends State<PrivacyPolicyScreen> {
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
          '개인정보 처리방침',
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
                      'S-TAP 개인정보 처리방침',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'S-TAP에서 어떤 정보를 이용하고 '
                      '어떻게 보호하는지 안내해드려요.',
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
                      number: '1',
                      title: '수집하는 개인정보',
                      content:
                          'S-TAP은 서비스 제공을 위해 다음과 같은 정보를 '
                          '수집하거나 이용할 수 있습니다.\n\n'
                          '• 이메일 주소 또는 Google 계정 정보\n'
                          '• 닉네임 및 프로필 설정 정보\n'
                          '• 사용자가 선택한 관심 영역\n'
                          '• 앱 이용 및 활동 기록\n\n'
                          '추후 기능이 추가될 경우 수집 항목도 달라질 수 있으며, '
                          '중요한 변경사항은 별도로 안내합니다.',
                    ),

                    _section(
                      number: '2',
                      title: '개인정보의 이용 목적',
                      content:
                          '수집된 정보는 회원 식별, 로그인 상태 관리, '
                          '프로필 제공, 사용자 맞춤형 기능 제공, '
                          '서비스 개선 등을 위해 이용할 수 있습니다.',
                    ),

                    _section(
                      number: '3',
                      title: '활동 및 서비스 이용 정보',
                      content:
                          'S-TAP은 서비스 기능 제공을 위해 사용자의 '
                          '연습 참여, 미션 수행, 활동 기록 등 '
                          '서비스 이용 과정에서 생성되는 정보를 이용할 수 있습니다.\n\n'
                          '이러한 정보는 사용자의 이용 경험을 개선하고 '
                          '맞춤형 연습을 제공하기 위한 목적으로 활용될 수 있습니다.',
                    ),

                    _section(
                      number: '4',
                      title: '민감한 정보의 처리',
                      content:
                          'S-TAP에서는 향후 사용자의 상태 확인 또는 '
                          '맞춤형 지원을 위해 사용자가 직접 입력한 '
                          '일부 정보가 이용될 수 있습니다.\n\n'
                          '이러한 정보는 필요한 범위에서만 처리하며, '
                          '구체적인 수집 항목과 이용 목적은 실제 서비스 기능이 '
                          '확정되는 과정에서 별도로 안내합니다.',
                    ),

                    _section(
                      number: '5',
                      title: '개인정보의 보관',
                      content:
                          '개인정보는 서비스 제공을 위해 필요한 기간 동안 '
                          '보관할 수 있습니다.\n\n'
                          '회원 탈퇴 또는 개인정보 삭제 요청이 있는 경우에는 '
                          '관련 정책과 법령에 따라 정보를 삭제하거나 '
                          '필요한 범위에서 보관합니다.',
                    ),

                    _section(
                      number: '6',
                      title: '개인정보의 제3자 제공',
                      content:
                          'S-TAP은 이용자의 동의 없이 개인정보를 '
                          '외부에 임의로 제공하지 않는 것을 원칙으로 합니다.\n\n'
                          '단, 서비스 제공을 위해 외부 시스템이나 서비스가 '
                          '사용되는 경우 필요한 범위에서 정보 처리가 '
                          '이루어질 수 있으며, 이 경우 관련 내용을 안내합니다.',
                    ),

                    _section(
                      number: '7',
                      title: '이용자의 권리',
                      content:
                          '이용자는 자신의 개인정보를 확인하거나 수정할 수 있으며, '
                          '회원 탈퇴 또는 개인정보 삭제를 요청할 수 있습니다.\n\n'
                          '구체적인 요청 방법은 실제 서비스 배포 전에 '
                          '앱 내 설정 또는 문의 기능을 통해 제공할 예정입니다.',
                    ),

                    _section(
                      number: '8',
                      title: '개인정보 보호',
                      content:
                          'S-TAP은 개인정보가 분실, 유출 또는 '
                          '무단으로 이용되지 않도록 필요한 보호 조치를 '
                          '적용하기 위해 노력합니다.',
                    ),

                    _section(
                      number: '9',
                      title: '처리방침의 변경',
                      content:
                          '서비스 기능이나 개인정보 처리 방식이 변경될 경우 '
                          '본 개인정보 처리방침도 수정될 수 있습니다.\n\n'
                          '중요한 변경사항은 서비스 내 안내 등을 통해 '
                          '알릴 수 있습니다.',
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
                        '※ 현재 개인정보 처리방침은 '
                        'S-TAP 프로토타입 개발을 위한 초안입니다. '
                        '실제 배포 전에는 최종적으로 수집하는 데이터, '
                        '보관 기간, 외부 서비스 이용 여부 등을 기준으로 '
                        '내용을 다시 검토하고 확정해야 합니다.',
                        style: TextStyle(
                          color: Color(0xFF6A716E),
                          height: 1.6,
                        ),
                      ),
                    ),

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
            Icons.shield_outlined,
            color: primary,
            size: 22,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              '개인정보는 필요한 범위에서만 이용하고, '
              '사용자가 자신의 정보를 관리할 수 있도록 하는 것을 원칙으로 합니다.',
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
            '$number. $title',
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
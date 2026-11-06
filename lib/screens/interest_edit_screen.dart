import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_options.dart';

class InterestEditScreen extends StatefulWidget {
  final List<String> currentInterests;

  const InterestEditScreen({super.key, required this.currentInterests});

  @override
  State<InterestEditScreen> createState() => _InterestEditScreenState();
}

class _InterestEditScreenState extends State<InterestEditScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color darkColor = Color(0xFF151918);

  late Set<String> selectedInterests;

  bool isEditing = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    selectedInterests = widget.currentInterests.toSet();
  }

  // ============================================================
  // 현재 관심 영역 표시
  // ============================================================

  String get _currentInterestSummary {
    if (widget.currentInterests.isEmpty) {
      return '설정된 관심 영역 없음';
    }

    return widget.currentInterests.join(', ');
  }

  // ============================================================
  // 수정 시작
  // ============================================================

  void _startEditing() {
    setState(() {
      selectedInterests = widget.currentInterests.toSet();
      isEditing = true;
    });
  }

  // ============================================================
  // 선택 / 해제
  // ============================================================

  void _toggleInterest(String interest) {
    setState(() {
      if (selectedInterests.contains(interest)) {
        selectedInterests.remove(interest);
      } else {
        selectedInterests.add(interest);
      }
    });
  }

  // ============================================================
  // 저장
  // ============================================================

  Future<void> _saveInterests() async {
    if (isSaving) {
      return;
    }

    if (selectedInterests.isEmpty) {
      _showMessage('관심 영역을 하나 이상 선택해주세요.');

      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await Supabase.instance.client
          .from('profiles_v2')
          .update({
            'interests': selectedInterests.toList(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('관심 영역이 변경되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('관심 영역을 저장하지 못했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // 메시지
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,

        leading: IconButton(
          onPressed: isSaving
              ? null
              : () {
                  if (isEditing) {
                    setState(() {
                      isEditing = false;
                      selectedInterests = widget.currentInterests.toSet();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 21,
            color: darkColor,
          ),
        ),

        title: const Text(
          '관심 영역 수정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        top: false,
        child: isEditing ? _buildEditScreen() : _buildCurrentScreen(),
      ),
    );
  }

  // ============================================================
  // 현재 관심 영역 화면
  // ============================================================

  Widget _buildCurrentScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 안내 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 29,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(width: 17),

                      const Expanded(
                        child: Text(
                          '관심 영역은\n'
                          '나에게 맞는 활동과 훈련을 '
                          '추천하는 데 활용돼요.',
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.55,
                            color: Color(0xFF51615C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 38),

                const Text(
                  '현재 설정된 관심 영역',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A5350),
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: widget.currentInterests.isEmpty
                      ? Text(
                          '설정된 관심 영역이 없어요.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: widget.currentInterests.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Text(
                                interest,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4C5B56),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),

                const SizedBox(height: 16),

                Text(
                  _currentInterestSummary,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),

        _buildBottomButton(
          text: '관심 영역 변경하기',
          enabled: true,
          onTap: _startEditing,
        ),
      ],
    );
  }

  // ============================================================
  // 수정 화면
  // ============================================================

  Widget _buildEditScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '어떤 부분을 조금\n바꿔보고 싶나요?',
                  style: TextStyle(
                    fontSize: 27,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                    color: darkColor,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  '여러 개를 선택해도 괜찮아요.',
                  style: TextStyle(fontSize: 14.5, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 28),

                // ------------------------------------------------
                // 온보딩과 동일한 관심 영역
                // ------------------------------------------------
                ...ProfileOptions.interests.map((interest) {
                  final selected = selectedInterests.contains(interest);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        _toggleInterest(interest);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 17,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? primaryColor
                                : const Color(0xFFDDE6E2),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selected
                                    ? primaryColor
                                    : const Color(0xFFF0F4F2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                selected
                                    ? Icons.check_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade500,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: darkColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: primaryColor,
                        size: 20,
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          '선택한 관심 영역은 이후 활동과 '
                          '훈련을 추천할 때 활용할 수 있어요.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: Colors.black54,
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

        _buildBottomButton(
          text: '저장하기',
          enabled: selectedInterests.isNotEmpty && !isSaving,
          loading: isSaving,
          onTap: _saveInterests,
        ),
      ],
    );
  }

  // ============================================================
  // 하단 버튼
  // ============================================================

  Widget _buildBottomButton({
    required String text,
    required bool enabled,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: enabled && !loading ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            disabledBackgroundColor: primaryColor.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

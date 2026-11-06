import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_options.dart';

import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'hq25_intro_screen.dart';
import 'life_status_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);

  final PageController _pageController = PageController();

  final TextEditingController _nicknameController =
      TextEditingController();

  // 한 줄 다짐
  final TextEditingController _messageController =
      TextEditingController();

  int currentStep = 0;

  bool isSaving = false;
  bool showError = false;

  // ============================================================
  // 프로필
  // ============================================================

  String selectedAvatar = '🌱';

  final List<String> avatars = const [
    '🌱',
    '🙂',
    '😊',
    '😎',
    '🐰',
    '🐻',
  ];

  // ============================================================
  // 관심 영역
  // 실제 선택지는 ProfileOptions.interests 사용
  // ============================================================

  final Set<String> selectedInterests = {};

  // ============================================================
  // 지역
  // 실제 지역 데이터는 ProfileOptions 사용
  // ============================================================

  String? regionLevel1;
  String? regionLevel2;
  String? regionLevel3;

  // ============================================================
  // 약관 / 알림
  // ============================================================

  bool termsAgreed = false;
  bool privacyAgreed = false;
  bool notificationsEnabled = true;

  // ============================================================
  // Dispose
  // ============================================================

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    _messageController.dispose();

    super.dispose();
  }

  // ============================================================
  // 지역 관련 Getter
  // ProfileOptions의 공통 지역 데이터 사용
  // ============================================================

  List<String> get _level1Options {
    return ProfileOptions.regionLevel2Data.keys.toList();
  }

  List<String> get _level2Options {
    if (regionLevel1 == null) {
      return [];
    }

    return ProfileOptions.regionLevel2Data[regionLevel1] ?? [];
  }

  List<String> get _level3Options {
    if (regionLevel2 == null) {
      return [];
    }

    return ProfileOptions.regionLevel3Data[regionLevel2] ?? [];
  }

  bool get _needsLevel2 {
    if (regionLevel1 == null) {
      return false;
    }

    return _level2Options.isNotEmpty;
  }

  bool get _needsLevel3 {
    return _level3Options.isNotEmpty;
  }

  // ============================================================
  // 유효성 검사
  // ============================================================

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        return _nicknameController.text.trim().isNotEmpty;

      case 1:
        return selectedInterests.isNotEmpty;

      case 2:
        if (regionLevel1 == null) {
          return false;
        }

        if (_needsLevel2 && regionLevel2 == null) {
          return false;
        }

        if (_needsLevel3 && regionLevel3 == null) {
          return false;
        }

        return true;

      case 3:
        return termsAgreed && privacyAgreed;

      default:
        return false;
    }
  }

  String get _errorMessage {
    switch (currentStep) {
      case 0:
        return '닉네임을 입력해주세요.';

      case 1:
        return '바꾸고 싶은 영역을 하나 이상 선택해주세요.';

      case 2:
        return '거주 지역을 모두 선택해주세요.';

      case 3:
        return '이용약관과 개인정보 처리방침에 동의해주세요.';

      default:
        return '입력 내용을 확인해주세요.';
    }
  }

  // ============================================================
  // 페이지 이동
  // ============================================================

  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) {
      setState(() {
        showError = true;
      });

      return;
    }

    setState(() {
      showError = false;
    });

    if (currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(
          milliseconds: 250,
        ),
        curve: Curves.easeOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();

    if (currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    _pageController.previousPage(
      duration: const Duration(
        milliseconds: 250,
      ),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // 약관
  // ============================================================

  Future<void> _openTerms() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsScreen(),
      ),
    );

    if (result == true) {
      setState(() {
        termsAgreed = true;
        showError = false;
      });
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );

    if (result == true) {
      setState(() {
        privacyAgreed = true;
        showError = false;
      });
    }
  }

  // ============================================================
  // 온보딩 완료 및 저장
  // ============================================================

  Future<void> _completeOnboarding() async {
    if (isSaving) {
      return;
    }

    if (!_validateCurrentStep()) {
      setState(() {
        showError = true;
      });

      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '로그인 정보를 확인할 수 없습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now =
          DateTime.now().toIso8601String();

      final message =
          _messageController.text.trim();

      // ======================================================
      // 1. profiles_v2 저장
      // ======================================================

      await Supabase.instance.client
          .from('profiles_v2')
          .upsert({
        'id': user.id,

        'nickname':
            _nicknameController.text.trim(),

        // 한 줄 다짐
        'message':
            message.isEmpty ? null : message,

        'avatar_type': 'emoji',

        'avatar_emoji':
            selectedAvatar,

        'profile_image_url':
            null,

        'interests':
            selectedInterests.toList(),

        'region_level1':
            regionLevel1,

        'region_level2':
            regionLevel2,

        'region_level3':
            regionLevel3,

        // 추후 공식 행정구역 코드 연결
        'region_code':
            null,

        'notifications_enabled':
            notificationsEnabled,

        'terms_agreed_at':
            now,

        'privacy_agreed_at':
            now,

        'onboarding_completed':
            true,

        'updated_at':
            now,
      });

      // ======================================================
      // 2. HQ-25 초기검사 기록 확인
      // ======================================================

      final initialHq25 =
          await Supabase.instance.client
              .from('hq25_assessments')
              .select('id')
              .eq('user_id', user.id)
              .eq(
                'assessment_type',
                'initial',
              )
              .limit(1)
              .maybeSingle();

      if (!mounted) {
        return;
      }

      // HQ-25를 아직 하지 않은 사용자
      if (initialHq25 == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const Hq25IntroScreen(),
          ),
          (route) => false,
        );

        return;
      }

      // ======================================================
      // 3. 생활상태 초기 기록 확인
      // ======================================================

      final initialLifeStatus =
          await Supabase.instance.client
              .from(
                'life_status_assessments',
              )
              .select('id')
              .eq('user_id', user.id)
              .eq(
                'assessment_type',
                'initial',
              )
              .limit(1)
              .maybeSingle();

      if (!mounted) {
        return;
      }

      // HQ-25는 했지만 생활상태 입력은 하지 않은 사용자
      if (initialLifeStatus == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const LifeStatusScreen(),
          ),
          (route) => false,
        );

        return;
      }

      // ======================================================
      // 4. 모두 완료된 사용자
      // ======================================================

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HomeScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '프로필 저장 중 오류가 발생했습니다.\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final progress =
        (currentStep + 1) / 4;

    return Scaffold(
      backgroundColor:
          backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // 상단 진행상황
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        isSaving
                            ? null
                            : _previousPage,
                    icon: const Icon(
                      Icons
                          .arrow_back_ios_new_rounded,
                      size: 21,
                    ),
                  ),

                  const SizedBox(
                    width: 5,
                  ),

                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        100,
                      ),
                      child:
                          LinearProgressIndicator(
                        value:
                            progress,
                        minHeight:
                            7,
                        backgroundColor:
                            const Color(
                          0xFFE3ECE8,
                        ),
                        valueColor:
                            const AlwaysStoppedAnimation<
                                Color>(
                          primaryColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  Text(
                    '${currentStep + 1}/4',
                    style:
                        const TextStyle(
                      fontSize:
                          14,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // 페이지
            // ==================================================

            Expanded(
              child: PageView(
                controller:
                    _pageController,
                physics:
                    const NeverScrollableScrollPhysics(),
                onPageChanged:
                    (index) {
                  setState(() {
                    currentStep =
                        index;

                    showError =
                        false;
                  });
                },
                children: [
                  _buildProfileStep(),
                  _buildInterestStep(),
                  _buildRegionStep(),
                  _buildAgreementStep(),
                ],
              ),
            ),

            // ==================================================
            // 오류
            // ==================================================

            if (showError)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  8,
                ),
                child: Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    13,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFFFEEEE,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Text(
                    _errorMessage,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFD94343,
                      ),
                      fontWeight:
                          FontWeight.w600,
                      fontSize:
                          13,
                    ),
                  ),
                ),
              ),

            // ==================================================
            // 하단 버튼
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                10,
                24,
                20,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                height:
                    56,
                child:
                    ElevatedButton(
                  onPressed:
                      isSaving
                          ? null
                          : _nextPage,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        primaryColor,
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        primaryColor
                            .withValues(
                      alpha:
                          0.5,
                    ),
                    elevation:
                        0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                  child:
                      isSaving
                          ? const SizedBox(
                              width:
                                  23,
                              height:
                                  23,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,
                                color:
                                    Colors.white,
                              ),
                            )
                          : Text(
                              currentStep == 3
                                  ? '시작하기'
                                  : '다음',
                              style:
                                  const TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 1
  // 닉네임 + 이모지 + 한 줄 다짐
  // ============================================================

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        32,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'S-TAP에서 사용할\n나를 설정해볼까요?',
            style:
                TextStyle(
              fontSize:
                  28,
              height:
                  1.35,
              fontWeight:
                  FontWeight.w900,
              color:
                  Colors.black87,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            '언제든 마이페이지에서 바꿀 수 있어요.',
            style:
                TextStyle(
              fontSize:
                  14.5,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 32,
          ),

          // ----------------------------------------------------
          // 닉네임
          // ----------------------------------------------------

          const Text(
            '닉네임',
            style:
                TextStyle(
              fontSize:
                  15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          TextField(
            controller:
                _nicknameController,
            maxLength:
                15,
            onChanged:
                (_) {
              if (showError) {
                setState(() {
                  showError =
                      false;
                });
              }
            },
            decoration:
                InputDecoration(
              hintText:
                  '사용할 닉네임을 입력해주세요',
              counterText:
                  '',
              filled:
                  true,
              fillColor:
                  Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal:
                    18,
                vertical:
                    18,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(
                    0xFFDDE6E2,
                  ),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      primaryColor,
                  width:
                      1.7,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          // ----------------------------------------------------
          // 프로필 이모지
          // ----------------------------------------------------

          const Text(
            '프로필 이모지',
            style:
                TextStyle(
              fontSize:
                  15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            '나중에는 원하는 사진으로 바꿀 수도 있어요.',
            style:
                TextStyle(
              fontSize:
                  13.5,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Wrap(
            spacing:
                12,
            runSpacing:
                12,
            children:
                avatars.map(
              (emoji) {
                final selected =
                    selectedAvatar ==
                        emoji;

                return InkWell(
                  onTap:
                      () {
                    setState(() {
                      selectedAvatar =
                          emoji;
                    });
                  },
                  borderRadius:
                      BorderRadius.circular(
                    50,
                  ),
                  child:
                      AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds:
                          150,
                    ),
                    width:
                        62,
                    height:
                        62,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Colors.white,
                      border:
                          Border.all(
                        color:
                            selected
                                ? primaryColor
                                : const Color(
                                    0xFFDDE6E2,
                                  ),
                        width:
                            selected
                                ? 2.2
                                : 1,
                      ),
                    ),
                    child:
                        Center(
                      child:
                          Text(
                        emoji,
                        style:
                            const TextStyle(
                          fontSize:
                              29,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(
            height: 30,
          ),

          // ----------------------------------------------------
          // 한 줄 다짐
          // ----------------------------------------------------

          Row(
            children: [
              const Text(
                '한 줄 다짐',
                style:
                    TextStyle(
                  fontSize:
                      15,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              Text(
                '선택',
                style:
                    TextStyle(
                  fontSize:
                      12.5,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            '지금의 마음이나 앞으로의 작은 다짐을 남겨보세요.',
            style:
                TextStyle(
              fontSize:
                  13.5,
              height:
                  1.5,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 11,
          ),

          TextField(
            controller:
                _messageController,
            maxLength:
                50,
            minLines:
                1,
            maxLines:
                2,
            decoration:
                InputDecoration(
              hintText:
                  '예: 천천히라도 한 걸음씩 나아가고 싶어요.',
              counterText:
                  '',
              filled:
                  true,
              fillColor:
                  Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal:
                    18,
                vertical:
                    17,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(
                    0xFFDDE6E2,
                  ),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      primaryColor,
                  width:
                      1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2
  // 관심 영역
  // ============================================================

  Widget _buildInterestStep() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        32,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            '어떤 부분을 조금\n바꿔보고 싶나요?',
            style:
                TextStyle(
              fontSize:
                  28,
              height:
                  1.35,
              fontWeight:
                  FontWeight.w900,
              color:
                  Colors.black87,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            '여러 개를 선택해도 괜찮아요.',
            style:
                TextStyle(
              fontSize:
                  14.5,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          // ----------------------------------------------------
          // ProfileOptions의 공통 관심영역 사용
          // ----------------------------------------------------

          ...ProfileOptions.interests.map(
            (interest) {
              final selected =
                  selectedInterests.contains(
                interest,
              );

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom:
                      11,
                ),
                child:
                    InkWell(
                  onTap:
                      () {
                    setState(() {
                      if (selected) {
                        selectedInterests.remove(
                          interest,
                        );
                      } else {
                        selectedInterests.add(
                          interest,
                        );
                      }

                      showError =
                          false;
                    });
                  },
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  child:
                      AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds:
                          150,
                    ),
                    padding:
                        const EdgeInsets.all(
                      17,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          selected
                              ? primaryColor.withValues(
                                  alpha:
                                      0.08,
                                )
                              : Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                      border:
                          Border.all(
                        color:
                            selected
                                ? primaryColor
                                : const Color(
                                    0xFFDDE6E2,
                                  ),
                        width:
                            selected
                                ? 1.8
                                : 1,
                      ),
                    ),
                    child:
                        Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color:
                              selected
                                  ? primaryColor
                                  : Colors.grey.shade400,
                        ),

                        const SizedBox(
                          width:
                              13,
                        ),

                        Expanded(
                          child:
                              Text(
                            interest,
                            style:
                                TextStyle(
                              fontSize:
                                  15,
                              fontWeight:
                                  selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3
  // 거주 지역
  // ============================================================

  Widget _buildRegionStep() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        32,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            '어느 지역에\n살고 계신가요?',
            style:
                TextStyle(
              fontSize:
                  28,
              height:
                  1.35,
              fontWeight:
                  FontWeight.w900,
              color:
                  Colors.black87,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            '가까운 지원기관과 지역별 지원정보를 '
            '안내하는 데 활용해요.',
            style:
                TextStyle(
              fontSize:
                  14.5,
              height:
                  1.55,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _buildRegionDropdown(
            label:
                '시·도',
            hint:
                '시·도를 선택해주세요',
            value:
                regionLevel1,
            items:
                _level1Options,
            onChanged:
                (value) {
              setState(() {
                regionLevel1 =
                    value;

                regionLevel2 =
                    null;

                regionLevel3 =
                    null;

                showError =
                    false;
              });
            },
          ),

          if (_needsLevel2) ...[
            const SizedBox(
              height:
                  18,
            ),

            _buildRegionDropdown(
              label:
                  '시·군·구',
              hint:
                  '지역을 선택해주세요',
              value:
                  regionLevel2,
              items:
                  _level2Options,
              onChanged:
                  (value) {
                setState(() {
                  regionLevel2 =
                      value;

                  regionLevel3 =
                      null;

                  showError =
                      false;
                });
              },
            ),
          ],

          if (_needsLevel3) ...[
            const SizedBox(
              height:
                  18,
            ),

            _buildRegionDropdown(
              label:
                  '구',
              hint:
                  '구를 선택해주세요',
              value:
                  regionLevel3,
              items:
                  _level3Options,
              onChanged:
                  (value) {
                setState(() {
                  regionLevel3 =
                      value;

                  showError =
                      false;
                });
              },
            ),
          ],

          const SizedBox(
            height: 24,
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              16,
            ),
            decoration:
                BoxDecoration(
              color:
                  primaryColor.withValues(
                alpha:
                    0.06,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child:
                const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color:
                      primaryColor,
                  size:
                      20,
                ),

                SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      Text(
                    '상세 주소나 현재 위치는 받지 않아요. '
                    '지역별 지원정보를 안내하는 데 필요한 '
                    '범위만 저장해요.',
                    style:
                        TextStyle(
                      fontSize:
                          13.5,
                      height:
                          1.55,
                      color:
                          Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 지역 선택 Dropdown
  // ============================================================

  Widget _buildRegionDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                15,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(
          height:
              9,
        ),

        DropdownButtonFormField<String>(
          key: ValueKey(
            '$label-$value-${items.join('|')}',
          ),
          initialValue:
              value,
          isExpanded:
              true,
          hint:
              Text(
            hint,
            style:
                TextStyle(
              color:
                  Colors.grey.shade500,
            ),
          ),
          items:
              items.map(
            (item) {
              return DropdownMenuItem<String>(
                value:
                    item,
                child:
                    Text(
                  item,
                ),
              );
            },
          ).toList(),
          onChanged:
              onChanged,
          decoration:
              InputDecoration(
            filled:
                true,
            fillColor:
                Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  16,
              vertical:
                  17,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(
                  0xFFDDE6E2,
                ),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    primaryColor,
                width:
                    1.7,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 4
  // 약관
  // ============================================================

  Widget _buildAgreementStep() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        32,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            '마지막으로\n몇 가지만 확인할게요.',
            style:
                TextStyle(
              fontSize:
                  28,
              height:
                  1.35,
              fontWeight:
                  FontWeight.w900,
              color:
                  Colors.black87,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            '내용을 확인한 뒤 동의해주세요.',
            style:
                TextStyle(
              fontSize:
                  14.5,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _agreementTile(
            title:
                '이용약관 동의',
            agreed:
                termsAgreed,
            onTap:
                _openTerms,
          ),

          const SizedBox(
            height: 12,
          ),

          _agreementTile(
            title:
                '개인정보 처리방침 동의',
            agreed:
                privacyAgreed,
            onTap:
                _openPrivacyPolicy,
          ),

          const SizedBox(
            height: 26,
          ),

          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  4,
            ),
            title:
                const Text(
              '알림 받기',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            subtitle:
                const Text(
              '활동이나 기록 알림을 받을 수 있어요.',
            ),
            activeThumbColor:
                primaryColor,
            value:
                notificationsEnabled,
            onChanged:
                (value) {
              setState(() {
                notificationsEnabled =
                    value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 약관 Tile
  // ============================================================

  Widget _agreementTile({
    required String title,
    required bool agreed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
          onTap,
      borderRadius:
          BorderRadius.circular(
        17,
      ),
      child:
          Container(
        padding:
            const EdgeInsets.all(
          17,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          border:
              Border.all(
            color:
                agreed
                    ? primaryColor
                    : const Color(
                        0xFFDDE6E2,
                      ),
            width:
                agreed
                    ? 1.7
                    : 1,
          ),
        ),
        child:
            Row(
          children: [
            Icon(
              agreed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  agreed
                      ? primaryColor
                      : Colors.grey.shade400,
            ),

            const SizedBox(
              width:
                  13,
            ),

            Expanded(
              child:
                  Text(
                title,
                style:
                    const TextStyle(
                  fontSize:
                      15,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size:
                  17,
              color:
                  Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
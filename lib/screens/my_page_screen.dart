import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'profile_edit_screen.dart';
import 'region_edit_screen.dart';
import 'interest_edit_screen.dart';
import 'conversation_training_screen.dart';
import 'record_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color darkColor = Color(0xFF151918);
  static const Color errorColor = Color(0xFFE5484D);

  bool isLoading = true;
  bool isUpdatingNotification = false;

  String nickname = '사용자';
  String? message;

  String avatarType = 'emoji';
  String avatarEmoji = '🌱';
  String? profileImageUrl;

  String email = '';

  List<String> interests = [];

  String? regionLevel1;
  String? regionLevel2;
  String? regionLevel3;

  bool notificationsEnabled = true;

  bool hasInitialHq25 = false;
  bool hasInitialLifeStatus = false;

  @override
  void initState() {
    super.initState();

    _loadMyPageData();
  }

  // ============================================================
  // 마이페이지 데이터 불러오기
  // ============================================================

  Future<void> _loadMyPageData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // 프로필
      // --------------------------------------------------------

      final profile = await Supabase.instance.client
          .from('profiles_v2')
          .select(
            'nickname, '
            'message, '
            'avatar_type, '
            'avatar_emoji, '
            'profile_image_url, '
            'interests, '
            'region_level1, '
            'region_level2, '
            'region_level3, '
            'notifications_enabled',
          )
          .eq('id', user.id)
          .maybeSingle();

      // --------------------------------------------------------
      // HQ-25 초기검사
      // --------------------------------------------------------

      final hq25 = await Supabase.instance.client
          .from('hq25_assessments')
          .select('id')
          .eq('user_id', user.id)
          .eq('assessment_type', 'initial')
          .limit(1)
          .maybeSingle();

      // --------------------------------------------------------
      // 생활상태 초기검사
      // --------------------------------------------------------

      final lifeStatus = await Supabase.instance.client
          .from('life_status_assessments')
          .select('id')
          .eq('user_id', user.id)
          .eq('assessment_type', 'initial')
          .limit(1)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      final rawInterests = profile?['interests'];

      List<String> loadedInterests = [];

      if (rawInterests is List) {
        loadedInterests =
            rawInterests.map((item) => item.toString()).toList();
      }

      String? loadedProfileImageUrl;

      final storedProfileImagePath =
          profile?['profile_image_url']?.toString();

      if (storedProfileImagePath != null &&
          storedProfileImagePath.trim().isNotEmpty) {
        try {
          if (storedProfileImagePath.startsWith('http://') ||
              storedProfileImagePath.startsWith('https://')) {
            // 예전 URL 방식 데이터가 있다면 그대로 사용
            loadedProfileImageUrl = storedProfileImagePath;
          } else {
            // Private Storage 파일은 임시 signed URL 생성
            loadedProfileImageUrl =
                await Supabase.instance.client.storage
                    .from('profile-images')
                    .createSignedUrl(
                      storedProfileImagePath,
                      60 * 60,
                    );
          }
        } catch (_) {
          loadedProfileImageUrl = null;
        }
      }

      setState(() {
        email = user.email ?? '';

        nickname =
            profile?['nickname']?.toString() ?? '사용자';

        message =
            profile?['message']?.toString();

        avatarType =
            profile?['avatar_type']?.toString() ?? 'emoji';

        avatarEmoji =
            profile?['avatar_emoji']?.toString() ?? '🌱';

        profileImageUrl =
            loadedProfileImageUrl;

        interests =
            loadedInterests;

        regionLevel1 =
            profile?['region_level1']?.toString();

        regionLevel2 =
            profile?['region_level2']?.toString();

        regionLevel3 =
            profile?['region_level3']?.toString();

        notificationsEnabled =
            profile?['notifications_enabled'] == true;

        hasInitialHq25 =
            hq25 != null;

        hasInitialLifeStatus =
            lifeStatus != null;

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '마이페이지 정보를 불러오지 못했습니다.\n$error',
          ),
        ),
      );
    }
  }

  // ============================================================
  // 관심 영역 표시
  // ============================================================

  String get _interestSummary {
    if (interests.isEmpty) {
      return '등록된 관심 영역 없음';
    }

    if (interests.length == 1) {
      return interests.first;
    }

    return '${interests.first} 외 ${interests.length - 1}개';
  }

  // ============================================================
  // 지역 표시
  // ============================================================

  String get _regionSummary {
    final parts = <String>[
      if (regionLevel1 != null &&
          regionLevel1!.trim().isNotEmpty)
        regionLevel1!.trim(),

      if (regionLevel2 != null &&
          regionLevel2!.trim().isNotEmpty)
        regionLevel2!.trim(),

      if (regionLevel3 != null &&
          regionLevel3!.trim().isNotEmpty)
        regionLevel3!.trim(),
    ];

    if (parts.isEmpty) {
      return '지역 정보 없음';
    }

    return parts.join(' ');
  }

  // ============================================================
  // 알림 설정 저장
  // ============================================================

  Future<void> _updateNotification(bool value) async {
    if (isUpdatingNotification) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      isUpdatingNotification = true;
    });

    try {
      await Supabase.instance.client
          .from('profiles_v2')
          .update({
            'notifications_enabled': value,
            'updated_at':
                DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) {
        return;
      }

      setState(() {
        notificationsEnabled = value;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '알림 설정을 변경하지 못했습니다.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingNotification = false;
        });
      }
    }
  }

  // ============================================================
  // 로그아웃 확인
  // ============================================================

  Future<void> _confirmLogout() async {
    final shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '로그아웃할까요?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            '다시 이용하려면 계정으로 로그인해야 합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    errorColor,
              ),
              child:
                  const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await Supabase.instance.client.auth
          .signOut();

      if (!mounted) {
        return;
      }

      // 마이페이지 등 위에 쌓인 화면을 모두 닫고
      // AuthGate가 보여주는 로그인 화면으로 돌아갑니다.
      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '로그아웃 중 오류가 발생했습니다.\n$error',
          ),
        ),
      );
    }
  }

  // ============================================================
  // 준비 중 메시지
  // ============================================================

  void _showPreparingMessage(
    String featureName,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$featureName 기능을 준비하고 있어요.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      bottomNavigationBar:
          _buildBottomNavigation(),

      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: _loadMyPageData,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              22,
              20,
              32,
            ),
            child: isLoading
                ? _buildLoading()
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        child: Text(
                          '내 프로필',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight:
                                FontWeight
                                    .w900,
                            color:
                                darkColor,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      _buildProfileCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildMyInfoCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildStatusCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildSettingsCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildAccountCard(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 로딩
  // ============================================================

  Widget _buildLoading() {
    return SizedBox(
      height: 550,
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: primaryColor,
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              '내 정보를 불러오고 있어요.',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 상단 프로필 카드
  // ============================================================

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF0FFF8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          26,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFDDEFE8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 20,
            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE9FFF5,
              ),
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color: primaryColor
                    .withValues(
                  alpha: 0.12,
                ),
              ),
            ),
            clipBehavior:
                Clip.antiAlias,
            child:
                _buildProfileAvatar(),
          ),

          const SizedBox(
            width: 18,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight
                            .w900,
                    color:
                        darkColor,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                if (message != null &&
                    message!
                        .trim()
                        .isNotEmpty)
                  Text(
                    message!,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: Colors
                          .grey
                          .shade700,
                    ),
                  )
                else
                  Text(
                    '한 줄 메시지가 아직 없어요.',
                    style:
                        TextStyle(
                      fontSize: 14,
                      color: Colors
                          .grey
                          .shade500,
                    ),
                  ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  email.isEmpty
                      ? '이메일 정보 없음'
                      : email,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize: 12.5,
                    color: Colors
                        .grey
                        .shade500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          FilledButton(
            onPressed: () async {
              final updated =
                  await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ProfileEditScreen(),
                ),
              );

              if (updated == true) {
                await _loadMyPageData();
              }
            },
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  const Color(
                0xFFE0F8EE,
              ),
              foregroundColor:
                  primaryColor,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
            ),
            child: const Text(
              '프로필 수정',
              style: TextStyle(
                fontWeight:
                    FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 프로필 이미지 / 이모지
  // ============================================================

  Widget _buildProfileAvatar() {
    final hasImage =
        avatarType == 'image' &&
        profileImageUrl != null &&
        profileImageUrl!
            .trim()
            .isNotEmpty;

    if (hasImage) {
      return Image.network(
        profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return _buildEmojiAvatar();
        },
      );
    }

    return _buildEmojiAvatar();
  }

  Widget _buildEmojiAvatar() {
    return Center(
      child: Text(
        avatarEmoji,
        style:
            const TextStyle(
          fontSize: 42,
        ),
      ),
    );
  }

  // ============================================================
  // 내 정보
  // ============================================================

  Widget _buildMyInfoCard() {
    return _buildSectionCard(
      icon:
          Icons.person_rounded,
      title:
          '내 정보',
      children: [
        _buildMenuRow(
          icon:
              Icons.favorite_border_rounded,
          title:
              '관심 영역',
          value:
              _interestSummary,
          showArrow:
              true,
          onTap: () async {
            final updated =
                await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InterestEditScreen(
                  currentInterests:
                      interests,
                ),
              ),
            );

            if (updated == true) {
              await _loadMyPageData();
            }
          },
        ),

        _buildDivider(),

        _buildMenuRow(
          icon:
              Icons.location_on_outlined,
          title:
              '생활 지역',
          value:
              _regionSummary,
          showArrow:
              true,
          onTap: () async {
            final updated =
                await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RegionEditScreen(
                  regionLevel1:
                      regionLevel1,
                  regionLevel2:
                      regionLevel2,
                  regionLevel3:
                      regionLevel3,
                ),
              ),
            );

            if (updated == true) {
              await _loadMyPageData();
            }
          },
        ),
      ],
    );
  }

  // ============================================================
  // 내 상태 확인
  // ============================================================

  Widget _buildStatusCard() {
    return _buildSectionCard(
      icon:
          Icons.bar_chart_rounded,
      title:
          '내 상태 확인',
      children: [
        _buildMenuRow(
          icon:
              Icons.description_outlined,
          title:
              '초기 상태 확인',
          customTrailing:
              _buildStatusChip(
            hasInitialHq25,
          ),
          showArrow:
              true,
          onTap: () {
            _showPreparingMessage(
              '초기 상태 결과 보기',
            );
          },
        ),

        _buildDivider(),

        _buildMenuRow(
          icon:
              Icons.calendar_month_outlined,
          title:
              '생활상태 확인',
          customTrailing:
              _buildStatusChip(
            hasInitialLifeStatus,
          ),
          showArrow:
              true,
          onTap: () {
            _showPreparingMessage(
              '생활상태 기록 보기',
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // 설정
  // ============================================================

  Widget _buildSettingsCard() {
    return _buildSectionCard(
      icon:
          Icons.settings_rounded,
      title:
          '설정',
      children: [
        _buildMenuRow(
          icon:
              Icons.notifications_none_rounded,
          title:
              '알림 설정',
          customTrailing:
              Switch(
            value:
                notificationsEnabled,
            onChanged:
                isUpdatingNotification
                    ? null
                    : _updateNotification,
            activeTrackColor:
                primaryColor,
            activeThumbColor:
                Colors.white,
          ),
        ),

        _buildDivider(),

        _buildMenuRow(
          icon:
              Icons.article_outlined,
          title:
              '이용약관',
          showArrow:
              true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const TermsScreen(
                  viewOnly: true,
                ),
              ),
            );
          },
        ),

        _buildDivider(),

        _buildMenuRow(
          icon:
              Icons.shield_outlined,
          title:
              '개인정보처리방침',
          showArrow:
              true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const PrivacyPolicyScreen(
                  viewOnly: true,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // 계정
  // ============================================================

  Widget _buildAccountCard() {
    return _buildSectionCard(
      icon:
          Icons.lock_outline_rounded,
      title:
          '계정',
      children: [
        _buildMenuRow(
          icon:
              Icons.logout_rounded,
          title:
              '로그아웃',
          titleColor:
              errorColor,
          iconColor:
              errorColor,
          showArrow:
              true,
          onTap:
              _confirmLogout,
        ),
      ],
    );
  }

  // ============================================================
  // 공통 섹션 카드
  // ============================================================

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        8,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          26,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE4ECE9,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildIconCircle(
                icon,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .w900,
                    color:
                        darkColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 6,
          ),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // 메뉴 Row
  // ============================================================

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    String? value,
    Widget? customTrailing,
    VoidCallback? onTap,
    bool showArrow = false,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
        ),
        child: Row(
          children: [
            _buildIconCircle(
              icon,
              iconColor:
                  iconColor,
              size: 42,
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child: Text(
                title,
                style:
                    TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      titleColor ??
                          darkColor,
                ),
              ),
            ),

            if (value != null) ...[
              const SizedBox(
                width: 10,
              ),

              Flexible(
                child: Text(
                  value,
                  textAlign:
                      TextAlign.right,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize: 13.5,
                    color: Colors
                        .grey
                        .shade600,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),
            ],

            if (customTrailing != null) ...[
              const SizedBox(
                width: 10,
              ),
              customTrailing,
            ],

            if (showArrow) ...[
              const SizedBox(
                width: 7,
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                size: 25,
                color: Colors
                    .grey
                    .shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 아이콘 원
  // ============================================================

  Widget _buildIconCircle(
    IconData icon, {
    Color? iconColor,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(
        color:
            Color(
          0xFFE7FBF3,
        ),
        shape:
            BoxShape.circle,
      ),
      alignment:
          Alignment.center,
      child: Icon(
        icon,
        size:
            size * 0.52,
        color:
            iconColor ??
                primaryColor,
      ),
    );
  }

  // ============================================================
  // 구분선
  // ============================================================

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color:
          Color(
        0xFFEDF0EF,
      ),
    );
  }

  // ============================================================
  // 완료 상태
  // ============================================================

  Widget _buildStatusChip(
    bool completed,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color: completed
            ? const Color(
                0xFFE1FAF0,
              )
            : const Color(
                0xFFF1F2F2,
              ),
        borderRadius:
            BorderRadius.circular(
          100,
        ),
      ),
      child: Text(
        completed
            ? '완료'
            : '미완료',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight:
              FontWeight.w800,
          color: completed
              ? primaryColor
              : Colors
                  .grey
                  .shade600,
        ),
      ),
    );
  }

  // ============================================================
  // 하단 메뉴
  // 홈 화면의 NavigationBar와 동일한 구성
  // ============================================================

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 72,
      backgroundColor:
          Colors.white,
      indicatorColor:
          primaryColor.withValues(
        alpha: 0.12,
      ),

      // 현재 화면은 MY
      selectedIndex: 3,

      onDestinationSelected:
          (index) async {
        switch (index) {
          // ----------------------------------------------------
          // 홈
          // ----------------------------------------------------
          case 0:
            Navigator.of(context).pop();
            break;

          // ----------------------------------------------------
          // 연습
          // ----------------------------------------------------
          case 1:
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ConversationTrainingScreen(),
              ),
            );
            break;

          // ----------------------------------------------------
          // 기록
          // ----------------------------------------------------
          case 2:
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const RecordScreen(),
              ),
            );
            break;

          // ----------------------------------------------------
          // MY
          // ----------------------------------------------------
          case 3:
            return;
        }
      },

      destinations:
          const [
        NavigationDestination(
          icon:
              Icon(
            Icons.home_outlined,
          ),
          selectedIcon:
              Icon(
            Icons.home_rounded,
            color:
                primaryColor,
          ),
          label:
              '홈',
        ),

        NavigationDestination(
          icon:
              Icon(
            Icons.menu_book_outlined,
          ),
          selectedIcon:
              Icon(
            Icons.menu_book_rounded,
            color:
                primaryColor,
          ),
          label:
              '연습',
        ),

        NavigationDestination(
          icon:
              Icon(
            Icons.bar_chart_rounded,
          ),
          selectedIcon:
              Icon(
            Icons.bar_chart_rounded,
            color:
                primaryColor,
          ),
          label:
              '기록',
        ),

        NavigationDestination(
          icon:
              Icon(
            Icons.person_outline_rounded,
          ),
          selectedIcon:
              Icon(
            Icons.person_rounded,
            color:
                primaryColor,
          ),
          label:
              'MY',
        ),
      ],
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color primary = Color(0xFF00A87E);

  static const Color primaryDark = Color(0xFF007A63);

  static const Color dark = Color(0xFF151515);

  static const Color errorColor = Color(0xFFE14B5A);

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final passwordConfirmController = TextEditingController();

  String? emailError;

  String? passwordError;

  String? passwordConfirmError;

  bool obscurePassword = true;

  bool obscurePasswordConfirm = true;

  bool isEmailLoading = false;

  bool isGoogleLoading = false;

  bool emailSent = false;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Google 로그인 또는 이메일 인증 링크를 통해
    // 실제 세션이 생성되면 회원가입 화면을 닫습니다.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.session != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();

    emailController.dispose();

    passwordController.dispose();

    passwordConfirmController.dispose();

    super.dispose();
  }

  // ============================================================
  // 이메일 형식 검사
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  // ============================================================
  // 비밀번호 검사
  // ============================================================

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return '비밀번호를 입력해 주세요.';
    }

    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해 주세요.';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      return '영문을 1자 이상 포함해 주세요.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return '숫자를 1자 이상 포함해 주세요.';
    }

    return null;
  }

  // ============================================================
  // 이메일 회원가입
  // ============================================================

  Future<void> _signUpWithEmail() async {
    final email = emailController.text.trim();

    final password = passwordController.text;

    final passwordConfirm = passwordConfirmController.text;

    String? newEmailError;

    String? newPasswordError;

    String? newPasswordConfirmError;

    // ----------------------------------------------------------
    // 입력값 검사
    // ----------------------------------------------------------

    if (email.isEmpty) {
      newEmailError = '이메일 주소를 입력해 주세요.';
    } else if (!_isValidEmail(email)) {
      newEmailError = '올바른 이메일 주소를 입력해 주세요.';
    }

    newPasswordError = _validatePassword(password);

    if (passwordConfirm.isEmpty) {
      newPasswordConfirmError = '비밀번호를 다시 입력해 주세요.';
    } else if (password != passwordConfirm) {
      newPasswordConfirmError = '비밀번호가 일치하지 않습니다.';
    }

    setState(() {
      emailError = newEmailError;

      passwordError = newPasswordError;

      passwordConfirmError = newPasswordConfirmError;
    });

    if (newEmailError != null ||
        newPasswordError != null ||
        newPasswordConfirmError != null) {
      return;
    }

    setState(() {
      isEmailLoading = true;
    });

    try {
      // --------------------------------------------------------
      // Supabase 회원가입 요청
      // --------------------------------------------------------

      final response = await Supabase.instance.client.auth.signUp(
        email: email,

        password: password,

        // 이메일 인증 링크를 누른 뒤
        // S-TAP 앱으로 돌아오기 위한 딥링크
        emailRedirectTo: 'stap://login-callback/',
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // 이미 가입된 계정 가능성 확인
      // --------------------------------------------------------
      //
      // Supabase는 이메일 존재 여부를 노출하지 않기 위해
      // 이미 등록된 사용자에 대해 명확한 오류 대신
      // identities가 비어 있는 User 응답을 반환할 수 있습니다.
      //
      // 이 경우 인증메일 안내 화면으로 넘어가지 않고
      // 중앙 팝업으로 로그인하도록 안내합니다.
      // --------------------------------------------------------

      final identities = response.user?.identities;

      if (identities != null && identities.isEmpty) {
        _showAccountExistsDialog();

        return;
      }

      // --------------------------------------------------------
      // 신규 회원가입
      // --------------------------------------------------------

      if (response.session == null) {
        // Confirm email이 켜져 있으면
        // 인증 전에는 session이 null입니다.

        setState(() {
          emailSent = true;
        });
      } else {
        // Confirm email이 꺼져 있는 경우
        // 바로 로그인 세션이 만들어집니다.

        _showMessage('회원가입이 완료되었습니다.');
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = '회원가입 중 문제가 발생했습니다.';

      final lower = e.message.toLowerCase();

      // --------------------------------------------------------
      // 중복 계정 관련 오류
      // --------------------------------------------------------

      if (lower.contains('already registered') ||
          lower.contains('already exists') ||
          lower.contains('user already')) {
        _showAccountExistsDialog();

        return;
      }
      // --------------------------------------------------------
      // 비밀번호 관련 오류
      // --------------------------------------------------------
      else if (lower.contains('password')) {
        message = '비밀번호를 다시 확인해 주세요.';
      }
      // --------------------------------------------------------
      // 이메일 관련 오류
      // --------------------------------------------------------
      else if (lower.contains('email')) {
        message = '이메일 주소를 다시 확인해 주세요.';
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('서버와 연결하는 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          isEmailLoading = false;
        });
      }
    }
  }

  // ============================================================
  // Google 회원가입
  // ============================================================

  Future<void> _continueWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,

        redirectTo: 'stap://login-callback/',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Google 인증을 시작하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  // ============================================================
  // 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFB),

      appBar: AppBar(
        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        elevation: 0,

        title: const Text(
          '회원가입',
          style: TextStyle(fontWeight: FontWeight.w900, color: dark),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'S-TAP 시작하기',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '나에게 편한 방법으로 계정을 만들어 주세요.\n'
                '가입 후 S-TAP에서 사용할 닉네임을 설정할 수 있습니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF707572),
                ),
              ),

              const SizedBox(height: 28),

              if (emailSent) _buildEmailSentCard() else _buildSignupCard(),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text(
                    '이미 계정이 있으신가요?',
                    style: TextStyle(color: Color(0xFF777777)),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },

                    child: const Text(
                      '로그인',

                      style: TextStyle(
                        color: primary,

                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'S-TAP은 전문 의료 서비스를 대체하지 않습니다.',

                  textAlign: TextAlign.center,

                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 회원가입 카드
  // ============================================================

  Widget _buildSignupCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(28),

        border: Border.all(color: const Color(0xFFE1E4E3)),

        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),

            blurRadius: 20,

            offset: Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ====================================================
          // Google
          // ====================================================

          SizedBox(
            width: double.infinity,

            height: 58,

            child: OutlinedButton(
              onPressed: isGoogleLoading ? null : _continueWithGoogle,

              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,

                side: const BorderSide(color: Color(0xFFDADADA)),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),

              child: isGoogleLoading
                  ? const SizedBox(
                      width: 23,

                      height: 23,

                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,

                        color: primary,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Text(
                          'G',

                          style: TextStyle(
                            color: Color(0xFF4285F4),

                            fontSize: 21,

                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        SizedBox(width: 12),

                        Text(
                          'Google로 가입하기',

                          style: TextStyle(
                            color: dark,

                            fontSize: 16,

                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),

          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE0E0E0))),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),

                child: Text(
                  '또는 이메일로 가입',

                  style: TextStyle(
                    color: Color(0xFF888888),

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Expanded(child: Divider(color: Color(0xFFE0E0E0))),
            ],
          ),

          const SizedBox(height: 26),

          // ====================================================
          // 이메일
          // ====================================================
          const Text(
            '이메일 주소',

            style: TextStyle(
              fontSize: 15,

              fontWeight: FontWeight.w800,

              color: dark,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: emailController,

            keyboardType: TextInputType.emailAddress,

            enabled: !isEmailLoading,

            onChanged: (_) {
              if (emailError != null) {
                setState(() {
                  emailError = null;
                });
              }
            },

            decoration: _inputDecoration(
              hint: 'example@email.com',

              icon: Icons.mail_outline,

              errorText: emailError,
            ),
          ),

          const SizedBox(height: 20),

          // ====================================================
          // 비밀번호
          // ====================================================
          const Text(
            '비밀번호',

            style: TextStyle(
              fontSize: 15,

              fontWeight: FontWeight.w800,

              color: dark,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: passwordController,

            obscureText: obscurePassword,

            enabled: !isEmailLoading,

            onChanged: (_) {
              if (passwordError != null) {
                setState(() {
                  passwordError = null;
                });
              }
            },

            decoration:
                _inputDecoration(
                  hint: '비밀번호 입력',

                  icon: Icons.lock_outline,

                  errorText: passwordError,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },

                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
          ),

          const SizedBox(height: 8),

          const Text(
            '영문과 숫자를 포함해 8자 이상 입력해 주세요. '
            '특수문자도 사용할 수 있습니다.',

            style: TextStyle(
              fontSize: 12,

              height: 1.4,

              color: Color(0xFF808583),
            ),
          ),

          const SizedBox(height: 18),

          // ====================================================
          // 비밀번호 확인
          // ====================================================
          const Text(
            '비밀번호 확인',

            style: TextStyle(
              fontSize: 15,

              fontWeight: FontWeight.w800,

              color: dark,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: passwordConfirmController,

            obscureText: obscurePasswordConfirm,

            enabled: !isEmailLoading,

            onChanged: (_) {
              if (passwordConfirmError != null) {
                setState(() {
                  passwordConfirmError = null;
                });
              }
            },

            decoration:
                _inputDecoration(
                  hint: '비밀번호 다시 입력',

                  icon: Icons.lock_reset_outlined,

                  errorText: passwordConfirmError,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePasswordConfirm = !obscurePasswordConfirm;
                      });
                    },

                    icon: Icon(
                      obscurePasswordConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
          ),

          const SizedBox(height: 26),

          // ====================================================
          // 이메일 인증 안내
          // ====================================================
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: const Color(0xFFECFFF7),

              borderRadius: BorderRadius.circular(17),

              border: Border.all(color: const Color(0xFFA5EED3)),
            ),

            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.mark_email_read_outlined, color: primary),

                SizedBox(width: 11),

                Expanded(
                  child: Text(
                    '가입하기를 누르면 입력한 이메일로 '
                    '인증 링크를 보내드립니다. '
                    '메일에서 링크를 누르면 이메일 인증이 완료됩니다.\n\n'
                    '다른 기기에서 인증한 경우에는 '
                    '인증을 마친 뒤 S-TAP으로 돌아와 로그인해주세요.',

                    style: TextStyle(
                      height: 1.5,

                      fontSize: 13,

                      color: Color(0xFF4F5D58),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ====================================================
          // 이메일 가입 버튼
          // ====================================================
          SizedBox(
            width: double.infinity,

            height: 58,

            child: FilledButton(
              onPressed: isEmailLoading ? null : _signUpWithEmail,

              style: FilledButton.styleFrom(
                backgroundColor: primary,

                disabledBackgroundColor: const Color(0xFFB8C4C0),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),

              child: isEmailLoading
                  ? const SizedBox(
                      width: 23,

                      height: 23,

                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,

                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '이메일로 가입하기',

                      style: TextStyle(
                        fontSize: 16,

                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 이메일 인증 메일 발송 완료 카드
  // ============================================================

  Widget _buildEmailSentCard() {
    final email = emailController.text.trim();

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(26),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(28),

        border: Border.all(color: const Color(0xFFE1E4E3)),

        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),

            blurRadius: 20,

            offset: Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        children: [
          Container(
            width: 78,

            height: 78,

            decoration: const BoxDecoration(
              color: Color(0xFFE8FFF6),

              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.mark_email_read_outlined,

              color: primary,

              size: 38,
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            '인증 메일을 보냈어요',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 23,

              fontWeight: FontWeight.w900,

              color: dark,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            email,

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: primaryDark,

              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            '메일함에서 S-TAP 인증 메일을 확인한 뒤\n'
            '인증 링크를 눌러 주세요.\n\n'
            'S-TAP이 설치된 기기에서 링크를 열면\n'
            '앱으로 다시 돌아올 수 있어요.\n\n'
            'PC 등 다른 기기에서 인증했다면\n'
            '인증 완료 후 S-TAP으로 돌아와 로그인해주세요.',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 14,

              height: 1.6,

              color: Color(0xFF666C69),
            ),
          ),

          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,

            height: 56,

            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },

              style: FilledButton.styleFrom(
                backgroundColor: dark,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),

              child: const Text(
                '로그인 화면으로 돌아가기',

                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: () {
              setState(() {
                emailSent = false;

                passwordController.clear();

                passwordConfirmController.clear();
              });
            },

            child: const Text(
              '다른 이메일로 가입하기',

              style: TextStyle(color: primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 입력창 스타일
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,

      errorText: errorText,

      hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),

      errorStyle: const TextStyle(
        color: errorColor,

        fontWeight: FontWeight.w600,
      ),

      prefixIcon: Icon(
        icon,

        color: errorText != null ? errorColor : const Color(0xFF999999),
      ),

      filled: true,

      fillColor: const Color(0xFFFCFCFC),

      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(
          color: errorText != null ? errorColor : const Color(0xFFDDDFDE),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(
          color: errorText != null ? errorColor : primary,

          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: const BorderSide(color: errorColor, width: 1.8),
      ),
    );
  }

  // ============================================================
  // 기존 계정 안내 팝업
  // ============================================================

  void _showAccountExistsDialog() {
    showDialog(
      context: context,

      barrierDismissible: true,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 18),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Container(
                width: 58,

                height: 58,

                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),

                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.error_outline_rounded,

                  color: errorColor,

                  size: 32,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '이미 가입된 계정일 수 있어요',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 18,

                  fontWeight: FontWeight.w900,

                  color: errorColor,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '로그인 화면에서 다시 시도해주세요.',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 14,

                  height: 1.5,

                  color: Color(0xFF555B58),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,

                height: 50,

                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },

                  style: FilledButton.styleFrom(
                    backgroundColor: primary,

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),

                  child: const Text(
                    '확인',

                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 안내 메시지
  // ============================================================

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

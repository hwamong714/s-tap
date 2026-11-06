import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color primary = Color(0xFF00A87E);
  static const Color dark = Color(0xFF151515);
  static const Color errorColor = Color(0xFFE14B5A);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? emailError;
  String? passwordError;

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // 이메일 형식 확인
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  // ============================================================
  // 로그인
  // ============================================================

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    String? newEmailError;
    String? newPasswordError;

    if (email.isEmpty) {
      newEmailError = '이메일 주소를 입력해 주세요.';
    } else if (!_isValidEmail(email)) {
      newEmailError = '올바른 이메일 주소를 입력해 주세요.';
    }

    if (password.isEmpty) {
      newPasswordError = '비밀번호를 입력해 주세요.';
    }

    setState(() {
      emailError = newEmailError;
      passwordError = newPasswordError;
    });

    if (newEmailError != null || newPasswordError != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인에 성공했습니다.')));
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = '로그인에 실패했습니다.';

      final lowerMessage = e.message.toLowerCase();

      if (lowerMessage.contains('invalid login') ||
          lowerMessage.contains('invalid credentials')) {
        message = '이메일 또는 비밀번호를 확인해 주세요.';
      } else if (lowerMessage.contains('email not confirmed')) {
        message = '이메일 인증이 완료되지 않았습니다.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('서버와 연결하는 중 문제가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // 비밀번호 재설정 이메일 입력 팝업
  // ============================================================

  Future<void> _showPasswordResetDialog() async {
    final currentEmail = emailController.text.trim();

    final resetEmailController = TextEditingController(
      text: _isValidEmail(currentEmail) ? currentEmail : '',
    );

    bool isSending = false;
    String? resetEmailError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendResetEmail() async {
              final email = resetEmailController.text.trim();

              if (email.isEmpty) {
                setDialogState(() {
                  resetEmailError = '이메일 주소를 입력해 주세요.';
                });

                return;
              }

              if (!_isValidEmail(email)) {
                setDialogState(() {
                  resetEmailError = '올바른 이메일 주소를 입력해 주세요.';
                });

                return;
              }

              setDialogState(() {
                resetEmailError = null;
                isSending = true;
              });

              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  email,
                  redirectTo: 'stap://login-callback/',
                );

                if (!mounted) return;

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                _showPasswordResetSentDialog(email);
              } on AuthException catch (e) {
                if (!dialogContext.mounted) return;

                final lower = e.message.toLowerCase();

                setDialogState(() {
                  isSending = false;

                  if (lower.contains('rate limit')) {
                    resetEmailError = '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
                  } else {
                    resetEmailError = '재설정 메일을 보내지 못했습니다. 잠시 후 다시 시도해 주세요.';
                  }
                });
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isSending = false;
                  resetEmailError = '서버와 연결하는 중 문제가 발생했습니다.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8FFF6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: primary,
                      size: 34,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    '비밀번호 재설정',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: dark,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    '가입할 때 사용한 이메일 주소를 입력해 주세요.\n'
                    '비밀번호를 새로 설정할 수 있는 링크를 보내드릴게요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF666C69),
                    ),
                  ),

                  const SizedBox(height: 22),

                  TextField(
                    controller: resetEmailController,
                    enabled: !isSending,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    onChanged: (_) {
                      if (resetEmailError != null) {
                        setDialogState(() {
                          resetEmailError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      errorText: resetEmailError,
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        color: resetEmailError != null
                            ? errorColor
                            : const Color(0xFF999999),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFCFCFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: resetEmailError != null
                              ? errorColor
                              : const Color(0xFFDDDFDE),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: resetEmailError != null ? errorColor : primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: errorColor,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: errorColor,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isSending ? null : sendResetEmail,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: const Color(0xFFB8C4C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '재설정 메일 보내기',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  TextButton(
                    onPressed: isSending
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    resetEmailController.dispose();
  }

  // ============================================================
  // 재설정 메일 발송 완료 팝업
  // ============================================================

  void _showPasswordResetSentDialog(String email) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8FFF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: primary,
                  size: 34,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '메일을 확인해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                '재설정 가능한 계정이라면 입력한 이메일로\n'
                '비밀번호 재설정 안내 메일을 보내드렸어요.\n\n'
                '메일의 링크를 눌러 비밀번호 변경을 계속해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFF666C69),
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
  // Google 로그인
  // ============================================================

  Future<void> _continueWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'stap://login-callback/',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Google 로그인에 실패했습니다.\n$e')));
    }
  }

  // ============================================================
  // 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            children: [
              const SizedBox(height: 5),

              // S-TAP 로고
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2200A87E),
                      blurRadius: 25,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'S-TAP',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: dark,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                '나의 일상을 다시 이어가는 연습',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Color(0xFF777D7A),
                ),
              ),

              const SizedBox(height: 34),

              // ==================================================
              // 로그인 카드
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE0E3E2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 25,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ============================================
                    // 로그인 / 회원가입 탭
                    // ============================================

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 58,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: dark,
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: const SizedBox(
                                height: 58,
                                child: Center(
                                  child: Text(
                                    '회원가입',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ============================================
                    // 안심 보장
                    // ============================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFFF7),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF80E7C5)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: primary, size: 28),

                          SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '안심 보장',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: dark,
                                  ),
                                ),

                                SizedBox(height: 7),

                                Text(
                                  '편안한 닉네임으로 이용할 수 있으며,\n'
                                  '개인정보와 기록은 안전하게 보호됩니다.',
                                  style: TextStyle(
                                    height: 1.5,
                                    fontSize: 13,
                                    color: Color.fromARGB(255, 97, 104, 104),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ============================================
                    // 이메일
                    // ============================================
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '이메일 주소',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: dark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
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

                    const SizedBox(height: 22),

                    // ============================================
                    // 비밀번호
                    // ============================================
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '비밀번호',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: dark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
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

                    const SizedBox(height: 14),

                    // ============================================
                    // 비밀번호 재설정
                    // ============================================
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _showPasswordResetDialog,
                        child: const Text(
                          '비밀번호를 잊으셨나요?',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ============================================
                    // 일반 로그인 버튼
                    // ============================================
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: isLoading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: dark,
                          disabledBackgroundColor: const Color(0xFF777777),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '로그인하고 시작하기',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),

                                  SizedBox(width: 14),

                                  Icon(Icons.arrow_forward),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============================================
                    // 또는
                    // ============================================
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFE0E0E0))),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '또는',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ============================================
                    // Google 로그인
                    // ============================================
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton(
                        onPressed: _continueWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFDADADA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            SizedBox(width: 12),

                            Text(
                              'Google로 계속하기',
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

                    const SizedBox(height: 18),

                    // ============================================
                    // 회원가입 바로가기
                    // ============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '아직 계정이 없으신가요?',
                          style: TextStyle(color: Color(0xFF777777)),
                        ),

                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'S-TAP은 전문 의료 서비스를 대체하지 않습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 입력창 디자인
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,

      prefixIcon: Icon(
        icon,
        color: errorText != null ? errorColor : const Color(0xFF999999),
      ),

      hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),

      errorStyle: const TextStyle(
        color: errorColor,
        fontWeight: FontWeight.w600,
      ),

      filled: true,
      fillColor: const Color(0xFFFCFCFC),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: errorText != null ? errorColor : const Color(0xFFDDDFDE),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: errorText != null ? errorColor : primary,
          width: 1.6,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: errorColor, width: 1.8),
      ),
    );
  }
}

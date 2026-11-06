import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  final Future<void> Function() onFinished;

  const ResetPasswordScreen({super.key, required this.onFinished});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const Color primary = Color(0xFF00A87E);
  static const Color dark = Color(0xFF151515);
  static const Color errorColor = Color(0xFFE14B5A);

  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  String? passwordError;
  String? passwordConfirmError;

  bool obscurePassword = true;
  bool obscurePasswordConfirm = true;
  bool isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    passwordConfirmController.dispose();

    super.dispose();
  }

  // ============================================================
  // 비밀번호 검사
  // ============================================================

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return '새 비밀번호를 입력해 주세요.';
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
  // 비밀번호 변경
  // ============================================================

  Future<void> _updatePassword() async {
    final password = passwordController.text;
    final passwordConfirm = passwordConfirmController.text;

    final newPasswordError = _validatePassword(password);

    String? newPasswordConfirmError;

    if (passwordConfirm.isEmpty) {
      newPasswordConfirmError = '새 비밀번호를 다시 입력해 주세요.';
    } else if (password != passwordConfirm) {
      newPasswordConfirmError = '비밀번호가 일치하지 않습니다.';
    }

    setState(() {
      passwordError = newPasswordError;
      passwordConfirmError = newPasswordConfirmError;
    });

    if (newPasswordError != null || newPasswordConfirmError != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      await _showSuccessDialog();
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = '비밀번호를 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.';

      final lower = e.message.toLowerCase();

      if (lower.contains('password')) {
        message = '사용할 수 없는 비밀번호입니다. 다시 입력해 주세요.';
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
  // 변경 완료 팝업
  // ============================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8FFF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: primary,
                  size: 36,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '비밀번호가 변경되었어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '새 비밀번호로 다시 로그인해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF666C69),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    await widget.onFinished();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '로그인 화면으로 돌아가기',
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
  // 재설정 취소
  // ============================================================

  Future<void> _cancelRecovery() async {
    if (isLoading) return;

    await widget.onFinished();
  }

  // ============================================================
  // 화면
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FFFB),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 40),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2200A87E),
                        blurRadius: 24,
                        offset: Offset(0, 9),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  '새 비밀번호 설정',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: dark,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  '앞으로 S-TAP 로그인에 사용할\n'
                  '새 비밀번호를 입력해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xFF707572),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                      const Text(
                        '새 비밀번호',
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
                        enabled: !isLoading,
                        onChanged: (_) {
                          if (passwordError != null) {
                            setState(() {
                              passwordError = null;
                            });
                          }
                        },
                        decoration:
                            _inputDecoration(
                              hint: '새 비밀번호 입력',
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
                        '영문과 숫자를 포함해 8자 이상 입력해 주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF808583),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        '새 비밀번호 확인',
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
                        enabled: !isLoading,
                        onChanged: (_) {
                          if (passwordConfirmError != null) {
                            setState(() {
                              passwordConfirmError = null;
                            });
                          }
                        },
                        onSubmitted: (_) {
                          if (!isLoading) {
                            _updatePassword();
                          }
                        },
                        decoration:
                            _inputDecoration(
                              hint: '새 비밀번호 다시 입력',
                              icon: Icons.lock_reset_outlined,
                              errorText: passwordConfirmError,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePasswordConfirm =
                                        !obscurePasswordConfirm;
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

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: isLoading ? null : _updatePassword,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            disabledBackgroundColor: const Color(0xFFB8C4C0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '비밀번호 변경하기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: TextButton(
                          onPressed: isLoading ? null : _cancelRecovery,
                          child: const Text(
                            '취소하고 로그인으로 돌아가기',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontWeight: FontWeight.w700,
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
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
      errorStyle: const TextStyle(
        color: errorColor,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFFCFCFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
}

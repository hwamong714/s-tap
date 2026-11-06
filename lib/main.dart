import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/hq25_intro_screen.dart';
import 'screens/life_status_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ugfrrqgzxxikimnapaqv.supabase.co',
    publishableKey: 'sb_publishable_LpOpF42cBIJN5PpUYAR0yQ_dreieJW2',
  );

  runApp(const STapApp());
}

class STapApp extends StatelessWidget {
  const STapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'S-TAP',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A87E)),
        scaffoldBackgroundColor: const Color(0xFFF5FFFB),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// 로그인 / 비밀번호 복구 상태 확인
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  Session? _session;

  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();

    _session = Supabase.instance.client.auth.currentSession;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;

        setState(() {
          _session = data.session;

          // 비밀번호 재설정 링크를 통해 들어온 경우
          if (data.event == AuthChangeEvent.passwordRecovery) {
            _isPasswordRecovery = true;
          }

          // 로그아웃되면 복구 모드 종료
          if (data.event == AuthChangeEvent.signedOut) {
            _isPasswordRecovery = false;
          }
        });
      },
      onError: (_, _) {
        // 인증 스트림의 일시적인 네트워크 오류가
        // 앱 전체 오류로 이어지지 않도록 처리합니다.
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // 비밀번호 재설정 완료 또는 취소
  // ============================================================

  Future<void> _finishPasswordRecovery() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    setState(() {
      _isPasswordRecovery = false;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ========================================================
    // 비밀번호 재설정 링크로 들어온 사용자
    // ========================================================

    if (_isPasswordRecovery && _session != null) {
      return ResetPasswordScreen(onFinished: _finishPasswordRecovery);
    }

    // ========================================================
    // 로그인하지 않은 사용자
    // ========================================================

    if (_session == null) {
      return const LoginScreen();
    }

    // ========================================================
    // 일반 로그인 사용자
    // ========================================================

    return const UserStateGate();
  }
}

// ============================================================
// 사용자 진행 상태 확인
// ============================================================

class UserStateGate extends StatefulWidget {
  const UserStateGate({super.key});

  @override
  State<UserStateGate> createState() => _UserStateGateState();
}

class _UserStateGateState extends State<UserStateGate> {
  late Future<UserRouteState> _userStateFuture;

  @override
  void initState() {
    super.initState();

    _userStateFuture = _loadUserState();
  }

  Future<UserRouteState> _loadUserState() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const UserRouteState(
        profile: null,
        hasInitialHq25: false,
        hasInitialLifeStatus: false,
      );
    }

    // ========================================================
    // 1. 프로필 확인
    // ========================================================

    final profile = await Supabase.instance.client
        .from('profiles_v2')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    // 프로필이 없으면 아직 온보딩 전 상태
    if (profile == null) {
      return const UserRouteState(
        profile: null,
        hasInitialHq25: false,
        hasInitialLifeStatus: false,
      );
    }

    final onboardingCompleted = profile['onboarding_completed'] == true;

    // 온보딩이 끝나지 않았다면
    // 뒤의 검사 기록을 확인할 필요 없음
    if (!onboardingCompleted) {
      return UserRouteState(
        profile: profile,
        hasInitialHq25: false,
        hasInitialLifeStatus: false,
      );
    }

    // ========================================================
    // 2. 초기 HQ-25 검사 확인
    // ========================================================

    final initialHq25 = await Supabase.instance.client
        .from('hq25_assessments')
        .select('id')
        .eq('user_id', user.id)
        .eq('assessment_type', 'initial')
        .limit(1)
        .maybeSingle();

    final hasInitialHq25 = initialHq25 != null;

    // HQ-25를 아직 하지 않았다면
    // 생활상태 기록까지 확인할 필요 없음
    if (!hasInitialHq25) {
      return UserRouteState(
        profile: profile,
        hasInitialHq25: false,
        hasInitialLifeStatus: false,
      );
    }

    // ========================================================
    // 3. 초기 생활상태 확인
    // ========================================================

    final initialLifeStatus = await Supabase.instance.client
        .from('life_status_assessments')
        .select('id')
        .eq('user_id', user.id)
        .eq('assessment_type', 'initial')
        .limit(1)
        .maybeSingle();

    final hasInitialLifeStatus = initialLifeStatus != null;

    return UserRouteState(
      profile: profile,
      hasInitialHq25: hasInitialHq25,
      hasInitialLifeStatus: hasInitialLifeStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRouteState>(
      future: _userStateFuture,
      builder: (context, snapshot) {
        // ====================================================
        // 불러오는 중
        // ====================================================

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5FFFB),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00A87E)),
            ),
          );
        }

        // ====================================================
        // 오류 발생
        // ====================================================

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5FFFB),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '사용자 정보를 불러오는 중 오류가 발생했습니다.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final state = snapshot.data;

        if (state == null) {
          return const LoginScreen();
        }

        final profile = state.profile;

        // ====================================================
        // 프로필 없음
        // → 온보딩
        // ====================================================

        if (profile == null) {
          return const OnboardingScreen();
        }

        final onboardingCompleted = profile['onboarding_completed'] == true;

        // ====================================================
        // 온보딩 미완료
        // ====================================================

        if (!onboardingCompleted) {
          return const OnboardingScreen();
        }

        // ====================================================
        // HQ-25 초기검사 미완료
        // ====================================================

        if (!state.hasInitialHq25) {
          return const Hq25IntroScreen();
        }

        // ====================================================
        // HQ-25 완료
        // 생활상태 초기 입력 미완료
        // ====================================================

        if (!state.hasInitialLifeStatus) {
          return const LifeStatusScreen();
        }

        // ====================================================
        // 온보딩 + HQ-25 + 생활상태 모두 완료
        // ====================================================

        return const HomeScreen();
      },
    );
  }
}

// ============================================================
// 사용자 진행 상태 데이터
// ============================================================

class UserRouteState {
  final Map<String, dynamic>? profile;

  final bool hasInitialHq25;

  final bool hasInitialLifeStatus;

  const UserRouteState({
    required this.profile,
    required this.hasInitialHq25,
    required this.hasInitialLifeStatus,
  });
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// S-TAP 초기 HQ-25 결과 조회 화면
//
// - 최초 HQ-25 검사 결과 조회
// - 기존 검사 데이터 읽기 전용
// - 100점 만점 총점 표시
// - 기존 앱의 41점 선별 참고 기준 사용
// - 검사일 표시 (DB에 created_at이 있는 경우)
// - 의학적 진단이나 은둔 여부 확정 금지
// - 기존 검사 결과 수정 / 삭제 없음
// ============================================================

class InitialHq25ResultScreen extends StatefulWidget {
  const InitialHq25ResultScreen({super.key});

  @override
  State<InitialHq25ResultScreen> createState() =>
      _InitialHq25ResultScreenState();
}

class _InitialHq25ResultScreenState extends State<InitialHq25ResultScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color darkColor = Color(0xFF151918);

  // 기존 S-TAP 결과 화면에서 사용 중인 참고 기준
  static const int screeningCutoff = 41;

  late Future<Map<String, dynamic>?> _resultFuture;

  @override
  void initState() {
    super.initState();
    _resultFuture = _loadInitialResult();
  }

  // ==========================================================
  // 1. 최초 검사 결과 불러오기
  //
  // 현재 사용자 + assessment_type = initial
  // 조건으로 조회합니다.
  //
  // 저장된 결과를 수정하지 않습니다.
  // ==========================================================

  Future<Map<String, dynamic>?> _loadInitialResult() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw StateError('로그인 정보가 없습니다.');
    }

    final result = await supabase
        .from('hq25_assessments')
        .select()
        .eq('user_id', user.id)
        .eq('assessment_type', 'initial')
        .limit(1)
        .maybeSingle();

    return result;
  }

  // ==========================================================
  // 2. 다시 불러오기
  // ==========================================================

  void _reload() {
    setState(() {
      _resultFuture = _loadInitialResult();
    });
  }

  // ==========================================================
  // 3. 검사일 표시
  //
  // created_at 필드가 존재하면 사용합니다.
  // 없다면 날짜를 임의로 생성하지 않습니다.
  // ==========================================================

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) {
      return '검사일 정보 없음';
    }

    final parsed = DateTime.tryParse(rawDate.toString());

    if (parsed == null) {
      return '검사일 정보 없음';
    }

    final local = parsed.toLocal();

    return '${local.year}년 '
        '${local.month}월 '
        '${local.day}일';
  }

  // ==========================================================
  // 4. 총점 변환
  // ==========================================================

  int? _parseScore(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  // ==========================================================
  // 5. 검사 결과 설명
  //
  // 기존 결과 화면과 동일한 참고 기준을 사용하지만
  // 진단으로 해석하지 않습니다.
  // ==========================================================

  String _resultTitle(int score) {
    if (score >= screeningCutoff) {
      return '조금 더 살펴볼 필요가 있어요';
    }

    return '현재 상태를 확인했어요';
  }

  String _resultDescription(int score) {
    if (score >= screeningCutoff) {
      return '초기 검사 점수가 S-TAP에서 사용하는 '
          'HQ-25 선별 참고 기준인 41점 이상으로 나타났어요.\n\n'
          '하지만 이 결과만으로 은둔 상태나 '
          '정신건강 상태를 진단할 수는 없어요. '
          '현재 생활에서 느끼는 어려움을 이해하기 위한 '
          '참고자료로 활용해 주세요.';
    }

    return '초기 검사 점수가 S-TAP에서 사용하는 '
        'HQ-25 선별 참고 기준인 41점보다 낮게 나타났어요.\n\n'
        '점수가 기준보다 낮더라도 생활에서 '
        '어려움을 느낄 수 있어요. '
        '이 결과는 자신의 초기 상태를 '
        '이해하기 위한 참고자료예요.';
  }

  // ==========================================================
  // 6. 공통 카드
  // ==========================================================

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4ECE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ==========================================================
  // 7. 로딩 화면
  // ==========================================================

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: primaryColor));
  }

  // ==========================================================
  // 8. 오류 / 결과 없음 화면
  // ==========================================================

  Widget _buildMessageScreen({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryColor, size: 52),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 확인하기'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 9. 저장된 검사 결과 화면
  // ==========================================================

  Widget _buildResult(Map<String, dynamic> result) {
    final score = _parseScore(result['total_score']);

    if (score == null || score < 0 || score > 100) {
      return _buildMessageScreen(
        icon: Icons.info_outline_rounded,
        title: '점수 정보를 확인할 수 없어요',
        message: '저장된 초기 검사 점수를 읽지 못했어요.',
      );
    }

    final testDate = _formatDate(result['created_at']);

    final progress = (score / 100.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // 상단 제목
          // ----------------------------------------------------

          const Center(
            child: Text(
              '나의 첫 번째 기록',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: darkColor,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              'S-TAP을 처음 시작했을 때의 '
              'HQ-25 검사 결과예요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(height: 26),

          // ----------------------------------------------------
          // 총점 카드
          // ----------------------------------------------------
          _buildCard(
            child: Column(
              children: [
                const Text(
                  'HQ-25 초기 검사 총점',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 62,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.only(bottom: 7, left: 6),
                      child: Text(
                        '/ 100점',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE7F1ED),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7FBF3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '선별 참고 기준 · 41점',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Divider(),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      testDate,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // 결과 안내
          // ----------------------------------------------------
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: primaryColor,
                      size: 25,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        _resultTitle(score),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: darkColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  _resultDescription(score),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // 주의사항
          // ----------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 21,
                  color: Colors.grey.shade700,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    '이 결과는 최초 검사 당시의 응답을 '
                    '바탕으로 계산된 점수예요.\n\n'
                    '현재의 상태와 다를 수 있으며, '
                    '점수만으로 은둔 여부나 '
                    '정신건강 상태를 확정하지 않아요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ----------------------------------------------------
          // 마이페이지로 돌아가기
          // ----------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '마이페이지로 돌아가기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 10. 메인 화면
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          '초기 HQ-25 결과',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: darkColor,
          ),
        ),
      ),

      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _resultFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildLoading();
            }

            if (snapshot.hasError) {
              return _buildMessageScreen(
                icon: Icons.error_outline_rounded,
                title: '결과를 불러오지 못했어요',
                message:
                    '인터넷 연결과 로그인 상태를 '
                    '확인한 뒤 다시 시도해 주세요.',
              );
            }

            final result = snapshot.data;

            if (result == null) {
              return _buildMessageScreen(
                icon: Icons.assignment_outlined,
                title: '초기 검사 기록이 없어요',
                message:
                    '아직 저장된 HQ-25 초기 검사 '
                    '결과를 찾지 못했어요.',
              );
            }

            return _buildResult(result);
          },
        ),
      ),
    );
  }
}

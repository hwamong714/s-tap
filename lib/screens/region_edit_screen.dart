import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_options.dart';

class RegionEditScreen extends StatefulWidget {
  final String? regionLevel1;
  final String? regionLevel2;
  final String? regionLevel3;

  const RegionEditScreen({
    super.key,
    this.regionLevel1,
    this.regionLevel2,
    this.regionLevel3,
  });

  @override
  State<RegionEditScreen> createState() => _RegionEditScreenState();
}

class _RegionEditScreenState extends State<RegionEditScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF5FFFB);
  static const Color darkColor = Color(0xFF151918);

  final TextEditingController _searchController = TextEditingController();

  bool isSelecting = false;
  bool isSaving = false;

  // 0 = 시/도
  // 1 = 시/군/구
  // 2 = 구
  int currentStep = 0;

  String? selectedLevel1;
  String? selectedLevel2;
  String? selectedLevel3;

  String searchText = '';

  @override
  void initState() {
    super.initState();

    selectedLevel1 = widget.regionLevel1;
    selectedLevel2 = widget.regionLevel2;
    selectedLevel3 = widget.regionLevel3;

    _searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        searchText = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // 지역 데이터
  // ============================================================

  List<String> get _level1Options {
    return ProfileOptions.regionLevel2Data.keys.toList();
  }

  List<String> get _level2Options {
    if (selectedLevel1 == null) {
      return [];
    }

    return ProfileOptions.regionLevel2Data[selectedLevel1] ?? [];
  }

  List<String> get _level3Options {
    if (selectedLevel2 == null) {
      return [];
    }

    return ProfileOptions.regionLevel3Data[selectedLevel2] ?? [];
  }

  bool get _needsLevel2 {
    return _level2Options.isNotEmpty;
  }

  bool get _needsLevel3 {
    return _level3Options.isNotEmpty;
  }

  // ============================================================
  // 현재 표시 지역
  // ============================================================

  String get _currentRegionSummary {
    final parts = <String>[
      if (widget.regionLevel1 != null && widget.regionLevel1!.trim().isNotEmpty)
        widget.regionLevel1!.trim(),

      if (widget.regionLevel2 != null && widget.regionLevel2!.trim().isNotEmpty)
        widget.regionLevel2!.trim(),

      if (widget.regionLevel3 != null && widget.regionLevel3!.trim().isNotEmpty)
        widget.regionLevel3!.trim(),
    ];

    if (parts.isEmpty) {
      return '설정된 생활 지역 없음';
    }

    return parts.join(' ');
  }

  String get _selectedRegionSummary {
    final parts = <String>[
      if (selectedLevel1 != null && selectedLevel1!.trim().isNotEmpty)
        selectedLevel1!.trim(),

      if (selectedLevel2 != null && selectedLevel2!.trim().isNotEmpty)
        selectedLevel2!.trim(),

      if (selectedLevel3 != null && selectedLevel3!.trim().isNotEmpty)
        selectedLevel3!.trim(),
    ];

    return parts.join(' ');
  }

  // ============================================================
  // 현재 단계 목록
  // ============================================================

  List<String> get _currentOptions {
    switch (currentStep) {
      case 0:
        return _level1Options;

      case 1:
        return _level2Options;

      case 2:
        return _level3Options;

      default:
        return [];
    }
  }

  List<String> get _filteredOptions {
    if (searchText.isEmpty) {
      return _currentOptions;
    }

    return _currentOptions.where((item) {
      return item.contains(searchText);
    }).toList();
  }

  String? get _currentSelectedValue {
    switch (currentStep) {
      case 0:
        return selectedLevel1;

      case 1:
        return selectedLevel2;

      case 2:
        return selectedLevel3;

      default:
        return null;
    }
  }

  String get _searchHint {
    switch (currentStep) {
      case 0:
        return '시·도 이름을 검색해주세요.';

      case 1:
        return '시·군·구 이름을 검색해주세요.';

      case 2:
        return '구 이름을 검색해주세요.';

      default:
        return '지역명을 검색해주세요.';
    }
  }

  // ============================================================
  // 변경 시작
  // ============================================================

  void _startEditing() {
    setState(() {
      selectedLevel1 = widget.regionLevel1;
      selectedLevel2 = widget.regionLevel2;
      selectedLevel3 = widget.regionLevel3;

      currentStep = 0;
      isSelecting = true;

      searchText = '';
      _searchController.clear();
    });
  }

  // ============================================================
  // 지역 선택
  // ============================================================

  void _selectRegion(String value) {
    setState(() {
      switch (currentStep) {
        case 0:
          selectedLevel1 = value;

          // 시·도가 변경되면 하위 지역 초기화
          selectedLevel2 = null;
          selectedLevel3 = null;
          break;

        case 1:
          selectedLevel2 = value;

          // 시·군·구가 변경되면 일반구 초기화
          selectedLevel3 = null;
          break;

        case 2:
          selectedLevel3 = value;
          break;
      }
    });
  }

  // ============================================================
  // 이전 단계
  // ============================================================

  void _previousSelectionStep() {
    FocusScope.of(context).unfocus();

    if (currentStep == 0) {
      setState(() {
        isSelecting = false;
        searchText = '';
        _searchController.clear();
      });

      return;
    }

    setState(() {
      currentStep -= 1;

      searchText = '';
      _searchController.clear();
    });
  }

  // ============================================================
  // 다음
  // ============================================================

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();

    if (currentStep == 0) {
      if (selectedLevel1 == null) {
        _showMessage('시·도를 선택해주세요.');
        return;
      }

      // 세종특별자치시처럼 하위 지역이 없는 경우
      if (!_needsLevel2) {
        await _saveRegion();
        return;
      }

      setState(() {
        currentStep = 1;

        searchText = '';
        _searchController.clear();
      });

      return;
    }

    if (currentStep == 1) {
      if (selectedLevel2 == null) {
        _showMessage('시·군·구를 선택해주세요.');
        return;
      }

      if (_needsLevel3) {
        setState(() {
          currentStep = 2;

          searchText = '';
          _searchController.clear();
        });

        return;
      }

      await _saveRegion();
      return;
    }

    if (currentStep == 2) {
      if (selectedLevel3 == null) {
        _showMessage('구를 선택해주세요.');
        return;
      }

      await _saveRegion();
    }
  }

  // ============================================================
  // 버튼 활성화 여부
  // ============================================================

  bool get _canContinue {
    switch (currentStep) {
      case 0:
        return selectedLevel1 != null;

      case 1:
        return selectedLevel2 != null;

      case 2:
        return selectedLevel3 != null;

      default:
        return false;
    }
  }

  String get _bottomButtonText {
    if (currentStep == 0) {
      if (selectedLevel1 != null && !_needsLevel2) {
        return '저장하기';
      }

      return '다음';
    }

    if (currentStep == 1) {
      if (selectedLevel2 != null && !_needsLevel3) {
        return '저장하기';
      }

      return '다음';
    }

    return '저장하기';
  }

  // ============================================================
  // Supabase 저장
  // ============================================================

  Future<void> _saveRegion() async {
    if (isSaving) {
      return;
    }

    if (selectedLevel1 == null) {
      _showMessage('생활 지역을 선택해주세요.');
      return;
    }

    if (_needsLevel2 && selectedLevel2 == null) {
      _showMessage('시·군·구를 선택해주세요.');
      return;
    }

    if (_needsLevel3 && selectedLevel3 == null) {
      _showMessage('구를 선택해주세요.');
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
            'region_level1': selectedLevel1,
            'region_level2': selectedLevel2,
            'region_level3': selectedLevel3,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('생활 지역이 변경되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('생활 지역을 저장하지 못했습니다.\n$error');
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
                  if (isSelecting) {
                    _previousSelectionStep();
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
          '생활 지역 수정',
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
        child: isSelecting
            ? _buildSelectionScreen()
            : _buildCurrentRegionScreen(),
      ),
    );
  }

  // ============================================================
  // 현재 생활 지역 화면
  // ============================================================

  Widget _buildCurrentRegionScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // 안내 카드
                // ------------------------------------------------

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
                          Icons.location_on_rounded,
                          size: 31,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(width: 17),

                      const Expanded(
                        child: Text(
                          '생활 지역은\n'
                          '주변 맞춤 미션, 프로그램, 기관 정보를 '
                          '제공하기 위해 사용돼요.',
                          style: TextStyle(
                            fontSize: 13.5,
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
                  '현재 설정된 생활 지역',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A5350),
                  ),
                ),

                const SizedBox(height: 14),

                InkWell(
                  onTap: _startEditing,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 19,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 28,
                          color: Color(0xFF5A6864),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Text(
                            _currentRegionSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: darkColor,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 27,
                          color: Color(0xFF7E8884),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildBottomButton(
          text: '생활 지역 변경하기',
          enabled: true,
          onTap: _startEditing,
        ),
      ],
    );
  }

  // ============================================================
  // 지역 선택 화면
  // ============================================================

  Widget _buildSelectionScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // 검색
                // ------------------------------------------------

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _searchHint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                    ),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFDDE5E2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // 단계 표시
                // ------------------------------------------------
                _buildStepHeader(),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // 선택된 지역 경로
                // ------------------------------------------------
                if (_selectedRegionSummary.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 19,
                          color: primaryColor,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            _selectedRegionSummary,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E5D58),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                ],

                // ------------------------------------------------
                // 지역 목록
                // ------------------------------------------------
                if (_filteredOptions.isEmpty)
                  _buildEmptySearch()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredOptions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                    itemBuilder: (context, index) {
                      final item = _filteredOptions[index];

                      return _buildRegionItem(item);
                    },
                  ),
              ],
            ),
          ),
        ),

        _buildBottomButton(
          text: _bottomButtonText,
          enabled: _canContinue && !isSaving,
          loading: isSaving,
          onTap: _nextStep,
        ),
      ],
    );
  }

  // ============================================================
  // 단계 상단
  // ============================================================

  Widget _buildStepHeader() {
    final tabs = <_RegionStepTab>[
      _RegionStepTab(title: '시/도 선택', step: 0),
      _RegionStepTab(title: '시/군/구 선택', step: 1),

      if (_needsLevel3) _RegionStepTab(title: '구 선택', step: 2),
    ];

    return Row(
      children: tabs.map((tab) {
        final selected = currentStep == tab.step;
        final available = tab.step <= currentStep;

        return Expanded(
          child: InkWell(
            onTap: available
                ? () {
                    setState(() {
                      currentStep = tab.step;

                      searchText = '';
                      _searchController.clear();
                    });
                  }
                : null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    tab.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected ? primaryColor : Colors.grey.shade600,
                    ),
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? primaryColor : const Color(0xFFE7ECEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // 지역 선택 카드
  // ============================================================

  Widget _buildRegionItem(String item) {
    final selected = _currentSelectedValue == item;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _selectRegion(item);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE5FAF2) : const Color(0xFFF1F5F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryColor : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF4A5652),
                  ),
                ),
              ),

              if (selected) ...[
                const SizedBox(width: 6),

                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 검색 결과 없음
  // ============================================================

  Widget _buildEmptySearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 12),

            Text(
              '검색 결과가 없어요.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 하단 버튼
  // ============================================================

  Widget _buildBottomButton({
    required String text,
    required bool enabled,
    required FutureOr<void> Function() onTap,
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
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: enabled && !loading
                ? () async {
                    await onTap();
                  }
                : null,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF21D4B0), Color(0xFF00A87E)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
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
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionStepTab {
  final String title;
  final int step;

  const _RegionStepTab({required this.title, required this.step});
}

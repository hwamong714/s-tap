import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const Color primaryColor = Color(0xFF00A87E);
  static const Color backgroundColor = Color(0xFFF7FBF9);
  static const Color darkColor = Color(0xFF151918);

  final TextEditingController nicknameController = TextEditingController();

  final TextEditingController messageController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  bool isLoading = true;
  bool isSaving = false;

  String selectedMode = 'emoji';

  String selectedEmoji = '🌱';

  String? storedProfileImagePath;
  String? currentSignedImageUrl;

  Uint8List? pickedImageBytes;

  String? pickedImageExtension;
  String? pickedImageContentType;

  static const List<String> emojiOptions = ['🌱', '🙂', '😊', '😎', '🐰', '🐻'];

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  @override
  void dispose() {
    nicknameController.dispose();
    messageController.dispose();

    super.dispose();
  }

  // ============================================================
  // 현재 프로필 불러오기
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        _showMessage('로그인 정보를 확인할 수 없습니다.');

        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles_v2')
          .select(
            'nickname, '
            'message, '
            'avatar_type, '
            'avatar_emoji, '
            'profile_image_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final loadedNickname = profile?['nickname']?.toString() ?? '';

      final loadedMessage = profile?['message']?.toString() ?? '';

      final loadedAvatarType = profile?['avatar_type']?.toString() ?? 'emoji';

      final loadedAvatarEmoji = profile?['avatar_emoji']?.toString() ?? '🌱';

      final loadedProfileImagePath = profile?['profile_image_url']?.toString();

      String? signedUrl;

      if (loadedProfileImagePath != null &&
          loadedProfileImagePath.trim().isNotEmpty) {
        try {
          if (loadedProfileImagePath.startsWith('http://') ||
              loadedProfileImagePath.startsWith('https://')) {
            // 예전 URL 방식 데이터가 있다면
            // 그대로 표시하기 위한 호환 처리
            signedUrl = loadedProfileImagePath;
          } else {
            // Private Storage이므로
            // 화면 표시용 signed URL 생성
            signedUrl = await Supabase.instance.client.storage
                .from('profile-images')
                .createSignedUrl(loadedProfileImagePath, 60 * 60);
          }
        } catch (_) {
          signedUrl = null;
        }
      }

      if (!mounted) return;

      setState(() {
        nicknameController.text = loadedNickname;

        messageController.text = loadedMessage;

        selectedMode = loadedAvatarType == 'image' ? 'image' : 'emoji';

        selectedEmoji = loadedAvatarEmoji;

        storedProfileImagePath = loadedProfileImagePath;

        currentSignedImageUrl = signedUrl;

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage('프로필 정보를 불러오지 못했습니다.\n$error');
    }
  }

  // ============================================================
  // 사진 선택 + 1:1 크롭
  // ============================================================

  Future<void> _pickProfileImage() async {
    if (isSaving) return;

    try {
      // --------------------------------------------------------
      // 1. 갤러리에서 사진 선택
      // --------------------------------------------------------

      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        return;
      }

      // --------------------------------------------------------
      // 2. 선택한 사진 1:1 크롭
      // --------------------------------------------------------

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,

        // 프로필 사진은 1:1 비율로 고정
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),

        // 최종 저장 형식
        compressFormat: ImageCompressFormat.jpg,

        compressQuality: 90,

        // 프로필 사진에 과도한 해상도는 필요하지 않으므로 제한
        maxWidth: 1200,
        maxHeight: 1200,

        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '프로필 사진 편집',

            toolbarColor: primaryColor,

            toolbarWidgetColor: Colors.white,

            activeControlsWidgetColor: primaryColor,

            // 원형 프로필 영역
            cropStyle: CropStyle.circle,

            // 정사각형 고정
            initAspectRatio: CropAspectRatioPreset.square,

            lockAspectRatio: true,

            // 다른 비율 선택 방지
            aspectRatioPresets: [CropAspectRatioPreset.square],

            // 프로필 사진에서는 격자가 없어도 충분함
            showCropGrid: false,

            // 확대/축소 및 회전 컨트롤 유지
            hideBottomControls: false,
          ),

          IOSUiSettings(
            title: '프로필 사진 편집',

            doneButtonTitle: '완료',

            cancelButtonTitle: '취소',

            cropStyle: CropStyle.circle,

            aspectRatioLockEnabled: true,

            resetAspectRatioEnabled: false,

            aspectRatioPickerButtonHidden: true,

            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      // 사용자가 편집 화면에서 취소
      if (croppedFile == null) {
        return;
      }

      // --------------------------------------------------------
      // 3. 크롭 결과 읽기
      // --------------------------------------------------------

      final bytes = await croppedFile.readAsBytes();

      const maxBytes = 5 * 1024 * 1024;

      if (bytes.length > maxBytes) {
        if (!mounted) return;

        _showMessage('프로필 사진은 5MB 이하만 사용할 수 있어요.');

        return;
      }

      if (!mounted) return;

      // --------------------------------------------------------
      // 4. 미리보기용 상태 저장
      // --------------------------------------------------------

      setState(() {
        pickedImageBytes = bytes;

        // cropper 결과를 JPG로 통일했으므로
        // Supabase Storage에도 JPEG로 저장
        pickedImageExtension = 'jpg';

        pickedImageContentType = 'image/jpeg';

        selectedMode = 'image';
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('사진을 불러오거나 편집하는 중 오류가 발생했습니다.\n$error');
    }
  }

  // ============================================================
  // 프로필 저장
  // ============================================================

  Future<void> _saveProfile() async {
    if (isSaving) return;

    final nickname = nicknameController.text.trim();

    final message = messageController.text.trim();

    // --------------------------------------------------------
    // 입력값 검사
    // --------------------------------------------------------

    if (nickname.isEmpty) {
      _showMessage('닉네임을 입력해주세요.');

      return;
    }

    if (nickname.length > 12) {
      _showMessage('닉네임은 12자 이하로 입력해주세요.');

      return;
    }

    if (message.length > 50) {
      _showMessage('한마디는 50자 이하로 입력해주세요.');

      return;
    }

    if (selectedMode == 'image' &&
        pickedImageBytes == null &&
        (storedProfileImagePath == null ||
            storedProfileImagePath!.trim().isEmpty)) {
      _showMessage('프로필 사진을 선택해주세요.');

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

    String? newUploadedPath;

    try {
      String? finalImagePath = storedProfileImagePath;

      // --------------------------------------------------------
      // 새 사진이 있다면 Storage 업로드
      // --------------------------------------------------------

      if (selectedMode == 'image' &&
          pickedImageBytes != null &&
          pickedImageExtension != null &&
          pickedImageContentType != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        newUploadedPath =
            '${user.id}/profile_$timestamp'
            '.$pickedImageExtension';

        await Supabase.instance.client.storage
            .from('profile-images')
            .uploadBinary(
              newUploadedPath,
              pickedImageBytes!,
              fileOptions: FileOptions(
                contentType: pickedImageContentType,
                cacheControl: '3600',
                upsert: false,
              ),
            );

        finalImagePath = newUploadedPath;
      }

      // --------------------------------------------------------
      // profiles_v2 업데이트
      // --------------------------------------------------------

      final updateData = <String, dynamic>{
        'nickname': nickname,

        'message': message.isEmpty ? null : message,

        'avatar_type': selectedMode,

        'avatar_emoji': selectedEmoji,

        'updated_at': DateTime.now().toIso8601String(),
      };

      if (selectedMode == 'image') {
        updateData['profile_image_url'] = finalImagePath;
      }

      await Supabase.instance.client
          .from('profiles_v2')
          .update(updateData)
          .eq('id', user.id);

      // --------------------------------------------------------
      // 새 사진 저장 성공 후 이전 Storage 사진 제거
      // --------------------------------------------------------

      if (newUploadedPath != null &&
          storedProfileImagePath != null &&
          storedProfileImagePath!.trim().isNotEmpty &&
          storedProfileImagePath != newUploadedPath &&
          !storedProfileImagePath!.startsWith('http://') &&
          !storedProfileImagePath!.startsWith('https://')) {
        try {
          await Supabase.instance.client.storage.from('profile-images').remove([
            storedProfileImagePath!,
          ]);
        } catch (_) {
          // 기존 파일 삭제 실패는
          // 프로필 저장 자체에는 영향을 주지 않음
        }
      }

      if (!mounted) return;

      // true를 돌려주면 마이페이지에서
      // 데이터를 다시 불러옵니다.
      Navigator.pop(context, true);
    } catch (error) {
      // --------------------------------------------------------
      // DB 저장 실패 시 새로 업로드된 파일 정리
      // --------------------------------------------------------

      if (newUploadedPath != null) {
        try {
          await Supabase.instance.client.storage.from('profile-images').remove([
            newUploadedPath,
          ]);
        } catch (_) {
          // 정리 실패는 별도 처리하지 않음
        }
      }

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage('프로필을 저장하지 못했습니다.\n$error');
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

        centerTitle: true,

        leading: IconButton(
          onPressed: isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },

          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkColor),
        ),

        title: const Text(
          '프로필 수정',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfilePreview(),

                          const SizedBox(height: 24),

                          _buildModeSelector(),

                          const SizedBox(height: 24),

                          if (selectedMode == 'emoji')
                            _buildEmojiSection()
                          else
                            _buildPhotoSection(),

                          const SizedBox(height: 30),

                          _buildNicknameField(),

                          const SizedBox(height: 20),

                          _buildMessageField(),
                        ],
                      ),
                    ),
                  ),

                  _buildSaveArea(),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // 프로필 미리보기
  // ============================================================

  Widget _buildProfilePreview() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6EE),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.12),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatarPreview(),
              ),

              Positioned(
                right: 0,
                bottom: 4,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            '프로필 사진을 설정해보세요',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: darkColor,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            selectedMode == 'emoji'
                ? '나를 표현하는 이모지를 선택할 수 있어요.'
                : '사진을 원하는 위치와 크기로 조절할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    if (selectedMode == 'image') {
      if (pickedImageBytes != null) {
        return Image.memory(
          pickedImageBytes!,
          fit: BoxFit.cover,
          width: 132,
          height: 132,
        );
      }

      if (currentSignedImageUrl != null &&
          currentSignedImageUrl!.trim().isNotEmpty) {
        return Image.network(
          currentSignedImageUrl!,
          fit: BoxFit.cover,
          width: 132,
          height: 132,
          errorBuilder: (context, error, stackTrace) {
            return _buildEmojiPreview();
          },
        );
      }
    }

    return _buildEmojiPreview();
  }

  Widget _buildEmojiPreview() {
    return Center(
      child: Text(selectedEmoji, style: const TextStyle(fontSize: 62)),
    );
  }

  // ============================================================
  // 이모지 / 사진 탭
  // ============================================================

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _modeButton(
            mode: 'emoji',
            icon: Icons.eco_rounded,
            label: '이모지 선택',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _modeButton(
            mode: 'image',
            icon: Icons.image_outlined,
            label: '사진 업로드',
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String mode,
    required IconData icon,
    required String label,
  }) {
    final selected = selectedMode == mode;

    return InkWell(
      onTap: isSaving
          ? null
          : () {
              setState(() {
                selectedMode = mode;
              });
            },

      borderRadius: BorderRadius.circular(14),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),

        height: 52,

        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7FAF2) : Colors.white,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFDDE4E1),

            width: selected ? 1.5 : 1,
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? primaryColor : Colors.grey.shade600,
            ),

            const SizedBox(width: 8),

            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 이모지 선택
  // ============================================================

  Widget _buildEmojiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이모지 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 14),

        GridView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          itemCount: emojiOptions.length,

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),

          itemBuilder: (context, index) {
            final emoji = emojiOptions[index];

            final selected = emoji == selectedEmoji;

            return InkWell(
              onTap: isSaving
                  ? null
                  : () {
                      setState(() {
                        selectedEmoji = emoji;

                        selectedMode = 'emoji';
                      });
                    },

              borderRadius: BorderRadius.circular(18),

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),

                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE7FAF2) : Colors.white,

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(
                    color: selected ? primaryColor : const Color(0xFFE0E6E3),

                    width: selected ? 1.6 : 1,
                  ),
                ),

                alignment: Alignment.center,

                child: Text(emoji, style: const TextStyle(fontSize: 37)),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // 사진 업로드
  // ============================================================

  Widget _buildPhotoSection() {
    final hasImage =
        pickedImageBytes != null ||
        (currentSignedImageUrl != null &&
            currentSignedImageUrl!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,

          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(20),

            border: Border.all(color: const Color(0xFFDDE4E1)),
          ),

          child: Column(
            children: [
              Icon(
                hasImage
                    ? Icons.check_circle_outline_rounded
                    : Icons.image_outlined,

                color: hasImage ? primaryColor : Colors.grey.shade500,

                size: 36,
              ),

              const SizedBox(height: 12),

              Text(
                hasImage ? '선택한 사진을 사용할 수 있어요.' : '사진을 업로드해보세요',

                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'JPG, PNG · 최대 5MB',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 6),

              Text(
                '사진 선택 후 1:1 영역을 이동하고 확대·축소할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: isSaving ? null : _pickProfileImage,

                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE1F8EE),

                  foregroundColor: primaryColor,

                  elevation: 0,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                icon: const Icon(Icons.photo_library_outlined, size: 20),

                label: Text(
                  hasImage ? '다른 사진 선택' : '사진 선택하기',

                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 닉네임
  // ============================================================

  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '닉네임',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: nicknameController,

          enabled: !isSaving,

          maxLength: 12,

          textInputAction: TextInputAction.next,

          decoration: InputDecoration(
            hintText: '닉네임을 입력해주세요',

            counterText: '',

            filled: true,

            fillColor: Colors.white,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDDE4E1)),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDDE4E1)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,

          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: nicknameController,

            builder: (context, value, child) {
              return Text(
                '${value.text.length}/12',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 한마디
  // ============================================================

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '한마디',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: messageController,

          enabled: !isSaving,

          maxLength: 50,

          maxLines: 3,

          minLines: 2,

          decoration: InputDecoration(
            hintText: '나를 표현하는 한마디를 적어보세요.',

            counterText: '',

            filled: true,

            fillColor: Colors.white,

            contentPadding: const EdgeInsets.all(16),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDDE4E1)),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDDE4E1)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,

          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: messageController,

            builder: (context, value, child) {
              return Text(
                '${value.text.length}/50',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 저장 버튼
  // ============================================================

  Widget _buildSaveArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

      decoration: const BoxDecoration(
        color: backgroundColor,

        border: Border(top: BorderSide(color: Color(0xFFE3EBE7))),
      ),

      child: SizedBox(
        width: double.infinity,

        height: 58,

        child: FilledButton(
          onPressed: isSaving ? null : _saveProfile,

          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,

            foregroundColor: Colors.white,

            disabledBackgroundColor: primaryColor.withValues(alpha: 0.45),

            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),

          child: isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '저장하기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:mychat/core/network/api_client.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = false;
  String _avatarUrl = '';
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ref.read(apiClientProvider).getProfile();
      _nicknameCtrl.text = data['nickname'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      setState(() {
        _avatarUrl = data['avatar_url'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image == null) return;

    setState(() {
      _loading = true;
      _localAvatarPath = image.path;
    });

    try {
      final result = await ref.read(apiClientProvider).uploadFile(image.path);
      final url = result['url'] as String;

      await ref.read(apiClientProvider).updateProfile({'avatar_url': url});

      setState(() {
        _avatarUrl = url;
        _localAvatarPath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      setState(() => _localAvatarPath = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ImageProvider? _buildAvatarImage() {
    if (_localAvatarPath != null) {
      return FileImage(File(_localAvatarPath!));
    }
    if (_avatarUrl.isNotEmpty) {
      final url = _avatarUrl.startsWith('http')
          ? _avatarUrl
          : '${ApiConstants.baseUrlWindows}$_avatarUrl';
      return NetworkImage(url);
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).updateProfile({
        'nickname': _nicknameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      });
      final authBox = Hive.box('auth');
      await authBox.put('nickname', _nicknameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chat'),
        ),
        title: const Text('个人信息'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loading ? null : _pickAndUploadAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF07C160),
                    backgroundImage: _buildAvatarImage(),
                    child: (_localAvatarPath == null && _avatarUrl.isEmpty)
                        ? const Icon(Icons.camera_alt, color: Colors.white, size: 32)
                        : null,
                  ),
                  if (_loading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nicknameCtrl,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '个性签名',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

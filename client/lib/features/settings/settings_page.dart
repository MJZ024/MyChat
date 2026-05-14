import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _authBox = Hive.box('auth');
  final _settingsBox = Hive.box('settings');
  int _cacheCount = 0;
  late final int _uid = (_authBox.get('user_id') as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _cacheCount = PaintingBinding.instance.imageCache.currentSize;
  }

  void _updateCacheCount() {
    _cacheCount = PaintingBinding.instance.imageCache.currentSize;
    setState(() {});
  }

  String _key(String name) => '${_uid}_$name';

  T _get<T>(String key, T defaultValue) {
    final value = _settingsBox.get(_key(key));
    return value is T ? value : defaultValue;
  }

  void _set<T>(String key, T value) {
    _settingsBox.put(_key(key), value);
    setState(() {});
  }

  void _showFontSizeDialog() {
    final current = _get<int>('font_size', 1);
    final labels = ['小', '中', '大'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('字体大小'),
        children: List.generate(3, (i) {
          return RadioListTile<int>(
            title: Text(labels[i]),
            value: i,
            groupValue: current,
            onChanged: (v) {
              _set('font_size', v);
              Navigator.pop(ctx);
            },
          );
        }),
      ),
    );
  }

  void _showBgPicker() {
    final hasCustom = _get<String>('chat_bg_path', '').isNotEmpty;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('选择图片'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (!mounted) return;
                if (image != null) {
                  _set('chat_bg_path', image.path);
                }
              },
            ),
            if (hasCustom)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.red),
                title: const Text('恢复默认', style: TextStyle(color: Colors.red)),
                onTap: () {
                  _set('chat_bg_path', '');
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理缓存'),
        content: Text('当前图片缓存约 $_cacheCount 张，确定清除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              _updateCacheCount();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清理')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatBgPath = _get<String>('chat_bg_path', '');
    final hasCustomBg = chatBgPath.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // === 账号 ===
          const _SectionHeader('账号'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('个人信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.grey),
            title: const Text('修改密码', style: TextStyle(color: Colors.grey)),
            subtitle: const Text('即将推出', style: TextStyle(fontSize: 12)),
            enabled: false,
          ),
          const Divider(),

          // === 通知 ===
          const _SectionHeader('通知'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('消息通知'),
            value: _get<bool>('message_notification', true),
            onChanged: (v) => _set('message_notification', v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.preview_outlined),
            title: const Text('通知预览'),
            value: _get<bool>('notification_preview', true),
            onChanged: (v) => _set('notification_preview', v),
          ),
          const Divider(),

          // === 外观 ===
          const _SectionHeader('外观'),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('字体大小'),
            subtitle: Text(['小', '中', '大'][_get<int>('font_size', 1)]),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFontSizeDialog,
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('聊天背景'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showBgPicker,
          ),
          if (hasCustomBg)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(chatBgPath),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          const Divider(),

          // === 存储 ===
          const _SectionHeader('存储'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清理缓存'),
            subtitle: Text('图片缓存: $_cacheCount 张'),
            onTap: _showClearCacheDialog,
          ),
          const Divider(),

          // === 关于 ===
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本号'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('意见反馈'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('如有建议或问题，请发送邮件至项目维护者')),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

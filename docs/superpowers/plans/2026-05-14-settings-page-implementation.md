# 设置页面实现计划

> **For agentic workers:** 按任务顺序执行，每步完成后自检再继续。

**Goal:** 实现设置页面，包含账号/通知/外观/存储/关于五个分组

**Architecture:** 新增 SettingsPage (ConsumerStatefulWidget)，通过 Hive `settings` box 按用户隔离存储，chat_page 读取字体和背景设置

**Tech Stack:** Flutter + Riverpod + Hive + go_router + image_picker

---

### 文件规划

| 操作 | 文件 |
|------|------|
| 修改 | `client/lib/main.dart` — 打开 settings box |
| 新增 | `client/lib/features/settings/settings_page.dart` — 设置页面 |
| 修改 | `client/lib/router/app_router.dart` — 加 /settings 路由 |
| 修改 | `client/lib/features/chat/chat_list_page.dart` — 设置 onTap |
| 修改 | `client/lib/features/chat/chat_page.dart` — 读取字体/背景设置 |
| 修改 | `docs/PROGRESS.md` — 更新进度 |

---

### Task 1: 打开 settings Hive box

**Files:**
- 修改: `client/lib/main.dart:16-19`

- [ ] **Step 1: 在 main.dart 中打开 settings box**

```dart
  if (!Hive.isBoxOpen('auth')) {
    await Hive.openBox('auth');
  }
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox('settings');
  }
```

- [ ] **Step 2: 编译验证**

Run: `flutter build windows --debug`
Expected: Build 成功

---

### Task 2: 创建设置页面

**Files:**
- 创建: `client/lib/features/settings/settings_page.dart`

- [ ] **Step 1: 创建 settings_page.dart**

```dart
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
  int _cacheCount = 0;

  @override
  void initState() {
    super.initState();
    _updateCacheCount();
  }

  void _updateCacheCount() {
    setState(() {
      _cacheCount = PaintingBinding.instance.imageCache.currentSize;
    });
  }

  int get _uid {
    final box = Hive.box('auth');
    return box.get('user_id', defaultValue: 0) as int;
  }

  String _key(String name) => '${_uid}_$name';

  T _get<T>(String key, T defaultValue) {
    final box = Hive.box('settings');
    final value = box.get(_key(key));
    return value is T ? value : defaultValue;
  }

  void _set<T>(String key, T value) {
    final box = Hive.box('settings');
    box.put(_key(key), value);
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
```

需要补充 `import 'dart:io';` 在文件顶部（`File` 需要）。

- [ ] **Step 2: 编译验证**

Run: `flutter build windows --debug`
Expected: Build 成功

---

### Task 3: 添加路由

**Files:**
- 修改: `client/lib/router/app_router.dart`

- [ ] **Step 1: 加 import 和路由**

在 `app_router.dart` 顶部加：
```dart
import 'package:mychat/features/settings/settings_page.dart';
```

在 routes 列表中 `GoRoute(path: '/profile', ...` 之后加：

```dart
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsPage(),
),
```

- [ ] **Step 2: 编译验证**

Run: `flutter build windows --debug`
Expected: Build 成功

---

### Task 4: 接入设置入口

**Files:**
- 修改: `client/lib/features/chat/chat_list_page.dart:304-308`

- [ ] **Step 1: 修改设置 ListTile 的 onTap**

将：
```dart
ListTile(
  leading: const Icon(Icons.settings),
  title: const Text('设置'),
  onTap: () {},
),
```

改为：
```dart
ListTile(
  leading: const Icon(Icons.settings),
  title: const Text('设置'),
  onTap: () => context.push('/settings'),
),
```

- [ ] **Step 2: 编译验证**

Run: `flutter build windows --debug`
Expected: Build 成功

---

### Task 5: 聊天页读取字体和背景设置

**Files:**
- 修改: `client/lib/features/chat/chat_page.dart`

- [ ] **Step 1: 在 ChatPage build 方法中读取设置**

在 `_ChatPageState` 类中添加辅助方法，在 `build` 中用 `ValueListenableBuilder` 包裹或直接读取。

在 `build` 方法 Body 最外层用 `ValueListenableBuilder` 包裹：

```dart
// 在 build 的 body 部分最外层包裹
ValueListenableBuilder(
  valueListenable: Hive.box('settings').listenable(),
  builder: (context, box, child) {
    final uid = Hive.box('auth').get('user_id', defaultValue: 0);
    final chatBgPath = box.get('${uid}_chat_bg_path', defaultValue: '') as String;
    final fontSize = box.get('${uid}_font_size', defaultValue: 1) as int;
    final scale = [0.85, 1.0, 1.15][fontSize];

    return Stack(
      children: [
        if (chatBgPath.isNotEmpty)
          Positioned.fill(
            child: Image.file(File(chatBgPath), fit: BoxFit.cover),
          ),
        // 原 body 内容用 MediaQuery 传字体缩放
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ],
    );
  },
  child: /* 原 Scaffold body 的内容 */,
)
```

> 注意：`child!` 是原 `Scaffold` 的 body 内容（Column 包裹 Expanded + _buildInputBar 等）。
> 需要把原来 `Scaffold` 的 body 从返回值改为作为 `ValueListenableBuilder` 的 `child`。
> 需要 `import 'dart:io';` 和 `import 'package:hive_flutter/hive_flutter.dart';`

- [ ] **Step 2: 编译验证**

Run: `flutter build windows --debug`
Expected: Build 成功

---

### Task 6: 更新进度文档

**Files:**
- 修改: `docs/PROGRESS.md`

- [ ] **Step 1: 更新 PROGRESS.md**

在"功能缺口"部分，将设置页面从：
```
- [ ] 设置页面 — **完全缺失**，底部导航栏「设置」按钮回调为空
```
改为：
```
- [x] 设置页面 — 账号/通知/外观/存储/关于（通知开关 [~] 等 FCM 上线，修改密码 [o] 占位灰显）
```

---

### 验证清单

1. `flutter build windows --debug` 编译通过 (每次 task 都验证)
2. 设置入口可正常进入
3. 个人信息跳转正常
4. 修改密码灰显
5. 通知开关可切换并持久化
6. 字体大小对话框可选
7. 聊天背景可选图/恢复默认
8. 清理缓存可执行
9. 版本号和意见反馈显示正常
10. 聊天页读取字体缩放和背景生效

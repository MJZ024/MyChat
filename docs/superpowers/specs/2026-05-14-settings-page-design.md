# MyChat 设置页面设计方案

## 概述

新增设置页面，统一管理应用的账号、通知、外观、存储和关于信息。设置按用户隔离存储。

## 存储设计

### Hive Box: `settings`

Key 格式：`{user_id}_{config_name}`，实现用户级隔离。

| Key 模式 | 类型 | 默认值 | 说明 |
|----------|------|--------|------|
| `{uid}_message_notification` | bool | true | 新消息通知开关 |
| `{uid}_notification_preview` | bool | true | 通知是否显示消息内容 |
| `{uid}_font_size` | int | 1 | 字体大小：0=小, 1=中, 2=大 |
| `{uid}_chat_bg_path` | String | `''` | 聊天背景图片路径，空=默认 |

## 页面结构

```
设置（SettingsPage）
├── 账号
│   ├── 个人信息          → push('/profile')
│   └── 修改密码           灰显，subtitle "即将推出"
│
├── 通知
│   ├── 消息通知           Switch 开关 [~] 等 FCM 上线
│   └── 通知预览           Switch 开关 [~] 等 FCM 上线
│
├── 外观
│   ├── 字体大小           小 / 中 / 大 三选一弹窗
│   ├── 聊天背景           底部菜单：选择图片 / 恢复默认
│   └── 背景预览           缩略图，仅自定义背景时出现
│
├── 存储
│   └── 清理缓存           显示缓存大小 + 确认弹窗
│
├── 关于
│   ├── 版本号             1.0.0
│   └── 意见反馈           提示 "请发送邮件至..."
```

## 各功能实现说明

### 个人信息
跳转已有 `/profile` 路由，无需新增逻辑。

### 修改密码
灰色 ListTile，`enabled: false`，subtitle 显示"即将推出"。后续需服务端提供修改密码 API。

### 消息通知 / 通知预览
Switch 开关，修改后即时写入 Hive。当前 FCM 推送未上线，开关无效，标记 `[~]` 待后续接入。

### 字体大小
三选一弹窗（BottomSheet 或 SimpleDialog）。选中的值写入 Hive，聊天页读取 `font_size` 后乘以比例因子（如 0.85x / 1.0x / 1.15x）应用到消息文字。

### 聊天背景
- "选择图片"：调用 `image_picker`（已在 pubspec 依赖中），选完存路径到 Hive
- "恢复默认"：清空 Hive 中的路径
- 聊天页读取路径，有自定义背景时替换默认背景
- 自定义背景启用时，设置页显示缩略图预览

### 清理缓存
调用 `PaintingBinding.instance.imageCache.clear()` 清 Flutter 内存图片缓存，`imageCache.liveImageCount` 获取当前缓存数量。确认弹窗后执行，显示"已清理"提示。

### 版本号
硬编码为 `1.0.0`。

### 意见反馈
点击显示 SnackBar 或弹窗提示联系方式。

## 路由

- 新增路由 `/settings` → `SettingsPage()`
- 入口：`chat_list_page.dart` 左侧抽屉菜单"设置" `onTap`

## 文件清单

| 操作 | 文件 |
|------|------|
| 新增 | `client/lib/features/settings/settings_page.dart` |
| 修改 | `client/lib/router/app_router.dart` |
| 修改 | `client/lib/features/chat/chat_list_page.dart` |
| 修改 | `client/lib/features/chat/chat_page.dart` — 读取字体/背景设置 |
| 更新 | `docs/PROGRESS.md` |

## 依赖

无新增依赖。`image_picker`、`hive`、`flutter_riverpod`、`go_router` 均已在项目中。

## 进度标记约定

- 通知开关标记 `[~]` — UI 完成，等待 FCM 推送上线后生效
- 修改密码标记 `[o]` — 占位灰显，等待服务端 API
- 其余功能标记为 `[x]` — 完整实现

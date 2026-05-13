# MyChat

一个支持单聊、群聊、通讯录、多端同步的即时聊天系统。Flutter 客户端 + Go 后端。

## 技术栈

- **客户端**: Flutter 3.x (Android + Windows)
- **后端**: Go 1.22+ (Gin + gorilla/websocket)
- **数据库**: PostgreSQL 16 + Redis 7
- **对象存储**: MinIO
- **消息队列**: NATS
- **协议**: Protobuf over WebSocket
- **认证**: JWT (RS256)
- **加密**: Signal Protocol

## 项目结构

```
MyChat/
├── server/          # Go 后端
│   ├── cmd/         # 入口
│   ├── internal/    # 业务模块
│   ├── pkg/         # 公共包
│   ├── configs/     # 配置
│   └── deploy/      # Docker 部署
├── client/          # Flutter 客户端
│   └── lib/         # Dart 源码
├── shared/          # 共享 Protobuf 定义
└── docs/            # 文档
```

## 快速开始

### 前置依赖

- Go 1.22+
- Flutter 3.x (含 Android SDK + Windows 工具链)
- Docker + Docker Compose
- protoc + protoc-gen-go

### 启动基础设施

```bash
cd server/deploy
docker-compose up -d
```

### 启动后端

```bash
cd server
go run ./cmd/server
```

### 启动客户端

```bash
cd client
flutter pub get
flutter run -d windows    # Windows
flutter run -d <device>   # Android
```

## 开发进度

详见 [docs/PROGRESS.md](docs/PROGRESS.md)

- [x] Phase 1: 基础骨架（注册/登录、单聊文字消息）
- [~] Phase 2: 通讯录 + 富媒体 + 群聊（语音录音/视频未实现，其余未测）
- [~] Phase 3: 消息搜索/转发/回复已写未测，频道/推送/设置待开发
- [ ] Phase 4: E2E加密、阅后即焚、语音/视频通话、2FA、消息收藏

## 开发注意事项

### 配置文件

复制示例配置并填入本地环境信息：

```bash
cp server/configs/config.example.yaml server/configs/config.yaml
# 编辑 config.yaml，填入你的数据库密码、MinIO 密钥等
```

### 多开客户端测试

`lib/main.dart` 中 Hive 初始化改为按进程 PID 分离目录（仅在开发测试时使用）：

```dart
// 生产环境（单实例）：
// await Hive.initFlutter();

// 开发测试（可多开，进程隔离）：
final dataDir = Directory('${Directory.current.path}/.mychat_data/inst_$pid');
Hive.init(dataDir.path);
```

- 每个进程独立 Hive 存储，可同时登录不同账号互不干扰
- 关闭后 PID 变化，数据不持久（每次打开需重新登录）
- `.mychat_data/` 下会堆积历史目录，可定期手动清理
- 发布上线前应改回 `Hive.initFlutter()`

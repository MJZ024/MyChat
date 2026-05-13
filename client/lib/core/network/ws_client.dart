import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient();
});

class WsClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _channel != null;

  String get _wsUrl {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return ApiConstants.wsUrlWindows;
    }
    return ApiConstants.wsUrl;
  }

  Future<void> connect() async {
    if (_disposed || _channel != null) return;

    final authBox = Hive.box('auth');
    final token = authBox.get('access_token') as String?;
    if (token == null) return;

    try {
      final uri = Uri.parse('$_wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            try {
              final msg = jsonDecode(data) as Map<String, dynamic>;
              _messageController.add(msg);
            } catch (_) {
              debugPrint('[ws_client] JSON 解析失败: $data');
            }
          }
        },
        onError: (error) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );

      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(message));
  }

  void sendTyping(String toId, int chatType) {
    send({
      'type': 'typing',
      'data': {'to_id': toId, 'chat_type': chatType},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendMessage({
    required String toId,
    required int chatType,
    required int contentType,
    required String content,
    String? replyTo,
  }) {
    send({
      'type': 'send_message',
      'data': {
        'to_id': toId,
        'chat_type': chatType,
        'content_type': contentType,
        'content': content,
        if (replyTo != null) 'reply_to': replyTo,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendRecall(String msgId) {
    send({
      'type': 'message_recall',
      'data': {'msg_id': msgId},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendRead(String conversationId) {
    send({
      'type': 'message_read',
      'data': {'conversation_id': conversationId},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({
        'type': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts > 5 ? 30 : _reconnectAttempts * 2);
    _reconnectTimer = Timer(delay, connect);
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messageController.close();
  }
}

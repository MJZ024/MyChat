import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/core/network/ws_client.dart';

final messagesProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

int get currentUserId => Hive.box('auth').get('user_id', defaultValue: 0) as int;

class ChatPage extends ConsumerStatefulWidget {
  final int conversationId;
  final int peerUid;
  final String name;
  final String avatarUrl;
  final int chatType; // 0=single, 1=group

  const ChatPage({
    super.key,
    required this.conversationId,
    this.peerUid = 0,
    required this.name,
    required this.avatarUrl,
    this.chatType = 0,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isUploading = false;
  Map<String, dynamic>? _replyTo;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isOnline = false;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(messagesProvider.notifier).state = [];
    _loadHistory();
    _markRead();

    _wsSubscription = ref.read(wsClientProvider).messages.listen((msg) {
      if (!mounted) return;
      final type = msg['type'] as String?;

      if (type == 'recv_message') {
        final data = msg['data'] as Map<String, dynamic>? ?? msg;
        final msgToId = data['to_id']?.toString() ?? '';
        final fromUid = data['from_uid']?.toString() ?? '';
        final isForThisChat = widget.chatType == 1
            ? msgToId == '${widget.conversationId}'
            : (msgToId == '${widget.conversationId}' ||
                (widget.peerUid > 0 &&
                    (msgToId == '${widget.peerUid}' || fromUid == '${widget.peerUid}')));
        if (isForThisChat) {
          ref.read(messagesProvider.notifier).update((list) => [...list, data]);
          _scrollToBottom();
          _markRead();
        }
      } else if (type == 'typing') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final fromUid = data['from_uid'];
        // Show typing indicator for single chat
        if (fromUid != null && fromUid != currentUserId) {
          setState(() => _isTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isTyping = false);
          });
        }
      } else if (type == 'online_status') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        if (data['uid'] != null) {
          setState(() => _isOnline = data['online'] == true);
        }
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await ref.read(apiClientProvider).getMessages(widget.conversationId);
      final loaded = msgs.map((m) => m as Map<String, dynamic>).toList();
      ref.read(messagesProvider.notifier).state = loaded;
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载历史消息失败')),
        );
      });
    }
  }

  void _markRead() {
    ref.read(wsClientProvider).sendRead('${widget.conversationId}');
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0);
      }
    });
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      ref.read(wsClientProvider).sendTyping('${widget.conversationId}', widget.chatType);
    }
  }

  void _sendMessage({int contentType = 0, String content = ''}) {
    if (content.isEmpty && contentType == 0) {
      content = _msgCtrl.text.trim();
      if (content.isEmpty) return;
      _msgCtrl.clear();
    }

    final ws = ref.read(wsClientProvider);
    final toId = widget.chatType == 1
        ? '${widget.conversationId}'
        : '${widget.peerUid > 0 ? widget.peerUid : widget.conversationId}';
    ws.sendMessage(
      toId: toId,
      chatType: widget.chatType,
      contentType: contentType,
      content: content,
      replyTo: _replyTo?['msg_id']?.toString(),
    );

    // Don't add local temp message; server will push recv_message back via WS
    setState(() => _replyTo = null);
  }

  void _recallMessage(Map<String, dynamic> msg) {
    ref.read(wsClientProvider).sendRecall(msg['msg_id'] as String);

    ref.read(messagesProvider.notifier).update((list) {
      return list.map((m) {
        if (m['msg_id'] == msg['msg_id']) {
          return {...m, 'recalled': true};
        }
        return m;
      }).toList();
    });
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  void _startReply(Map<String, dynamic> msg) {
    setState(() => _replyTo = msg);
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  void _forwardMessage(Map<String, dynamic> msg) {
    _showForwardDialog([msg['msg_id'] as String].where((s) => !s.startsWith('temp_')).map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toList());
  }

  void _showForwardDialog(List<int> messageIds) {
    if (messageIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ForwardTargetSelector(
        onSelect: (targetConvId) async {
          Navigator.pop(ctx);
          try {
            await ref.read(apiClientProvider).forwardMessages(messageIds, targetConvId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('转发成功')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('转发失败')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final result = await ref.read(apiClientProvider).uploadFile(image.path);
      _sendMessage(contentType: 1, content: result['url'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片上传失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final file = result.files.first;
      if (file.path == null) return;
      final uploadResult = await ref.read(apiClientProvider).uploadFile(file.path!);
      _sendMessage(contentType: 3, content: uploadResult['url'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件上传失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachButton(
                icon: Icons.image,
                label: '图片',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              _AttachButton(
                icon: Icons.insert_drive_file,
                label: '文件',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
              _AttachButton(
                icon: Icons.mic,
                label: '语音',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(Map<String, dynamic> msg) {
    final isMe = msg['from_uid'] == currentUserId;
    final canRecall = isMe && msg['msg_id'] != null && !msg['msg_id'].toString().startsWith('temp_');
    final content = msg['content'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRecall)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤回'),
                onTap: () {
                  Navigator.pop(ctx);
                  _recallMessage(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(content);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('转发'),
              onTap: () {
                Navigator.pop(ctx);
                _forwardMessage(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: const TextStyle(fontSize: 16)),
            if (_isTyping)
              const Text('对方正在输入...',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.circle, size: 10, color: Colors.green[400]),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'search':
                  context.push('/search',
                      extra: {'conversation_id': widget.conversationId});
                  break;
                case 'detail':
                  context.push('/chat-detail', extra: {
                    'conversation_id': widget.conversationId,
                    'peer_uid': widget.peerUid,
                    'name': widget.name,
                    'avatar_url': widget.avatarUrl,
                    'chat_type': widget.chatType,
                  });
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('搜索消息')),
              PopupMenuItem(value: 'detail', child: Text('聊天详情')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(backgroundColor: Color(0xFF07C160)),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('暂无消息'))
                : ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      final isMe = msg['from_uid'] == currentUserId;
                      final recalled = msg['recalled'] == true;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        recalled: recalled,
                        isGroup: widget.chatType == 1,
                        onLongPress: () => _showMessageActions(msg),
                        onReplyTap: () {},
                      );
                    },
                  ),
          ),
          if (_replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '回复: ${_replyTo!['content'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          _InputBar(
            controller: _msgCtrl,
            onSend: () => _sendMessage(),
            onAttach: _showAttachMenu,
            onChanged: _onTextChanged,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool recalled;
  final bool isGroup;
  final VoidCallback onLongPress;
  final VoidCallback onReplyTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.recalled,
    required this.isGroup,
    required this.onLongPress,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            isMe ? '你撤回了一条消息' : '对方撤回了一条消息',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
      );
    }

    final content = message['content'] as String? ?? '';
    final contentType = message['content_type'] ?? 0;
    final replyPreview = message['reply_preview'] as String?;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isGroup && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 2),
                      child: Text(
                        message['from_nickname']?.toString() ?? '用户${message['from_uid']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  // Reply preview
                  if (replyPreview != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xFF07C160),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        replyPreview.length > 50 ? '${replyPreview.substring(0, 50)}...' : replyPreview,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Container(
                    padding: contentType == 0
                        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                        : const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF95EC69) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                      ],
                    ),
                    child: _buildContent(context, content, contentType),
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF07C160),
                child: const Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String content, int contentType) {
    switch (contentType) {
      case 1:
        final url = content.startsWith('http') ? content : '${ApiConstants.staticUrl}$content';
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 250),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            ),
          ),
        );
      case 2:
        return _VoiceMessage(content: content);
      case 3:
        return _FileMessage(url: content);
      default:
        return SelectableText(content, style: const TextStyle(fontSize: 15));
    }
  }
}

class _VoiceMessage extends StatefulWidget {
  final String content;
  const _VoiceMessage({required this.content});

  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.content.startsWith('http')
        ? widget.content
        : '${ApiConstants.staticUrl}${widget.content}';
    return GestureDetector(
      onTap: () async {
        if (_isPlaying) {
          await _player.stop();
          setState(() => _isPlaying = false);
        } else {
          setState(() => _isPlaying = true);
          await _player.play(UrlSource(url));
          _player.onPlayerComplete.listen((_) {
            if (mounted) setState(() => _isPlaying = false);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minWidth: 120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: const Color(0xFF07C160),
              size: 32,
            ),
            const SizedBox(width: 8),
            const Text('语音消息', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _FileMessage extends StatelessWidget {
  final String url;
  const _FileMessage({required this.url});

  @override
  Widget build(BuildContext context) {
    final fileName = url.split('/').last;
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 250),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 36, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('文件', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<String> onChanged;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: '消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF07C160)),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// Forward target selector widget
class _ForwardTargetSelector extends ConsumerStatefulWidget {
  final ValueChanged<int> onSelect;

  const _ForwardTargetSelector({required this.onSelect});

  @override
  ConsumerState<_ForwardTargetSelector> createState() => _ForwardTargetSelectorState();
}

class _ForwardTargetSelectorState extends ConsumerState<_ForwardTargetSelector> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('转发到', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Flexible(
            child: FutureBuilder<List<dynamic>>(
              future: ref.read(apiClientProvider).getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Text('暂无会话');
                }
                return ListView(
                  shrinkWrap: true,
                  children: list.map((c) {
                    final m = c as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (m['type'] ?? 1) == 2 ? Colors.blue : const Color(0xFF07C160),
                        child: Icon(
                          (m['type'] ?? 1) == 2 ? Icons.group : Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(m['name'] as String? ?? ''),
                      onTap: () {
                        final convId = m['conversation_id'];
                        if (convId is int) {
                          widget.onSelect(convId);
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

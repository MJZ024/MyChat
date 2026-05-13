import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/features/chat/chat_list_page.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final int conversationId;
  final int peerUid;
  final String name;
  final String avatarUrl;
  final int chatType; // 0=single, 1=group

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.peerUid = 0,
    required this.name,
    this.avatarUrl = '',
    this.chatType = 0,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  bool _pinned = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final data = await ref.read(apiClientProvider).getConversationState(widget.conversationId);
      if (mounted) setState(() {
        _pinned = data['pinned'] == true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = widget.avatarUrl.startsWith('http')
        ? widget.avatarUrl
        : widget.avatarUrl.isNotEmpty
            ? '${ApiConstants.baseUrlWindows}${widget.avatarUrl}'
            : '';

    return Scaffold(
      appBar: AppBar(title: const Text('聊天详情')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor:
                  widget.chatType == 1 ? Colors.blue : const Color(0xFF07C160),
              backgroundImage:
                  fullUrl.isNotEmpty ? CachedNetworkImageProvider(fullUrl) : null,
              child: fullUrl.isEmpty
                  ? Icon(
                      widget.chatType == 1 ? Icons.group : Icons.person,
                      size: 40,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(widget.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          if (widget.chatType == 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('群聊',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ),
            ),
          const SizedBox(height: 24),
          const Divider(),

          // Search
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('查找聊天记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push(
                  '/search', extra: {'conversation_id': widget.conversationId});
            },
          ),
          const Divider(indent: 56),

          // Contact info (single only)
          if (widget.chatType == 0) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('查看联系人'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/contact/${widget.peerUid}', extra: {
                  'nickname': widget.name,
                  'avatar_url': widget.avatarUrl,
                });
              },
            ),
            const Divider(indent: 56),
          ],

          // Group info (group only)
          if (widget.chatType == 1) ...[
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('群聊信息'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/group/${widget.conversationId}',
                    extra: {'name': widget.name});
              },
            ),
            const Divider(indent: 56),
          ],

          // Pin toggle
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: const Text('置顶聊天'),
            trailing: _loaded
                ? Switch(
                    value: _pinned,
                    onChanged: (v) => _togglePin(),
                    activeColor: const Color(0xFF07C160),
                  )
                : const SizedBox(
                    width: 40,
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const Divider(),

          // Clear chat
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
            title: const Text('清空聊天记录'),
            onTap: _confirmClearChat,
          ),
          // Delete / Leave
          ListTile(
            leading: Icon(
              widget.chatType == 1 ? Icons.exit_to_app : Icons.person_remove,
              color: Colors.red,
            ),
            title: Text(
              widget.chatType == 1 ? '退出群聊' : '删除好友',
              style: const TextStyle(color: Colors.red),
            ),
            onTap: widget.chatType == 1 ? _confirmLeaveGroup : _confirmDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin() async {
    try {
      final pinned = await ref.read(apiClientProvider).togglePin(widget.conversationId);
      if (mounted) {
        setState(() => _pinned = pinned);
        ref.invalidate(conversationsProvider);
      }
    } catch (_) {}
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('将清空该聊天的所有消息记录，此操作无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).clearMessages(widget.conversationId);
              ref.invalidate(conversationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) context.go('/chat');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除 ${widget.name} 吗？同时会清空聊天记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).deleteFriend(widget.peerUid);
              ref.invalidate(conversationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) context.go('/chat');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('退出后将不再接收此群聊的消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).leaveGroup(widget.conversationId);
              ref.invalidate(conversationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) context.go('/chat');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

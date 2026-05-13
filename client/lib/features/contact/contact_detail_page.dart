import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/features/chat/chat_list_page.dart';
import 'package:mychat/features/contact/contact_list_page.dart';

class ContactDetailPage extends ConsumerStatefulWidget {
  final int uid;
  final String nickname;
  final String avatarUrl;
  final String username;

  const ContactDetailPage({
    super.key,
    required this.uid,
    required this.nickname,
    this.avatarUrl = '',
    this.username = '',
  });

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ref.read(apiClientProvider).getUserPublic(widget.uid);
      if (mounted) setState(() => _bio = data['bio'] ?? '');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = widget.avatarUrl.startsWith('http')
        ? widget.avatarUrl
        : widget.avatarUrl.isNotEmpty
            ? '${ApiConstants.baseUrlWindows}${widget.avatarUrl}'
            : '';

    return Scaffold(
      appBar: AppBar(title: const Text('联系人详情')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF07C160),
              backgroundImage:
                  fullUrl.isNotEmpty ? CachedNetworkImageProvider(fullUrl) : null,
              child: fullUrl.isEmpty
                  ? Text(
                      widget.nickname.isNotEmpty ? widget.nickname[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(widget.nickname,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          if (widget.username.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('@${widget.username}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ),
            ),
          if (_bio.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_bio,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ),
            ),
          const SizedBox(height: 32),
          Consumer(builder: (context, ref, _) {
            final contacts = ref.watch(contactsProvider).valueOrNull ?? [];
            final isFriend = contacts.any((c) {
              final m = c as Map<String, dynamic>;
              return m['uid'] == widget.uid;
            });
            if (isFriend) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.chat, color: Color(0xFF07C160)),
                    title: const Text('发送消息'),
                    onTap: () async {
                      try {
                        final convId = await ref
                            .read(apiClientProvider)
                            .getOrCreateSingleConversation(widget.uid);
                        if (context.mounted) {
                          context.go('/chat/$convId', extra: {
                            'name': widget.nickname,
                            'avatar_url': widget.avatarUrl,
                            'peer_uid': widget.uid,
                          });
                        }
                      } catch (_) {}
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: const Text('删除好友', style: TextStyle(color: Colors.red)),
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              );
            } else {
              return ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xFF07C160)),
                title: const Text('添加好友'),
                onTap: () async {
                  try {
                    await ref.read(apiClientProvider).sendFriendRequest(widget.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('好友请求已发送')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('发送失败')),
                      );
                    }
                  }
                },
              );
            }
          }),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除 ${widget.nickname} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).deleteFriend(widget.uid);
              ref.invalidate(contactsProvider);
              ref.invalidate(conversationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.go('/chat');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

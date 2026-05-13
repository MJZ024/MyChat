import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mychat/core/network/api_client.dart';

final groupMembersProvider = FutureProvider.family<List<dynamic>, int>((ref, groupId) {
  return ref.watch(apiClientProvider).getGroupMembers(groupId);
});

class GroupDetailPage extends ConsumerWidget {
  final int groupId;
  final String groupName;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) async {
              switch (val) {
                case 'leave':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('退出群聊'),
                      content: Text('Leave "$groupName"?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('退出',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(apiClientProvider).leaveGroup(groupId);
                    if (context.mounted) Navigator.pop(context);
                  }
                  break;
                case 'invite':
                  _showInviteDialog(context, ref);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'invite', child: Text('Invite Member')),
              const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
            ],
          ),
        ],
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF07C160)),
                title: const Text('进入聊天'),
                onTap: () {
                  context.push('/chat/$groupId', extra: {
                    'name': groupName,
                    'avatar_url': '',
                    'peer_uid': 0,
                    'chat_type': 1,
                  });
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final m = list[index] as Map<String, dynamic>;
                    final role = m['role'] as int? ?? 0;
                    final roleLabel = role == 2 ? 'Owner' : (role == 1 ? 'Admin' : '');
                    final nickname = m['nickname'] ?? '';
                    final currentUid = Hive.box('auth').get('user_id', defaultValue: 0) as int;
                    final memberUid = m['uid'] as int? ?? 0;
                    final isMe = memberUid == currentUid;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF07C160),
                        child: Text(
                          nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(isMe ? '$nickname (我)' : nickname),
                      subtitle: Text('@${m['username'] ?? ''}'),
                      trailing: roleLabel.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF07C160).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(roleLabel,
                                  style: const TextStyle(
                                      color: Color(0xFF07C160), fontSize: 12)),
                            )
                          : null,
                      onTap: isMe
                          ? null
                          : () {
                              context.push('/contact/$memberUid', extra: {
                                'nickname': nickname.toString(),
                                'avatar_url': m['avatar_url']?.toString() ?? '',
                                'username': m['username']?.toString() ?? '',
                              });
                            },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请成员'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'User ID',
            hintText: 'Enter the user ID to invite',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final uid = int.tryParse(ctrl.text);
              if (uid != null) {
                try {
                  await ref.read(apiClientProvider).inviteMember(groupId, uid);
                  ref.invalidate(groupMembersProvider(groupId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member invited')),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('邀请失败')),
                    );
                  }
                }
              }
            },
            child: const Text('邀请',
                style: TextStyle(color: Color(0xFF07C160))),
          ),
        ],
      ),
    );
  }
}

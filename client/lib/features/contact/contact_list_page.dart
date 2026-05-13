import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/core/network/ws_client.dart';
import 'package:mychat/features/chat/chat_list_page.dart';

final contactsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(apiClientProvider).getContacts();
});

final pendingRequestsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(apiClientProvider).getPendingRequests();
});

final onlineStatusProvider = StateProvider<Map<int, bool>>((ref) => {});

class ContactListPage extends ConsumerStatefulWidget {
  const ContactListPage({super.key});

  @override
  ConsumerState<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends ConsumerState<ContactListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ref.read(wsClientProvider).messages.listen((msg) {
      final type = msg['type'] as String?;
      if (type == 'online_status') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final uid = data['uid'];
        final online = data['online'] == true;
        if (uid is int || uid is String) {
          final uidInt = uid is int ? uid : int.tryParse(uid) ?? 0;
          ref.read(onlineStatusProvider.notifier).update((state) => {
            ...state,
            uidInt: online,
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '好友'),
            Tab(text: '群聊'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    return Column(
      children: [
        // Friend requests section
        Consumer(builder: (context, ref, _) {
          final requests = ref.watch(pendingRequestsProvider);
          return requests.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                leading: Badge(
                  label: Text('${list.length}'),
                  child: const Icon(Icons.mail),
                ),
                title: const Text('好友请求'),
                children: list.map<Widget>((req) {
                  final data = req as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF07C160),
                      child: Text(
                        (data['from_nickname'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(data['from_nickname'] ?? ''),
                    subtitle: Text(data['message'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await ref.read(apiClientProvider)
                                .acceptFriendRequest(data['id'] as int);
                            ref.invalidate(pendingRequestsProvider);
                            ref.invalidate(contactsProvider);
                          },
                          child: const Text('同意',
                              style: TextStyle(color: Color(0xFF07C160))),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref.read(apiClientProvider)
                                .rejectFriendRequest(data['id'] as int);
                            ref.invalidate(pendingRequestsProvider);
                          },
                          child: const Text('拒绝',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          );
        }),
        // Friends list
        Expanded(
          child: Consumer(builder: (context, ref, _) {
            final contacts = ref.watch(contactsProvider);
            final onlineStatus = ref.watch(onlineStatusProvider);
            return contacts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无好友', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('点击 + 添加好友', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(contactsProvider);
                    ref.invalidate(pendingRequestsProvider);
                  },
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final c = list[index] as Map<String, dynamic>;
                      final nickname = c['nickname'] as String? ?? '';
                      final avatarUrl = c['avatar_url'] as String? ?? '';
                      final uid = c['uid'] as int;
                      final isOnline = onlineStatus[uid] == true;

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF07C160),
                              child: avatarUrl.isEmpty
                                  ? Text(
                                      nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontSize: 20),
                                    )
                                  : null,
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text((c['alias'] as String? ?? '').isNotEmpty ? c['alias'] as String : nickname,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: (c['alias'] as String? ?? '').isNotEmpty
                            ? Text('@${c['username'] ?? ''}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12))
                            : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'chat':
                                try {
                                  final convId = await ref.read(apiClientProvider).getOrCreateSingleConversation(uid);
                                  if (context.mounted) {
                                    context.go('/chat/$convId', extra: {
                                      'name': nickname,
                                      'avatar_url': avatarUrl,
                                      'peer_uid': uid,
                                    });
                                  }
                                } catch (_) {}
                                break;
                              case 'delete':
                                _confirmDelete(context, uid);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'chat', child: Text('发送消息')),
                            const PopupMenuItem(value: 'delete', child: Text('删除好友')),
                          ],
                        ),
                        onTap: () {
                          context.push('/contact/$uid', extra: {
                            'nickname': nickname,
                            'avatar_url': avatarUrl,
                            'username': c['username'] ?? '',
                          });
                        },
                      );
                    },
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    return Consumer(builder: (context, ref, _) {
      final convos = ref.watch(conversationsProvider);
      return convos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final groups = list.where((c) {
            final m = c as Map<String, dynamic>;
            return (m['type'] ?? 1) == 2;
          }).toList();
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无群聊', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index] as Map<String, dynamic>;
              final name = g['name'] ?? '';
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  context.go('/chat/${g['conversation_id']}', extra: {
                    'name': name,
                    'avatar_url': g['avatar_url'] ?? '',
                    'peer_uid': g['peer_uid'] ?? 0,
                    'chat_type': 1,
                  });
                },
              );
            },
          );
        },
      );
    });
  }

  void _showSearchDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('添加好友'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: '搜索用户名或昵称',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: ctrl.text.trim().isEmpty
                        ? null
                        : () async {
                            final results = await ref
                                .read(apiClientProvider)
                                .searchUsers(ctrl.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _showSearchResults(context, results);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF07C160)),
                    child: const Text('搜索',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showSearchResults(BuildContext context, List<dynamic> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('搜索结果 (${results.length})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('未找到用户'))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: results.length,
                          itemBuilder: (ctx, i) {
                            final user = results[i] as Map<String, dynamic>;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF07C160),
                                child: Text(
                                  (user['nickname'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user['nickname'] ?? ''),
                              subtitle: Text('@${user['username'] ?? ''}'),
                              trailing: TextButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(apiClientProvider)
                                        .sendFriendRequest(user['id'] as int);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('好友请求已发送')),
                                      );
                                      Navigator.pop(ctx);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      String msg = '操作失败';
                                      if (e is DioException) {
                                        msg = e.response?.data?['message']?.toString() ?? msg;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    }
                                  }
                                },
                                child: const Text('添加'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('确定要删除该好友吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(apiClientProvider).deleteFriend(uid);
              ref.invalidate(contactsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

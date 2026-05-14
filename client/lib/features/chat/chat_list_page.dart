import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:mychat/core/constants/api_constants.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/core/network/ws_client.dart';
import 'package:mychat/features/contact/contact_list_page.dart';

final authWatchProvider = StreamProvider((ref) {
  return Hive.box('auth').watch();
});

final conversationsProvider = FutureProvider<List<dynamic>>((ref) {
  ref.watch(authWatchProvider);
  return ref.watch(apiClientProvider).getConversations();
});

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    ref.read(wsClientProvider).connect();
  }

  @override
  Widget build(BuildContext context) {
    // Compute unread counts for bottom nav badges
    final convos = ref.watch(conversationsProvider).valueOrNull ?? [];
    int msgUnread = 0;
    for (final c in convos) {
      final raw = (c as Map<String, dynamic>)['unread_count'];
      if (raw != null) msgUnread += (raw as num).toInt();
    }
    final pendingReqs = ref.watch(pendingRequestsProvider).valueOrNull ?? [];
    final contactUnread = pendingReqs.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search', extra: {'conversation_id': 0}),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          _navDest(Icons.chat, '消息', msgUnread),
          _navDest(Icons.contacts, '通讯录', contactUnread),
          _navDest(Icons.person, '我', 0),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showNewChatMenu(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _ChatList();
      case 1:
        return const ContactListPage();
      case 2:
        return _ProfileSection(ref: ref);
      default:
        return const SizedBox.shrink();
    }
  }

  NavigationDestination _navDest(IconData icon, String label, int count) {
    return NavigationDestination(
      icon: count > 0
          ? Badge(label: Text(count > 99 ? '99+' : '$count'), child: Icon(icon))
          : Icon(icon),
      label: label,
    );
  }

  void _showNewChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF07C160)),
              title: const Text('发起聊天'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/contacts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: Color(0xFF07C160)),
              title: const Text('创建群聊'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/group/create');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convos = ref.watch(conversationsProvider);

    return convos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('暂无会话', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final c = list[index] as Map<String, dynamic>;
              final type = c['type'] ?? 1;
              final name = c['name'] ?? '';
              final rawUnread = c['unread_count'];
              final unreadCount = rawUnread == null ? 0 : (rawUnread as num).toInt();
              return _ConversationTile(
                name: name,
                avatarUrl: c['avatar_url'] ?? '',
                lastMessage: c['last_msg_preview'] ?? '',
                unreadCount: unreadCount,
                isGroup: type == 2,
                isPinned: c['pinned'] == true,
                onTap: () {
                  context.push('/chat/${c['conversation_id']}', extra: {
                    'name': name,
                    'avatar_url': c['avatar_url'] ?? '',
                    'peer_uid': c['peer_uid'] ?? 0,
                    'chat_type': type == 2 ? 1 : 0,
                  });
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final int unreadCount;
  final bool isGroup;
  final bool isPinned;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.unreadCount,
    required this.isGroup,
    this.isPinned = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = avatarUrl.startsWith('http')
        ? avatarUrl
        : avatarUrl.isNotEmpty
            ? '${ApiConstants.baseUrlWindows}$avatarUrl'
            : '';

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isGroup ? Colors.blue : const Color(0xFF07C160),
            backgroundImage:
                fullUrl.isNotEmpty ? CachedNetworkImageProvider(fullUrl) : null,
            child: fullUrl.isEmpty
                ? Icon(
                    isGroup ? Icons.group : Icons.person,
                    color: Colors.white,
                    size: 28,
                  )
                : null,
          ),
        ],
      ),
      title: Row(
        children: [
          if (isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.group, size: 14, color: Colors.grey[600]),
            ),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 16, color: Colors.grey[400]),
            ),
          if (unreadCount > 0)
            Badge(label: Text(unreadCount > 99 ? '99+' : '$unreadCount')),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  final WidgetRef ref;
  const _ProfileSection({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: ref.read(apiClientProvider).getProfile(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF07C160)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: (user?['avatar_url'] ?? '').isNotEmpty
                    ? CachedNetworkImageProvider(
                        user!['avatar_url'].startsWith('http')
                            ? user['avatar_url']
                            : '${ApiConstants.baseUrlWindows}${user?['avatar_url']}',
                      )
                    : null,
                child: (user?['avatar_url'] ?? '').isEmpty
                    ? Text(
                        (user?['nickname'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 32, color: Color(0xFF07C160)),
                      )
                    : null,
              ),
              accountName: Text(user?['nickname'] ?? ''),
              accountEmail: Text('@${user?['username'] ?? ''}'),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('个人信息'),
          onTap: () => context.push('/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('设置'),
          onTap: () => context.push('/settings'),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('退出登录', style: TextStyle(color: Colors.red)),
          onTap: () async {
            final authBox = Hive.box('auth');
            await authBox.clear();
            ref.read(wsClientProvider).disconnect();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}

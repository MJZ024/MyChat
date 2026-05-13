import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mychat/features/auth/login_page.dart';
import 'package:mychat/features/auth/register_page.dart';
import 'package:mychat/features/chat/chat_detail_page.dart';
import 'package:mychat/features/chat/chat_list_page.dart';
import 'package:mychat/features/chat/chat_page.dart';
import 'package:mychat/features/contact/contact_detail_page.dart';
import 'package:mychat/features/contact/contact_list_page.dart';
import 'package:mychat/features/group/create_group_page.dart';
import 'package:mychat/features/group/group_detail_page.dart';
import 'package:mychat/features/profile/profile_page.dart';
import 'package:mychat/features/search/search_page.dart';

final authBoxListener = AuthBoxNotifier();

class AuthBoxNotifier extends ChangeNotifier {
  AuthBoxNotifier() {
    Hive.box('auth').watch().listen((_) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chat',
    refreshListenable: authBoxListener,
    redirect: (context, state) {
      final authBox = Hive.box('auth');
      final token = authBox.get('access_token');
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (token == null && !isAuthRoute) return '/login';
      if (token != null && isAuthRoute) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListPage(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final convId = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatPage(
            conversationId: convId,
            peerUid: extra['peer_uid'] as int? ?? 0,
            name: extra['name'] as String? ?? '',
            avatarUrl: extra['avatar_url'] as String? ?? '',
            chatType: extra['chat_type'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/chat-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatDetailPage(
            conversationId: extra['conversation_id'] as int? ?? 0,
            peerUid: extra['peer_uid'] as int? ?? 0,
            name: extra['name'] as String? ?? '',
            avatarUrl: extra['avatar_url'] as String? ?? '',
            chatType: extra['chat_type'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactListPage(),
      ),
      GoRoute(
        path: '/contact/:uid',
        builder: (context, state) {
          final uid = int.parse(state.pathParameters['uid']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ContactDetailPage(
            uid: uid,
            nickname: extra['nickname'] as String? ?? '',
            avatarUrl: extra['avatar_url'] as String? ?? '',
            username: extra['username'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/group/create',
        builder: (context, state) => const CreateGroupPage(),
      ),
      GoRoute(
        path: '/group/:id',
        builder: (context, state) {
          final groupId = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return GroupDetailPage(
            groupId: groupId,
            groupName: extra['name'] as String? ?? 'Group',
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SearchPage(
            conversationId: extra['conversation_id'] as int? ?? 0,
          );
        },
      ),
    ],
  );
});

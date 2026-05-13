import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mychat/core/network/ws_client.dart';
import 'package:mychat/features/chat/chat_list_page.dart';
import 'package:mychat/features/contact/contact_list_page.dart';

// Global WS event handler — watched by MyApp so it outlives any page navigation.
final wsEventHandlerProvider = Provider<void>((ref) {
  final sub = ref.watch(wsClientProvider).messages.listen((msg) {
    final type = msg['type'] as String?;
    if (type == 'recv_message' || type == 'message_read' ||
        type == 'friend_accept' || type == 'friend_request' ||
        type == 'group_created' || type == 'friend_deleted') {
      ref.invalidate(conversationsProvider);
      if (type == 'friend_request' || type == 'friend_accept' ||
          type == 'friend_deleted') {
        ref.invalidate(pendingRequestsProvider);
      }
      if (type == 'friend_request' || type == 'friend_accept' ||
          type == 'friend_deleted' || type == 'group_created') {
        ref.invalidate(contactsProvider);
      }
    }
  });
  ref.onDispose(sub.cancel);
  return;
});

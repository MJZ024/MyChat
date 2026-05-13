import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mychat/core/constants/api_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: defaultTargetPlatform == TargetPlatform.windows
        ? ApiConstants.baseUrlWindows
        : ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor());
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));
  return dio;
});

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authBox = Hive.box('auth');
    final token = authBox.get('access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final authBox = Hive.box('auth');
      final token = authBox.get('access_token');
      // Only clear if we actually had a token (skip login endpoint 401)
      if (token != null) {
        authBox.put('force_logout', true);
        authBox.delete('access_token');
        authBox.delete('refresh_token');
      }
    }
    handler.next(err);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // Auth
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? phone,
    String? nickname,
  }) async {
    final res = await _dio.post('/api/auth/register', data: {
      'username': username,
      'password': password,
      if (phone != null) 'phone': phone,
      if (nickname != null) 'nickname': nickname,
    });
    return res.data['data'];
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    return res.data['data'];
  }

  // User
  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/api/user/profile');
    return res.data['data'];
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _dio.put('/api/user/profile', data: data);
  }

  Future<Map<String, dynamic>> getUserPublic(int uid) async {
    final res = await _dio.get('/api/user/$uid');
    return res.data['data'];
  }

  // User search
  Future<List<dynamic>> searchUsers(String query) async {
    final res = await _dio.get('/api/user/search', queryParameters: {'q': query});
    return res.data['data'] ?? [];
  }

  // Contacts
  Future<List<dynamic>> getContacts() async {
    final res = await _dio.get('/api/contacts');
    return res.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> sendFriendRequest(int toUid, {String? message}) async {
    final res = await _dio.post('/api/contacts/request', data: {
      'to_uid': toUid,
      'message': message ?? '',
    });
    return res.data['data'];
  }

  Future<List<dynamic>> getPendingRequests() async {
    final res = await _dio.get('/api/contacts/requests');
    return res.data['data'] ?? [];
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _dio.post('/api/contacts/accept/$requestId');
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _dio.post('/api/contacts/reject/$requestId');
  }

  Future<void> deleteFriend(int uid) async {
    await _dio.delete('/api/contacts/$uid');
  }

  Future<void> blockUser(int uid) async {
    await _dio.post('/api/contacts/block/$uid');
  }

  Future<void> unblockUser(int uid) async {
    await _dio.post('/api/contacts/unblock/$uid');
  }

  // Conversations
  Future<List<dynamic>> getConversations() async {
    final res = await _dio.get('/api/conversations');
    return res.data['data'] ?? [];
  }

  Future<int> getOrCreateSingleConversation(int targetUid) async {
    final res = await _dio.post('/api/conversations/single/$targetUid');
    return res.data['data']['conversation_id'] as int;
  }

  Future<Map<String, dynamic>> getConversationState(int conversationId) async {
    final res = await _dio.get('/api/conversations/$conversationId/state');
    return res.data['data'];
  }

  Future<bool> toggleMute(int conversationId) async {
    final res = await _dio.put('/api/conversations/$conversationId/toggle-mute');
    return res.data['data']['muted'] as bool;
  }

  Future<bool> togglePin(int conversationId) async {
    final res = await _dio.put('/api/conversations/$conversationId/toggle-pin');
    return res.data['data']['pinned'] as bool;
  }

  Future<void> clearMessages(int conversationId) async {
    await _dio.delete('/api/messages/$conversationId');
  }

  // Messages
  Future<List<dynamic>> getMessages(int conversationId, {int lastSeq = 0}) async {
    final res = await _dio.get('/api/messages/$conversationId', queryParameters: {
      'last_seq': lastSeq,
    });
    return res.data['data'] ?? [];
  }

  // Groups
  Future<Map<String, dynamic>> createGroup(String name, List<int> memberUids) async {
    final res = await _dio.post('/api/groups', data: {
      'name': name,
      'member_uids': memberUids,
    });
    return res.data['data'];
  }

  Future<List<dynamic>> getGroupMembers(int groupId) async {
    final res = await _dio.get('/api/groups/$groupId/members');
    return res.data['data'] ?? [];
  }

  Future<void> inviteMember(int groupId, int uid) async {
    await _dio.post('/api/groups/$groupId/invite', data: {'uid': uid});
  }

  Future<void> leaveGroup(int groupId) async {
    await _dio.post('/api/groups/$groupId/leave');
  }

  Future<void> kickMember(int groupId, int uid) async {
    await _dio.post('/api/groups/$groupId/kick', data: {'uid': uid});
  }

  Future<void> updateGroupInfo(int groupId, Map<String, dynamic> data) async {
    await _dio.put('/api/groups/$groupId', data: data);
  }

  Future<Map<String, dynamic>> getGroupInfo(int groupId) async {
    final res = await _dio.get('/api/groups/$groupId');
    return res.data['data'];
  }

  // Online status
  Future<Map<int, bool>> getOnlineStatus(List<int> uids) async {
    final res = await _dio.get('/api/users/status', queryParameters: {
      'uids': uids.join(','),
    });
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(int.parse(k), v as bool));
  }

  // Message search
  Future<List<dynamic>> searchMessages(String query, {int conversationId = 0}) async {
    final params = <String, dynamic>{'q': query};
    if (conversationId > 0) params['conversation_id'] = conversationId;
    final res = await _dio.get('/api/messages/search', queryParameters: params);
    return res.data['data'] ?? [];
  }

  // Forward messages
  Future<void> forwardMessages(List<int> messageIds, int targetConvId) async {
    await _dio.post('/api/messages/forward', data: {
      'message_ids': messageIds,
      'target_conv_id': targetConvId,
    });
  }

  // Upload
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/api/upload', data: formData);
    return res.data['data'];
  }
}

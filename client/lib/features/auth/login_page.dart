import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/core/network/ws_client.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final data = await ref.read(apiClientProvider).login(
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      final authBox = Hive.box('auth');
      await authBox.put('access_token', data['access_token']);
      await authBox.put('refresh_token', data['refresh_token']);
      await authBox.put('user_id', data['user_id']);
      await authBox.put('username', data['username']);
      await authBox.put('nickname', data['nickname'] ?? '');
      await authBox.put('avatar_url', data['avatar_url'] ?? '');

      // Connect WebSocket
      ref.read(wsClientProvider).connect();

      if (mounted) context.go('/chat');
    } catch (e) {
      if (mounted) {
        String msg = '登录失败，请检查网络';
        if (e is DioException) {
          final serverMsg = e.response?.data?['message'];
          if (serverMsg != null) {
            final s = serverMsg.toString();
            msg = s == 'user not found' ? '用户不存在'
                : s == 'invalid password' ? '密码错误'
                : s;
          } else if (e.type == DioExceptionType.connectionError) {
            msg = '无法连接服务器';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble, size: 80, color: Color(0xFF07C160)),
              const SizedBox(height: 16),
              const Text('MyChat', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

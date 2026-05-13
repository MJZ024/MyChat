import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mychat/core/network/api_client.dart';
import 'package:mychat/features/chat/chat_list_page.dart';
import 'package:mychat/features/contact/contact_list_page.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  final Set<int> _selectedUids = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        actions: [
          TextButton(
            onPressed: _selectedUids.isEmpty || _nameCtrl.text.trim().isEmpty
                ? null
                : _createGroup,
            child: const Text('创建',
                style: TextStyle(color: Color(0xFF07C160), fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '群名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selectedUids.length} member(s) selected',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child: contacts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Add friends first to create a group'),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final c = list[index] as Map<String, dynamic>;
                    final uid = c['uid'] as int;
                    final nickname = c['nickname'] ?? '';
                    final selected = _selectedUids.contains(uid);

                    return CheckboxListTile(
                      value: selected,
                      secondary: CircleAvatar(
                        backgroundColor: const Color(0xFF07C160),
                        child: Text(
                          nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(nickname),
                      subtitle: Text('@${c['username'] ?? ''}'),
                      activeColor: const Color(0xFF07C160),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUids.add(uid);
                          } else {
                            _selectedUids.remove(uid);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createGroup() async {
    try {
      await ref.read(apiClientProvider).createGroup(
            _nameCtrl.text.trim(),
            _selectedUids.toList(),
          );
      if (mounted) {
        ref.invalidate(conversationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created')),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建群聊失败，请重试')),
        );
      }
    }
  }
}

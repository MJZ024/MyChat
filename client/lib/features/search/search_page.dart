import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mychat/core/network/api_client.dart';

class SearchPage extends ConsumerStatefulWidget {
  final int conversationId;

  const SearchPage({super.key, this.conversationId = 0});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _queryCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);
    try {
      final results = await ref.read(apiClientProvider).searchMessages(
        query,
        conversationId: widget.conversationId,
      );
      setState(() => _results = results);
    } catch (_) {
      _results = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.conversationId > 0 ? '搜索本会话...' : '搜索所有消息...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty && _queryCtrl.text.isNotEmpty
              ? const Center(child: Text('无结果'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final r = _results[index] as Map<String, dynamic>;
                    final content = r['content'] as String? ?? '';
                    final senderName = r['sender_name'] as String? ?? '';
                    final createdAt = r['created_at'];

                    return ListTile(
                      title: Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        senderName,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: createdAt != null
                          ? Text(
                              _formatTime(createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            )
                          : null,
                      onTap: () {
                        final convId = r['conversation_id'];
                        if (convId != null) {
                          context.go('/chat/$convId', extra: {
                            'name': senderName,
                            'avatar_url': '',
                          });
                        }
                      },
                    );
                  },
                ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final ms = timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms > 1e12 ? ms : ms * 1000);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}

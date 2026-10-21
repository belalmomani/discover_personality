import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/social/social_models.dart';
import '../auth/auth_screen.dart';
import 'chat_screen.dart';

/// Conversation list: newest first, unread counters, search by name.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<ConversationSummary>? _items;
  String? _error;
  String _query = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(socialApiProvider);
    if (!api.available) return;
    try {
      final r = await api.conversations();
      if (mounted) setState(() {
            _items = r;
            _error = null;
          });
    } catch (e) {
      if (mounted && _items == null) setState(() => _error = socialErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(socialApiProvider);
    final cloud = ref.watch(cloudApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الدردشات')),
      body: SafeArea(
        child: !cloud.isConfigured
            ? const EmptyView(icon: Icons.cloud_off_outlined, message: 'الدردشة تحتاج تفعيل الحساب السحابي في هذه النسخة.')
            : !api.available
                ? EmptyView(
                    icon: Icons.lock_outline,
                    message: 'سجّل الدخول لاستخدام الدردشة.',
                    action: FilledButton(onPressed: () => pushScreen(context, const AuthScreen()), child: const Text('تسجيل الدخول')),
                  )
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _items == null
                        ? const LoadingView()
                        : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final q = _query.trim();
    final shown = _items!.where((c) => q.isEmpty || c.otherUsername.contains(q)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث في المحادثات', border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      Expanded(
        child: shown.isEmpty
            ? const EmptyView(icon: Icons.forum_outlined, message: 'لا توجد محادثات. ابدأ من تبويب «يشبهونك».')
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    final preview = c.lastKind == 'gift' ? '🎁 هدية' : (c.lastKind == 'image' ? '📷 صورة' : (c.lastBody ?? ''));
                    return ListTile(
                      leading: CircleAvatar(child: Text(c.otherEmoji, style: const TextStyle(fontSize: 22))),
                      title: Text(c.otherUsername),
                      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: c.unread > 0 ? Badge(label: Text('${c.unread}')) : null,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            conversationId: c.id,
                            otherId: c.otherId,
                            otherName: c.otherUsername,
                            otherEmoji: c.otherEmoji,
                            lastSeen: c.lastSeen,
                          ),
                        ));
                        _load();
                      },
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}

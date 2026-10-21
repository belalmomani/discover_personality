import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/social/image_validator.dart';
import '../../data/social/social_api.dart';
import '../../data/social/social_models.dart';
import 'gift_sheet.dart';

String _hhmm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String lastSeenText(DateTime? seen, DateTime now) {
  if (seen == null) return '';
  final diff = now.difference(seen);
  if (diff.inMinutes < 3) return 'متصل الآن';
  if (diff.inMinutes < 60) return 'آخر ظهور قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'آخر ظهور قبل ${diff.inHours} ساعة';
  return 'آخر ظهور قبل ${diff.inDays} يوم';
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.otherId, required this.otherName, required this.otherEmoji, this.lastSeen});
  final String conversationId;
  final String otherId;
  final String otherName;
  final String otherEmoji;
  final DateTime? lastSeen;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<GiftItem> _gifts = [];
  bool _sending = false;
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    final api = ref.read(socialApiProvider);
    api.touchPresence().catchError((Object _) {});
    api.gifts().then((g) {
      if (mounted) setState(() => _gifts = g);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(socialApiProvider).sendMessage(widget.conversationId, t);
      _text.clear();
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (_sending) return;
    Uint8List bytes;
    try {
      // Gallery only (system photo picker: no storage permission needed). Resized and compressed before upload.
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
      if (x == null) return;
      bytes = await x.readAsBytes();
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر فتح المعرض.');
      return;
    }
    final check = validateChatImage(bytes);
    if (!check.ok) {
      if (mounted) showMessage(context, socialErrorMessage(StateError('invalid_image')));
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('إرسال هذه الصورة إلى ${widget.otherName}؟'),
        content: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, height: 220, fit: BoxFit.cover)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(socialApiProvider).sendImage(widget.conversationId, bytes);
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report({String? messageId}) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('الإبلاغ عن إساءة'),
        content: TextField(controller: c, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب سبب البلاغ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('إرسال البلاغ')),
        ],
      ),
    );
    c.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await ref.read(socialApiProvider).report(widget.otherId, messageId, reason);
      if (mounted) showMessage(context, 'تم إرسال البلاغ للإدارة.');
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('حظر ${widget.otherName}؟'),
        content: const Text('لن تستطيعا التواصل أو الظهور في قوائم بعضكما. يمكنك رفع الحظر لاحقًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حظر')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(socialApiProvider).block(widget.otherId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(socialApiProvider);
    final me = api.userId;
    final cs = Theme.of(context).colorScheme;
    final seen = lastSeenText(widget.lastSeen, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text('${widget.otherEmoji} ${widget.otherName}', style: const TextStyle(fontSize: 16)),
          if (seen.isNotEmpty) Text(seen, style: const TextStyle(fontSize: 11)),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'block' ? _block() : _report(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('إبلاغ عن إساءة')),
              PopupMenuItem(value: 'block', child: Text('حظر المستخدم')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: api.messages(widget.conversationId),
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(message: socialErrorMessage(snap.error!));
                if (!snap.hasData) return const LoadingView();
                final msgs = snap.data!;
                if (msgs.length != _lastCount) {
                  _lastCount = msgs.length;
                  if (msgs.any((m) => m.senderId != me && !m.isRead)) {
                    api.markRead(widget.conversationId).catchError((Object _) {});
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  });
                }
                if (msgs.isEmpty) return const EmptyView(icon: Icons.chat_bubble_outline, message: 'ابدأ المحادثة بتحية طيبة.');
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.senderId == me;
                    final gift = m.isGift ? _gifts.where((g) => g.id == m.giftId).cast<GiftItem?>().firstWhere((_) => true, orElse: () => null) : null;
                    final content = m.isImage ? '' : m.isGift ? '${gift?.emoji ?? "🎁"} ${mine ? "أرسلت" : "أرسل لك"} هدية${gift == null ? "" : ": ${gift.name}"}' : m.body;
                    return Align(
                      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                      child: GestureDetector(
                        onLongPress: mine ? null : () => _report(messageId: m.id),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: m.isGift ? cs.tertiaryContainer : (mine ? cs.primaryContainer : cs.surfaceContainerHigh),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (m.isImage) _ImageBubble(path: m.body, api: api) else Text(content, style: m.isGift ? const TextStyle(fontSize: 18) : null),
                            const SizedBox(height: 2),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_hhmm(m.createdAt), style: const TextStyle(fontSize: 10)),
                              if (mine) ...[const SizedBox(width: 4), Text(m.isRead ? '✓✓ قُرئت' : '✓ أُرسلت', style: const TextStyle(fontSize: 10))],
                            ]),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'إرسال هدية',
                icon: const Icon(Icons.card_giftcard),
                onPressed: () => showGiftSheet(context, conversationId: widget.conversationId, otherName: widget.otherName),
              ),
              IconButton(
                tooltip: 'إرسال صورة',
                icon: const Icon(Icons.image_outlined),
                onPressed: _sending ? null : _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'اكتب رسالة...', counterText: '', border: OutlineInputBorder()),
                ),
              ),
              IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      ),
    );
  }
}


/// Loads a short-lived signed URL, then shows the image (tap to enlarge). Failures show a placeholder.
class _ImageBubble extends StatefulWidget {
  const _ImageBubble({required this.path, required this.api});
  final String path;
  final SocialApi api;
  @override
  State<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<_ImageBubble> {
  late final Future<String> _url = widget.api.imageUrl(widget.path);

  Widget _placeholder(IconData icon, String text) => SizedBox(
        width: 200,
        height: 120,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(height: 4), Text(text, style: const TextStyle(fontSize: 12))]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) return _placeholder(Icons.broken_image_outlined, 'تعذر تحميل الصورة');
        if (!snap.hasData) return _placeholder(Icons.image_outlined, 'جارٍ التحميل...');
        final url = snap.data!;
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (d) => Dialog(
              child: InteractiveViewer(child: Image.network(url, errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image_outlined, 'تعذر تحميل الصورة'))),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image_outlined, 'تعذر تحميل الصورة'),
              loadingBuilder: (c, child, p) => p == null ? child : _placeholder(Icons.image_outlined, 'جارٍ التحميل...'),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/profile/animals.dart';
import '../../data/social/social_models.dart';
import '../auth/auth_screen.dart';
import 'admin_screen.dart';
import 'chat_screen.dart';

const _emojis = ['🙂', '😎', '🦅', '🦉', '🐬', '🦁', '🐺', '🐘', '🦊', '🐎', '🐈', '🌟'];

/// "People like you": opt-in. Shares only 8 aggregated numbers (never raw answers).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _loading = true;
  bool _editing = false;
  bool _admin = false;
  String? _error;
  SocialProfile? _profile;
  List<SimilarUser> _similar = [];
  WalletInfo? _wallet;

  final _name = TextEditingController();
  String _emoji = '🙂';
  bool _share = false;
  bool _showSeen = true;
  bool _age = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(socialApiProvider);
    if (!api.available) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await api.myProfile();
      _profile = p;
      if (p != null) {
        _name.text = p.username ?? '';
        _emoji = p.avatarEmoji;
        _share = p.shareResults;
        _showSeen = p.showLastSeen;
        _age = p.ageConfirmed;
      }
      _admin = await api.isAdmin();
      if (p != null && p.isComplete) {
        final history = ref.read(historyProvider);
        if (history.isNotEmpty) {
          await api.publishFeatures(featuresOf(history.first.result));
        }
        _similar = await api.findSimilar();
        _wallet = await api.wallet();
        api.touchPresence().catchError((Object _) {});
      }
    } catch (e) {
      _error = socialErrorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (ref.read(historyProvider).isEmpty && _share) {
      showMessage(context, 'أكمل الاختبار الرئيسي أولًا ليُحسب التشابه.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(socialApiProvider).saveProfile(
            username: _name.text.trim(),
            emoji: _emoji,
            shareResults: _share,
            showLastSeen: _showSeen,
            ageConfirmed: _age,
          );
      _editing = false;
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chat(SimilarUser u) async {
    try {
      final id = await ref.read(socialApiProvider).startConversation(u.userId);
      if (!mounted) return;
      pushScreen(context, ChatScreen(conversationId: id, otherId: u.userId, otherName: u.username, otherEmoji: u.emoji));
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  Future<void> _claim() async {
    try {
      await ref.read(socialApiProvider).claimDaily();
      final w = await ref.read(socialApiProvider).wallet();
      if (mounted) {
        setState(() => _wallet = w);
        showMessage(context, 'تمت إضافة عملات اليوم.');
      }
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  Future<void> _showBlocked() async {
    final api = ref.read(socialApiProvider);
    final list = await api.blocked();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('المحظورون'),
        content: list.isEmpty
            ? const Text('لا يوجد مستخدمون محظورون.')
            : Column(mainAxisSize: MainAxisSize.min, children: [
                for (final b in list)
                  ListTile(
                    title: Text(b.username),
                    trailing: TextButton(
                      onPressed: () async {
                        await api.unblock(b.userId);
                        if (d.mounted) Navigator.pop(d);
                        _load();
                      },
                      child: const Text('رفع الحظر'),
                    ),
                  ),
              ]),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(cloudApiProvider);
    final api = ref.watch(socialApiProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('يشبهونك'),
        actions: [
          if (api.available && _profile != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') setState(() => _editing = true);
                if (v == 'blocked') _showBlocked();
                if (v == 'admin') pushScreen(context, const AdminScreen());
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('ملفي الاجتماعي')),
                const PopupMenuItem(value: 'blocked', child: Text('المحظورون')),
                if (_admin) const PopupMenuItem(value: 'admin', child: Text('لوحة الإدارة')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: !cloud.isConfigured
            ? const EmptyView(icon: Icons.cloud_off_outlined, message: 'هذه الميزة تحتاج تفعيل الحساب السحابي (Supabase) في هذه النسخة.')
            : !api.available
                ? EmptyView(
                    icon: Icons.lock_outline,
                    message: 'سجّل الدخول لرؤية من يشبهك والدردشة معهم.',
                    action: FilledButton(onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
                      _load();
                    }, child: const Text('تسجيل الدخول')),
                  )
                : _loading
                    ? const LoadingView()
                    : _error != null
                        ? ErrorView(message: _error!, onRetry: _load)
                        : (_profile == null || !_profile!.isComplete || _editing)
                            ? _setupForm()
                            : _list(),
      ),
    );
  }

  Widget _setupForm() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SectionCard(
        title: 'قبل أن يظهر ملفك للآخرين',
        icon: Icons.privacy_tip_outlined,
        child: BulletList([
          'الميزة اختيارية ومعطلة حتى توافق.',
          'لا يُرسل إلا 8 أرقام مجمّعة من نتائجك للمطابقة، وليس إجاباتك ولا تاريخ ميلادك ولا بريدك.',
          'يرى الآخرون اسمك المستعار وصورتك الرمزية ونسبة التشابه فقط.',
          'يمكنك إيقاف المشاركة في أي وقت فتُحذف الأرقام من الخادم.',
        ]),
      ),
      TextField(
        controller: _name,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'اسم مستعار (3 إلى 20 حرفًا)', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final e in _emojis)
          ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 22)), selected: _emoji == e, onSelected: (_) => setState(() => _emoji = e)),
      ]),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: _age, onChanged: (v) => setState(() => _age = v ?? false), title: const Text('أؤكد أن عمري 18 سنة أو أكثر')),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: _share, onChanged: (v) => setState(() => _share = v ?? false), title: const Text('أوافق على مشاركة ملخص نتائجي للمطابقة مع الآخرين')),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: _showSeen, onChanged: (v) => setState(() => _showSeen = v ?? true), title: const Text('إظهار «آخر ظهور» للمحادثين')),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
      ),
      if (_editing) TextButton(onPressed: () => setState(() => _editing = false), child: const Text('إلغاء')),
    ]);
  }

  Widget _list() {
    final canClaim = _wallet?.canClaimDaily(DateTime.now().toUtc()) ?? false;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Chip(avatar: const Text('🪙'), label: Text('رصيدك: ${_wallet?.coins ?? 0}')),
          const SizedBox(width: 8),
          Chip(avatar: const Text('⭐'), label: Text('نقاط المكافآت: ${_wallet?.rewards ?? 0}')),
          const Spacer(),
          if (canClaim) TextButton(onPressed: _claim, child: const Text('عملات اليوم')),
        ]),
        const SizedBox(height: 8),
        if (ref.watch(historyProvider).isEmpty)
          const SectionCard(title: 'أكمل الاختبار الرئيسي', icon: Icons.fact_check_outlined, child: Text('تحتاج إلى نتيجة محفوظة ليُحسب التشابه.')),
        if (_similar.isEmpty)
          const SectionCard(title: 'لا يوجد من يطابقك بعد', icon: Icons.people_outline, child: Text('لم نجد مستخدمين بنسبة تشابه كافية الآن. اسحب للتحديث لاحقًا.'))
        else
          for (final u in _similar)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(u.emoji, style: const TextStyle(fontSize: 22))),
                title: Text(u.username),
                subtitle: Text('تشابه في الصفات: ${u.similarity}٪'),
                trailing: FilledButton.tonal(onPressed: () => _chat(u), child: const Text('دردشة')),
              ),
            ),
        const SizedBox(height: 8),
        const Text('التشابه تقدير رياضي لنتائج الاختبار وليس دليلًا على القرابة أو التوافق.', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

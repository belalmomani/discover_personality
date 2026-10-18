import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/social/social_models.dart';

/// Admin tools. Visible only if the server says you are an admin, and every call is re-checked
/// on the server (SECURITY DEFINER functions + RLS). No payment status can be edited here.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدارة'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'الهدايا'),
            Tab(text: 'البلاغات'),
            Tab(text: 'الإعدادات'),
            Tab(text: 'الإحصاءات'),
          ]),
        ),
        body: const SafeArea(child: TabBarView(children: [_GiftsTab(), _ReportsTab(), _SettingsTab(), _StatsTab()])),
      ),
    );
  }
}

const _tiers = ['free', 'basic', 'mid', 'rare', 'seasonal'];

class _GiftsTab extends ConsumerStatefulWidget {
  const _GiftsTab();
  @override
  ConsumerState<_GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends ConsumerState<_GiftsTab> {
  List<GiftItem>? _gifts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await ref.read(socialApiProvider).adminGifts();
      if (mounted) setState(() {
            _gifts = g;
            _error = null;
          });
    } catch (e) {
      if (mounted) setState(() => _error = socialErrorMessage(e));
    }
  }

  Future<void> _edit(GiftItem? g) async {
    final name = TextEditingController(text: g?.name ?? '');
    final emoji = TextEditingController(text: g?.emoji ?? '🎁');
    final price = TextEditingController(text: '${g?.price ?? 0}');
    final order = TextEditingController(text: '${g?.sortOrder ?? 100}');
    var tier = g?.tier ?? 'basic';
    var active = g?.active ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text(g == null ? 'هدية جديدة' : 'تعديل الهدية'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: emoji, decoration: const InputDecoration(labelText: 'الرمز (إيموجي)')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالعملات الافتراضية (0 = مجانية)')),
              TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
              DropdownButton<String>(value: tier, isExpanded: true, items: [for (final t in _tiers) DropdownMenuItem(value: t, child: Text(t))], onChanged: (v) => setSt(() => tier = v ?? tier)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('مفعّلة'), value: active, onChanged: (v) => setSt(() => active = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final item = GiftItem(
      id: g?.id ?? '',
      name: name.text.trim(),
      emoji: emoji.text.trim(),
      price: int.tryParse(price.text.trim()) ?? -1,
      tier: tier,
      active: active,
      startsAt: g?.startsAt,
      endsAt: g?.endsAt,
      sortOrder: int.tryParse(order.text.trim()) ?? 100,
    );
    name.dispose();
    emoji.dispose();
    price.dispose();
    order.dispose();
    if (saved != true || !mounted) return;
    if (item.name.isEmpty || item.emoji.isEmpty || item.price < 0) {
      showMessage(context, 'تحقق من الاسم والرمز والسعر.');
      return;
    }
    try {
      await ref.read(socialApiProvider).saveGift(item, isNew: g == null);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_gifts == null) return const LoadingView();
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(null), child: const Icon(Icons.add)),
      body: ListView(children: [
        for (final g in _gifts!)
          ListTile(
            leading: Text(g.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(g.name),
            subtitle: Text('${g.isFree ? "مجانية" : "${g.price} عملة"} • ${g.tier}${g.active ? "" : " • موقوفة"}'),
            onTap: () => _edit(g),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();
  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  List<ReportRow>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(socialApiProvider).adminReports('open');
      if (mounted) setState(() {
            _rows = r;
            _error = null;
          });
    } catch (e) {
      if (mounted) setState(() => _error = socialErrorMessage(e));
    }
  }

  Future<void> _act(ReportRow r, String status, {bool ban = false}) async {
    final api = ref.read(socialApiProvider);
    try {
      if (ban) await api.setBan(r.reportedId, true);
      await api.resolveReport(r.id, status);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows == null) return const LoadingView();
    if (_rows!.isEmpty) return const EmptyView(icon: Icons.check_circle_outline, message: 'لا توجد بلاغات مفتوحة.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final r in _rows!)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المُبلَّغ عنه: ${r.reported} • المُبلِّغ: ${r.reporter}'),
                Text('السبب: ${r.reason}'),
                if (r.messageBody != null) Text('الرسالة: ${r.messageBody}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton(onPressed: () => _act(r, 'dismissed'), child: const Text('تجاهل')),
                  OutlinedButton(onPressed: () => _act(r, 'reviewed'), child: const Text('تمت المراجعة')),
                  FilledButton(onPressed: () => _act(r, 'actioned', ban: true), child: const Text('حظر المستخدم')),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();
  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  Map<String, String>? _s;
  String? _error;

  static const _labels = {
    'daily_free_coins': 'عملات يومية مجانية لكل مستخدم',
    'free_gift_daily_limit': 'حد الهدايا المجانية يوميًا',
    'reward_rate_percent': 'نسبة نقاط المكافآت للمستلم من سعر الهدية (٪)',
    'chat_min_similarity': 'الحد الأدنى لنسبة التشابه للدردشة (٪)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(socialApiProvider).settings();
      if (mounted) setState(() {
            _s = s;
            _error = null;
          });
    } catch (e) {
      if (mounted) setState(() => _error = socialErrorMessage(e));
    }
  }

  Future<void> _edit(String key) async {
    final c = TextEditingController(text: _s![key]);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(_labels[key] ?? key),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    c.dispose();
    if (v == null || v.isEmpty || !mounted) return;
    try {
      await ref.read(socialApiProvider).setSetting(key, v);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, 'قيمة غير صالحة أو لا تملك الصلاحية.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_s == null) return const LoadingView();
    return ListView(children: [
      for (final e in _labels.entries)
        ListTile(title: Text(e.value), trailing: Text(_s![e.key] ?? '—'), onTap: () => _edit(e.key)),
    ]);
  }
}

class _StatsTab extends ConsumerStatefulWidget {
  const _StatsTab();
  @override
  ConsumerState<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<_StatsTab> {
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(socialApiProvider).stats().then((s) {
      if (mounted) setState(() => _stats = s);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = socialErrorMessage(e));
    });
  }

  static const _names = {
    'users': 'المستخدمون',
    'social_users': 'المشاركون في «يشبهونك»',
    'conversations': 'المحادثات',
    'messages': 'الرسائل',
    'gift_sends': 'الهدايا المرسلة',
    'coins_spent': 'عملات افتراضية مُنفقة',
    'coins_issued': 'عملات افتراضية مُصدرة',
    'open_reports': 'بلاغات مفتوحة',
  };

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!);
    if (_stats == null) return const LoadingView();
    return ListView(children: [
      for (final e in _names.entries) ListTile(title: Text(e.value), trailing: Text('${_stats![e.key] ?? 0}')),
      const Padding(padding: EdgeInsets.all(16), child: Text('العملات هنا افتراضية؛ لا توجد أموال حقيقية في هذه المرحلة.', style: TextStyle(fontSize: 12))),
    ]);
  }
}

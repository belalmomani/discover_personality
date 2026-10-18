import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/social/social_models.dart';

/// Bottom sheet to pick and send a gift. The server validates identity, balance and limits;
/// the idempotency key makes double taps / retries harmless.
Future<void> showGiftSheet(BuildContext context, {required String conversationId, required String otherName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GiftSheet(conversationId: conversationId, otherName: otherName),
  );
}

class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet({required this.conversationId, required this.otherName});
  final String conversationId;
  final String otherName;
  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  List<GiftItem>? _gifts;
  WalletInfo? _wallet;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(socialApiProvider);
    try {
      final g = await api.gifts();
      final w = await api.wallet();
      if (mounted) setState(() {
            _gifts = g;
            _wallet = w;
            _error = null;
          });
    } catch (e) {
      if (mounted) setState(() => _error = socialErrorMessage(e));
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await ref.read(socialApiProvider).claimDaily();
      await _load();
      if (mounted) showMessage(context, 'تمت إضافة عملات اليوم إلى رصيدك.');
    } catch (e) {
      if (mounted) showMessage(context, socialErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(GiftItem g) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد إرسال الهدية'),
        content: Text('إرسال ${g.emoji} «${g.name}» إلى ${widget.otherName}\n${g.isFree ? "هدية مجانية" : "السعر: ${g.price} عملة افتراضية"}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final key = newUuid(); // one key per confirmed tap: retries of the same request cannot charge twice
    try {
      await ref.read(socialApiProvider).sendGift(widget.conversationId, g.id, key);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('تم إرسال الهدية ${g.emoji}')));
    } catch (e) {
      if (mounted) {
        showMessage(context, socialErrorMessage(e));
        setState(() => _busy = false);
        _load();
      }
    }
  }

  static const _tierNames = {'free': 'مجانية', 'basic': 'رمزية', 'mid': 'متوسطة', 'rare': 'نادرة', 'seasonal': 'موسمية'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canClaim = _wallet?.canClaimDaily(DateTime.now().toUtc()) ?? false;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _gifts == null
                ? const LoadingView()
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Chip(avatar: const Text('🪙'), label: Text('رصيدك: ${_wallet!.coins} عملة افتراضية')),
                        const Spacer(),
                        if (canClaim) TextButton(onPressed: _busy ? null : _claim, child: const Text('عملات اليوم المجانية')),
                      ]),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('العملات افتراضية داخل التطبيق ولا تُحوَّل إلى أموال.', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: _gifts!.isEmpty
                          ? const EmptyView(icon: Icons.card_giftcard, message: 'لا توجد هدايا متاحة الآن.')
                          : GridView.count(
                              crossAxisCount: 3,
                              padding: const EdgeInsets.all(12),
                              childAspectRatio: 0.85,
                              children: [
                                for (final g in _gifts!)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _busy ? null : () => _send(g),
                                    child: Card(
                                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Text(g.emoji, style: const TextStyle(fontSize: 36)),
                                        const SizedBox(height: 4),
                                        Text(g.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(g.isFree ? 'مجانية' : '🪙 ${g.price}', style: TextStyle(color: cs.primary)),
                                        Text(_tierNames[g.tier] ?? '', style: const TextStyle(fontSize: 10)),
                                      ]),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ]),
      ),
    );
  }
}

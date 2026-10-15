import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/scoring/scoring_engine.dart';
import '../results/results_screen.dart';
import 'question_screen.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      final saved = await ref.read(assessmentProvider.notifier).finish();
      await ref.read(historyProvider.notifier).add(saved);
      // Best-effort cloud sync (no-op offline / signed out / unconfigured).
      final ids = await ref.read(syncServiceProvider).syncResults([saved]);
      await ref.read(historyProvider.notifier).markSynced(ids);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => ResultsScreen(resultId: saved.id)),
        (route) => route.isFirst,
      );
    } on ScoringException catch (e) {
      if (mounted) showMessage(context, 'لا يمكن حساب النتيجة: أجب عن كل الأسئلة أولًا.\n${e.message}');
    } catch (_) {
      if (mounted) showMessage(context, 'حدث خطأ غير متوقع أثناء حفظ النتيجة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(questionBankProvider);
    final state = ref.watch(assessmentProvider);
    final notifier = ref.read(assessmentProvider.notifier);
    final qs = bank.questions;
    final missing = [for (var i = 0; i < qs.length; i++) if (!state.answers.containsKey(qs[i].id)) i];
    final complete = missing.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الإجابات')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تمت الإجابة عن ${state.answers.length} من ${qs.length}', style: Theme.of(context).textTheme.titleMedium),
                  if (!complete) ...[
                    const SizedBox(height: 8),
                    Text('أسئلة بلا إجابة: ${missing.length}. اضغط عليها للإجابة.'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final i in missing.take(30))
                        ActionChip(
                          label: Text('${i + 1}'),
                          onPressed: () async {
                            await notifier.goTo(i);
                            if (context.mounted) pushScreen(context, const QuestionScreen(fromReview: true));
                          },
                        ),
                    ]),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('أجبت عن كل الأسئلة. راجع إجاباتك ثم اضغط «احسب النتيجة».'),
                    ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: qs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = state.answers[qs[i].id];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(qs[i].text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(a == null ? '—' : '$a', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await notifier.goTo(i);
                    if (context.mounted) pushScreen(context, const QuestionScreen(fromReview: true));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: complete && !_busy ? _finish : null,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('احسب النتيجة'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

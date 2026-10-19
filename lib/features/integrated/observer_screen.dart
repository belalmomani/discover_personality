import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/integrated/observer.dart';

/// A person who knows you well rates you (10 statements). Stored on this device only.
class ObserverScreen extends ConsumerStatefulWidget {
  const ObserverScreen({super.key});
  @override
  ConsumerState<ObserverScreen> createState() => _ObserverScreenState();
}

class _ObserverScreenState extends ConsumerState<ObserverScreen> {
  bool _started = false;
  String _relation = observerRelations.first;
  final Map<int, int> _answers = {};

  Future<void> _finish() async {
    await ref.read(observersProvider.notifier).add(_relation, _answers);
    if (!mounted) return;
    showMessage(context, 'شكرًا، سُجّل التقييم على جهازك.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(questionBankProvider).scale;
    final complete = ObserverRating.isComplete(_answers);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('رأي شخص يعرفك')),
      body: SafeArea(
        child: !_started
            ? ListView(padding: const EdgeInsets.all(16), children: [
                const SectionCard(
                  title: 'لمن تُسلَّم الشاشة؟',
                  icon: Icons.people_outline,
                  child: BulletList([
                    'سلّم الهاتف لشخص يعرفك جيدًا (صديق، زميل، قريب).',
                    'يجيب بصدق عن 10 عبارات عنك، ولن يرى نتائجك ولا إجاباتك.',
                    'يُفضَّل 3 مقيِّمين مختلفين على الأقل ليصبح المقارنة أوثق؛ مقيِّم واحد يعطي صورة مبدئية فقط.',
                    'لا تُحفظ أسماء؛ فقط صلة القرابة والإجابات، على جهازك فقط.',
                  ]),
                ),
                const Text('صلتك بصاحب الاختبار:'),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final r in observerRelations)
                    ChoiceChip(label: Text(r), selected: _relation == r, onSelected: (_) => setState(() => _relation = r)),
                ]),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => setState(() => _started = true), child: const Text('ابدأ التقييم')),
              ])
            : Column(children: [
                Expanded(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(scale.map((s) => '${s.value} = ${s.label}').join('\n')))),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('إلى أي مدى تنطبق هذه العبارة على الشخص الذي تقيّمه؟')),
                    for (var i = 0; i < observerItems.length; i++)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${i + 1}. ${observerItems[i].text}'),
                            const SizedBox(height: 8),
                            Row(children: [
                              for (final o in scale)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: ChoiceChip(
                                      label: SizedBox(width: double.infinity, child: Center(child: Text('${o.value}'))),
                                      selected: _answers[observerItems[i].id] == o.value,
                                      selectedColor: cs.primaryContainer,
                                      showCheckmark: false,
                                      onSelected: (_) => setState(() => _answers[observerItems[i].id] = o.value),
                                    ),
                                  ),
                                ),
                            ]),
                          ]),
                        ),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: complete ? _finish : null, child: Text(complete ? 'حفظ التقييم' : 'أجبت عن ${_answers.length} من ${observerItems.length}')),
                  ),
                ),
              ]),
      ),
    );
  }
}

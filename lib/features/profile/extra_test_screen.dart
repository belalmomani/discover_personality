import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/extra_test.dart';
import '../../data/scoring/extra_scoring.dart';
import 'extra_result_screen.dart';

/// All items on one scrollable page; the calculate button stays disabled until everything is answered.
class ExtraTestScreen extends ConsumerStatefulWidget {
  const ExtraTestScreen({super.key, required this.test});
  final ExtraTest test;
  @override
  ConsumerState<ExtraTestScreen> createState() => _ExtraTestScreenState();
}

class _ExtraTestScreenState extends ConsumerState<ExtraTestScreen> {
  late final Map<int, int> _answers;

  @override
  void initState() {
    super.initState();
    // Restore answers from an unfinished attempt (only ids that still exist in this test).
    final ids = widget.test.items.map((i) => i.id).toSet();
    final saved = ref.read(extraProgressProvider)[widget.test.id] ?? const <int, int>{};
    _answers = {for (final e in saved.entries) if (ids.contains(e.key)) e.key: e.value};
  }

  Future<void> _finish() async {
    await ref.read(extraResultsProvider.notifier).save(widget.test.id, _answers);
    await ref.read(extraProgressProvider.notifier).clearTest(widget.test.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ExtraResultScreen(test: widget.test)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    final scale = ref.watch(questionBankProvider).scale;
    final complete = ExtraScoring.isComplete(t, _answers);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.title, style: const TextStyle(fontSize: 16))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(t.note, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(scale.map((s) => '${s.value} = ${s.label}').join('\n')),
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < t.items.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1}. ${t.items[i].text}'),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final o in scale)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: SizedBox(width: double.infinity, child: Center(child: Text('${o.value}'))),
                                selected: _answers[t.items[i].id] == o.value,
                                selectedColor: cs.primaryContainer,
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() => _answers[t.items[i].id] = o.value);
                                  ref.read(extraProgressProvider.notifier).setAnswer(t.id, t.items[i].id, o.value);
                                },
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
              child: FilledButton(
                onPressed: complete ? _finish : null,
                child: Text(complete ? 'احسب النتيجة' : 'أجبت عن ${_answers.length} من ${t.items.length}'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

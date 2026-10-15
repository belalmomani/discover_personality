import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import 'review_screen.dart';

/// No ads are ever placed on this screen.
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key, this.fromReview = false});

  /// When true, answering a question returns to the review screen.
  final bool fromReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(questionBankProvider);
    final state = ref.watch(assessmentProvider);
    final notifier = ref.read(assessmentProvider.notifier);
    final qs = bank.questions;
    final index = state.index.clamp(0, qs.length - 1);
    final q = qs[index];
    final selected = state.answers[q.id];

    Future<void> choose(int v) async {
      await notifier.answer(q.id, v);
      if (!context.mounted) return;
      if (fromReview) {
        Navigator.of(context).pop();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!context.mounted) return;
      if (index < qs.length - 1) {
        await notifier.goTo(index + 1);
      } else {
        pushScreen(context, const ReviewScreen());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('السؤال ${index + 1} من ${qs.length}'),
        actions: [
          TextButton(
            onPressed: () => pushScreen(context, const ReviewScreen()),
            child: const Text('مراجعة'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(minHeight: 10, value: state.answers.length / qs.length),
                ),
              ),
              const SizedBox(width: 12),
              Text('${state.answers.length}/${qs.length}'),
            ]),
            const SizedBox(height: 24),
            Text(q.text, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(children: [
                for (final o in bank.scale)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: selected == o.value
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: CircleAvatar(radius: 14, child: Text('${o.value}')),
                        title: Text(o.label),
                        trailing: selected == o.value ? const Icon(Icons.check_circle) : null,
                        onTap: () => choose(o.value),
                      ),
                    ),
                  ),
              ]),
            ),
            if (!fromReview)
              Row(children: [
                OutlinedButton.icon(
                  onPressed: index > 0 ? () => notifier.goTo(index - 1) : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('السابق'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: index < qs.length - 1 ? () => notifier.goTo(index + 1) : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('التالي'),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}

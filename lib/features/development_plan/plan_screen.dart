import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/models/dev_plan.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, required this.resultId});
  final String resultId;

  Future<String?> _edit(BuildContext context, String title, String initial, {int lines = 3}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLines: lines, minLines: 1, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _commit(WidgetRef ref, DevPlan plan) async {
    await ref.read(plansProvider.notifier).commit();
    await ref.read(syncServiceProvider).syncPlan(plan); // best effort
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final matches = history.where((r) => r.id == resultId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطة 30 يومًا')),
        body: const EmptyView(icon: Icons.event_busy, message: 'لا يوجد تقرير مرتبط بهذه الخطة.'),
      );
    }
    final saved = matches.first;
    final plan = ref.watch(plansProvider)[saved.id];
    if (plan == null) {
      // Create the plan outside of build (state must not change while building).
      Future<void>.microtask(() => ref.read(plansProvider.notifier).ensure(saved));
      return Scaffold(
        appBar: AppBar(title: const Text('خطة التطوير لمدة 30 يومًا')),
        body: const LoadingView(message: 'جارٍ إنشاء خطتك...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('خطة التطوير لمدة 30 يومًا'),
        actions: [
          IconButton(
            tooltip: 'إنشاء خطة جديدة',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('إنشاء خطة جديدة؟'),
                  content: const Text('ستُستبدل الخطة الحالية وتعديلاتك وتقدمك.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد')),
                  ],
                ),
              );
              if (ok == true) await ref.read(plansProvider.notifier).regenerate(saved);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'مقياس الإنجاز',
            icon: Icons.donut_large,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ScoreBar(label: 'المهام المنجزة', fraction: plan.completion, valueText: '${plan.doneCount} / ${plan.days.length}', highlight: true),
              const Text('الخطة مبدئية ومولّدة محليًا من نتائجك؛ عدّل أي مهمة أو هدف بما يناسبك.'),
            ]),
          ),
          SectionCard(
            title: 'ثلاثة أهداف قابلة للقياس',
            icon: Icons.track_changes,
            child: Column(children: [
              for (final g in plan.goals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(g.title),
                  subtitle: Text('${g.current} من ${g.target} ${g.unit}'),
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: g.current > 0
                        ? () {
                            g.current--;
                            _commit(ref, plan);
                          }
                        : null,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      g.current++;
                      _commit(ref, plan);
                    },
                  ),
                  onLongPress: () async {
                    final t = await _edit(context, 'تعديل الهدف', g.title);
                    if (t != null && t.isNotEmpty) {
                      g.title = t;
                      await _commit(ref, plan);
                    }
                  },
                ),
              const Align(alignment: AlignmentDirectional.centerStart, child: Text('اضغط مطولًا على الهدف لتعديل عنوانه.', style: TextStyle(fontSize: 12))),
            ]),
          ),
          for (final w in plan.weeks)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ExpansionTile(
                shape: const Border(),
                title: Text('الأسبوع ${w.week}: ${w.title}'),
                subtitle: Text('${plan.days.where((d) => _weekOf(d.day) == w.week && d.done).length} / ${plan.days.where((d) => _weekOf(d.day) == w.week).length} منجزة'),
                childrenPadding: const EdgeInsets.all(12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('الهدف: ${w.goal}'),
                    subtitle: Text('المقياس: ${w.metric}'),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () async {
                      final g = await _edit(context, 'تعديل هدف الأسبوع', w.goal);
                      if (g != null && g.isNotEmpty) {
                        w.goal = g;
                        await _commit(ref, plan);
                      }
                    },
                  ),
                  for (final d in plan.days.where((d) => _weekOf(d.day) == w.week))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: d.done,
                      title: Text('اليوم ${d.day}: ${d.text}'),
                      subtitle: d.note.isEmpty ? null : Text('ملاحظتي: ${d.note}'),
                      secondary: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          final t = await _edit(context, 'تعديل مهمة اليوم ${d.day}', d.text);
                          if (t != null && t.isNotEmpty) {
                            d.text = t;
                            await _commit(ref, plan);
                          }
                        },
                      ),
                      onChanged: (v) {
                        d.done = v ?? false;
                        _commit(ref, plan);
                      },
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(w.review.isEmpty ? 'كتابة مراجعة الأسبوع' : 'مراجعتي: ${w.review}'),
                    onPressed: () async {
                      final t = await _edit(context, 'مراجعة الأسبوع ${w.week}', w.review, lines: 5);
                      if (t != null) {
                        w.review = t;
                        await _commit(ref, plan);
                      }
                    },
                  ),
                ],
              ),
            ),
          SectionCard(
            title: 'ملخص اليوم الثلاثين',
            icon: Icons.flag_circle_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.finalSummary.isEmpty ? 'اكتب هنا ما أنجزته وما تعلمته وما ستواصله.' : plan.finalSummary),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final t = await _edit(context, 'ملخص اليوم 30', plan.finalSummary, lines: 6);
                  if (t != null) {
                    plan.finalSummary = t;
                    await _commit(ref, plan);
                  }
                },
                child: const Text('كتابة / تعديل الملخص'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static int _weekOf(int day) => ((day - 1) ~/ 7 + 1).clamp(1, 4);
}

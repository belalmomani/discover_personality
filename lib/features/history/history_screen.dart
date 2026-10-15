import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/models/saved_result.dart';
import '../assessment/intro_screen.dart';
import '../development_plan/plan_screen.dart';
import '../results/results_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final plans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل التقدم')),
      body: SafeArea(
        child: history.isEmpty
            ? EmptyView(
                icon: Icons.timeline,
                message: 'لا توجد نتائج بعد. أكمل الاختبار لتظهر هنا ويمكنك مقارنتها لاحقًا.',
                action: FilledButton(onPressed: () => pushScreen(context, const IntroScreen()), child: const Text('ابدأ الاختبار')),
              )
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (history.length >= 2) _CompareCard(newer: history[0], older: history[1]),
                for (final h in history)
                  Card(
                    child: ListTile(
                      title: Text('${arabicDate(h.createdAt)} • ${h.result.mbtiType} • ${h.result.arfdCode}'),
                      subtitle: Text(plans[h.id] == null
                          ? 'لم تبدأ خطة 30 يومًا'
                          : 'الخطة: ${plans[h.id]!.doneCount} من 30 مهمة منجزة${h.synced ? " • متزامن" : ""}'),
                      onTap: () => pushScreen(context, ResultsScreen(resultId: h.id)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'plan') {
                            pushScreen(context, PlanScreen(resultId: h.id));
                          } else if (v == 'delete') {
                            await ref.read(historyProvider.notifier).remove(h.id);
                            await ref.read(plansProvider.notifier).removeFor(h.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'plan', child: Text('فتح الخطة')),
                          PopupMenuItem(value: 'delete', child: Text('حذف من الجهاز')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => pushScreen(context, const IntroScreen()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة الاختبار'),
                ),
              ]),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.newer, required this.older});
  final SavedResult newer;
  final SavedResult older;

  String _delta(num d) => d > 0 ? '+${d.round()}' : '${d.round()}';

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final n = newer.result.mbti[i];
      final o = older.result.mbti[i];
      rows.add(Text('${n.poleA}/${n.poleB}: ${o.preferred}${o.isClose ? "~" : ""} ← ${n.preferred}${n.isClose ? "~" : ""}  (تغير ${n.poleA}: ${_delta(n.pctA - o.pctA)} نقطة)'));
    }
    final nt = newer.result.enneagramTop;
    final ot = older.result.enneagramTop;
    final arfd = [
      for (var i = 0; i < 4; i++)
        '${newer.result.arfd[i].axis}: ${older.result.arfd[i].avg.toStringAsFixed(2)} ← ${newer.result.arfd[i].avg.toStringAsFixed(2)}',
    ].join('   ');
    return SectionCard(
      title: 'مقارنة آخر نتيجتين',
      icon: Icons.compare,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${arabicDate(older.createdAt)} ← ${arabicDate(newer.createdAt)}'),
        const SizedBox(height: 6),
        ...rows,
        const SizedBox(height: 6),
        Text('Enneagram (الأعلى): ${ot.type} (${ot.score}) ← ${nt.type} (${nt.score})'),
        Text('A-R-F-D: $arfd'),
        const SizedBox(height: 6),
        const Text('تغيّر النتائج بين مرتين قد يعكس الحالة المزاجية أو الظروف وليس بالضرورة تغيّرًا حقيقيًا في شخصيتك. (~ تعني نتيجة متقاربة)', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../data/integrated/integrated_engine.dart';
import '../../data/models/extra_test.dart';
import '../../data/scoring/extra_scoring.dart';
import '../profile/extra_test_screen.dart';
import 'observer_screen.dart';

class IntegratedReportScreen extends ConsumerWidget {
  const IntegratedReportScreen({super.key, required this.resultId});
  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).where((r) => r.id == resultId).toList();
    if (history.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('التحليل المتكامل')), body: const EmptyView(icon: Icons.search_off, message: 'لم يتم العثور على هذا التقرير.'));
    }
    final saved = history.first;
    final tests = ref.watch(extraTestsProvider);
    final extraResults = ref.watch(extraResultsProvider);
    final observers = ref.watch(observersProvider);
    final questions = ref.watch(questionBankProvider).questions;
    final extraAnswers = <String, Map<int, int>>{
      for (final t in tests)
        if (extraResults[t.id] != null && ExtraScoring.isComplete(t, extraResults[t.id]!.answers)) t.id: extraResults[t.id]!.answers,
    };
    final report = IntegratedEngine.build(IntegratedInput(
      questions: questions,
      answers: saved.answers,
      result: saved.result,
      extraTests: tests,
      extraAnswers: extraAnswers,
      observers: observers,
    ));
    ExtraTest? testById(String id) {
      final l = tests.where((t) => t.id == id);
      return l.isEmpty ? null : l.first;
    }

    Widget testButton(String id, String label) {
      final t = testById(id);
      if (t == null) return const SizedBox.shrink();
      return OutlinedButton(onPressed: () => pushScreen(context, ExtraTestScreen(test: t)), child: Text(label));
    }

    final cs = Theme.of(context).colorScheme;
    Widget confCard(Confidence c) {
      final color = c.level == ConfidenceLevel.low ? cs.errorContainer : (c.level == ConfidenceLevel.medium ? cs.tertiaryContainer : cs.primaryContainer);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.subject, style: Theme.of(context).textTheme.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text('ثقة ${confidenceName(c.level)}'),
              ),
            ]),
            const SizedBox(height: 6),
            BulletList(c.reasons),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحليل المتكامل'),
        actions: [
          IconButton(
            tooltip: 'نسخ التقرير كنص',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.toText()));
              if (context.mounted) showMessage(context, 'نُسخ التقرير. الصقه في أي تطبيق ملاحظات أو رسالة.');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(title: 'ملف شخصيتك في سطر', icon: Icons.person_search_outlined, child: Text(report.headline)),
          const DisclaimerBanner(),
          SectionCard(
            title: 'كيف تتكامل النتائج',
            icon: Icons.hub_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BulletList(report.themes),
              const SizedBox(height: 8),
              for (final c in report.constructs.where((c) => c.hasData)) ...[
                ScoreBar(label: c.name, fraction: c.pct / 100, valueText: '${levelName(c.level)} ${c.pct.round()}٪', highlight: c.level == Level.high),
                Text('${convergenceName(c.convergence)} • ${c.sources.map((s) => "${s.label} ${s.pct.round()}٪").join(" • ")}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
              ],
            ]),
          ),
          SectionCard(
            title: 'نقاط القوة',
            icon: Icons.thumb_up_alt_outlined,
            child: report.strengths.isEmpty
                ? const Text('لا توجد نقاط قوة بارزة بما يكفي من الدرجات الحالية.')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final s in report.strengths)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('• ${s.text}'),
                          Text('${s.evidence}${s.multiSource ? " • أكثر من مصدر" : ""}', style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                  ]),
          ),
          SectionCard(
            title: 'مصادر التعثر',
            icon: Icons.flag_outlined,
            child: report.stumbles.isEmpty
                ? const Text('لا مصادر تعثر بارزة من الدرجات الحالية.')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final s in report.stumbles)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('• ${s.text}'),
                          Text('${s.evidence}${s.multiSource ? " • أكثر من مصدر" : ""}', style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                  ]),
          ),
          if (report.contradictions.isNotEmpty) SectionCard(title: 'تناقضات محتملة', icon: Icons.compare_arrows, child: BulletList(report.contradictions)),
          SectionCard(title: 'طريقة اتخاذ القرار', icon: Icons.alt_route, child: BulletList(report.decisionLines)),
          SectionCard(
            title: 'التعامل مع الضغط',
            icon: Icons.self_improvement_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BulletList(report.stressLines),
              if (!report.stressMeasured) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  testButton('resilience', 'المرونة النفسية'),
                  testButton('bigfive', 'Big Five'),
                  testButton('psycap', 'رأس المال النفسي'),
                ]),
              ],
            ]),
          ),
          SectionCard(
            title: 'صورتك لدى الآخرين مقابل وصفك لنفسك',
            icon: Icons.visibility_outlined,
            child: _selfOthers(context, report.selfOthers, testById('bigfive')),
          ),
          SectionCard(
            title: 'درجة الثقة في كل نتيجة',
            icon: Icons.verified_outlined,
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('لا نعرض نسبة «دقة» مختلقة. الثقة هنا مستوى (منخفضة / متوسطة / مرتفعة نسبيًا) يُحسب من: اتساق إجاباتك داخل الأسئلة المتقاربة والعكسية، ووضوح الفارق بين الخيارات، ومدى اتفاق مقاييس أخرى أنجزتها، وعدد الأسئلة، وملاحظات جودة الإجابات.'),
              SizedBox(height: 6),
              Text('لا تتجاوز الثقة «متوسطة» ما لم يؤكد النتيجةَ مقياسٌ آخر مستقل. وحتى «المرتفعة نسبيًا» لا تعني صلاحية علمية، فالأسئلة نفسها لم تُحقَّق نفسيًا.'),
            ]),
          ),
          for (final c in report.confidences) confCard(c),
          if (report.extraConfidences.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text('الاختبارات الإضافية', style: Theme.of(context).textTheme.titleSmall)),
            for (final c in report.extraConfidences) confCard(c),
          ],
          if (report.flags.isNotEmpty) SectionCard(title: 'ملاحظات على جودة إجاباتك', icon: Icons.rule, child: BulletList([for (final f in report.flags) f.text])),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.toText()));
              if (context.mounted) showMessage(context, 'نُسخ التقرير كنص.');
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('نسخ التقرير كنص'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _selfOthers(BuildContext context, SelfOthers so, ExtraTest? bigfive) {
    if (so.needsBigFive) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('لم يُقَس بعد. للمقارنة نحتاج وصفك لنفسك (اختبار Big Five) ثم تقييم شخص يعرفك على الأبعاد نفسها.'),
        const SizedBox(height: 8),
        if (bigfive != null) OutlinedButton(onPressed: () => pushScreen(context, ExtraTestScreen(test: bigfive)), child: const Text('اختبار Big Five')),
      ]);
    }
    if (so.observerCount == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('لم يُقَس بعد: لا توجد تقييمات من أشخاص يعرفونك، ولن نخمّن كيف يراك الآخرون.'),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => pushScreen(context, const ObserverScreen()), child: const Text('اطلب رأي شخص يعرفك')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('عدد المقيِّمين: ${so.observerCount}${so.preliminary ? " — مبدئي، يُفضَّل 3 فأكثر" : ""}'),
      const SizedBox(height: 6),
      for (final r in so.rows) ...[
        Text(r.dimName, style: Theme.of(context).textTheme.titleSmall),
        ScoreBar(label: 'وصفك لنفسك', fraction: r.selfPct / 100, valueText: '${r.selfPct.round()}٪'),
        ScoreBar(label: 'كما يراك الآخرون', fraction: r.othersPct / 100, valueText: '${r.othersPct.round()}٪', highlight: true),
        Text(r.status, style: Theme.of(context).textTheme.bodySmall),
        if (r.observers >= 2 && r.observerSpread >= 25) Text('المقيِّمون أنفسهم مختلفون في هذا البعد.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
      const Text('تنبيه: يقيس الآخرون ما يرونه من سلوكك، وقد يتأثرون بنوع علاقتهم بك؛ والتقييم هنا بعبارتين لكل بُعد فهو تقريبي.', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => pushScreen(context, const ObserverScreen()), child: const Text('إضافة مقيِّم آخر')),
    ]);
  }
}

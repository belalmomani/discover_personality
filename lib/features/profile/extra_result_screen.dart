import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/models/extra_test.dart';
import '../../data/scoring/extra_scoring.dart';
import 'extra_test_screen.dart';

class ExtraResultScreen extends ConsumerWidget {
  const ExtraResultScreen({super.key, required this.test});
  final ExtraTest test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(extraResultsProvider)[test.id];
    if (saved == null || !ExtraScoring.isComplete(test, saved.answers)) {
      return Scaffold(
        appBar: AppBar(title: Text(test.title, style: const TextStyle(fontSize: 16))),
        body: EmptyView(
          icon: Icons.fact_check_outlined,
          message: 'لا توجد نتيجة لهذا الاختبار بعد.',
          action: FilledButton(onPressed: () => pushScreen(context, ExtraTestScreen(test: test)), child: const Text('ابدأ الاختبار')),
        ),
      );
    }
    final score = ExtraScoring.compute(test, saved.answers);
    return Scaffold(
      appBar: AppBar(title: Text(test.title, style: const TextStyle(fontSize: 16))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('تاريخ الاختبار: ${arabicDate(saved.createdAt)}'),
          const SizedBox(height: 8),
          if (score.headline != null)
            SectionCard(title: 'الأقرب لك', icon: Icons.favorite_border, child: Text(score.headline!)),
          if (score.topDims.isNotEmpty)
            SectionCard(
              title: 'الأعلى لديك',
              icon: Icons.emoji_events_outlined,
              child: BulletList([for (final d in score.topDims) '${d.dim.name} (${d.pct.round()}٪)']),
            ),
          SectionCard(
            title: 'النتائج التفصيلية',
            icon: Icons.bar_chart,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final d in score.dims) ...[
                ScoreBar(label: d.dim.name, fraction: d.pct / 100, valueText: '${d.pct.round()}٪ (متوسط ${d.avg.toStringAsFixed(2)})', highlight: d.level == 'high'),
                Text(score.interpret(d), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
            ]),
          ),
          SectionCard(
            title: 'كيف تقرأ هذه النتيجة؟',
            icon: Icons.info_outline,
            child: BulletList([
              test.note,
              'النسبة وصفية = ((المتوسط − 1) ÷ 4) × 100، وليست ترتيبًا بين الناس. «مرتفع» أعلى من 65٪، و«منخفض» أقل من 35٪.',
              'استبيان تقدير ذاتي: يعكس كيف ترى نفسك الآن، وقد يتغير مع الحالة والظروف.',
              'ليس تشخيصًا نفسيًا ولا حكمًا نهائيًا، ولم يُتحقق من صلاحية هذه الأسئلة علميًا.',
            ]),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ExtraTestScreen(test: test))),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة الاختبار'),
          ),
        ]),
      ),
    );
  }
}

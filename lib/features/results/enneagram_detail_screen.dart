import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../data/report/report_content.dart';
import '../../data/scoring/scoring_engine.dart';
import '../../data/scoring/scoring_result.dart';

class EnneagramDetailScreen extends StatelessWidget {
  const EnneagramDetailScreen({super.key, required this.result});
  final ScoringResult result;

  @override
  Widget build(BuildContext context) {
    final top = result.enneagramTop.score;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل Enneagram')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'الأنماط المرتبة حسب الدرجة',
            child: Column(children: [
              for (final s in result.enneagramRanking)
                ScoreBar(
                  label: enneagramTypes[s.type]!.name,
                  fraction: s.score / 20,
                  valueText: '${s.score} / 20',
                  highlight: s.score >= top - ScoringEngine.enneagramCloseThreshold,
                ),
            ]),
          ),
          SectionCard(
            title: result.enneagramConclusive ? 'النمط المرشح' : 'أنماط محتملة متقاربة',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!result.enneagramConclusive)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('درجات هذه الأنماط متقاربة (ضمن نقطتين من الأعلى)، والاختبار لا يحسم بينها.'),
                ),
              for (final c in result.enneagramCandidates) ...[
                Text(enneagramTypes[c.type]!.name, style: Theme.of(context).textTheme.titleSmall),
                Text('الدافع: ${enneagramTypes[c.type]!.motivation}'),
                Text('قوة محتملة: ${enneagramTypes[c.type]!.strength}'),
                Text('تحدٍ محتمل: ${enneagramTypes[c.type]!.challenge}'),
                Text('للتأمل: ${enneagramTypes[c.type]!.reflection}'),
                const Divider(),
              ],
            ]),
          ),
          const SectionCard(
            title: 'حدود هذا الاختبار',
            child: Text('أربعة أسئلة لكل نمط لا تكفي لاستنتاج الجناح أو الغرائز أو مستويات الصحة النفسية، ولذلك لا يعرضها التطبيق.'),
          ),
          const DisclaimerBanner(),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../data/report/report_content.dart';
import '../../data/scoring/scoring_engine.dart';
import '../../data/scoring/scoring_result.dart';

class MbtiDetailScreen extends StatelessWidget {
  const MbtiDetailScreen({super.key, required this.result});
  final ScoringResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل MBTI: ${result.mbtiType}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionCard(
            title: 'كيف حُسبت النتيجة؟',
            child: Text(
              'لكل قطب ثلاثة أسئلة. النسبة الوصفية = ((المتوسط − 1) ÷ 4) × 100. يُعد البعدان متقاربين إذا كان الفارق '
              'أقل من ${ScoringEngine.mbtiCloseThresholdPct} نقاط، وعندها لا نجزم بتفضيل. النسب وصفية وليست احتمالات علمية.',
            ),
          ),
          for (final p in result.mbti) _PairCard(p: p),
          const DisclaimerBanner(),
        ]),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.p});
  final MbtiPairResult p;

  @override
  Widget build(BuildContext context) {
    final a = mbtiPoles[p.poleA]!;
    final b = mbtiPoles[p.poleB]!;
    return SectionCard(
      title: '${a.name} مقابل ${b.name}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ScoreBar(label: a.name, fraction: p.pctA / 100, valueText: '${p.pctA.round()}٪ (متوسط ${p.avgA.toStringAsFixed(2)})', highlight: !p.isClose && p.preferred == p.poleA),
        ScoreBar(label: b.name, fraction: p.pctB / 100, valueText: '${p.pctB.round()}٪ (متوسط ${p.avgB.toStringAsFixed(2)})', highlight: !p.isClose && p.preferred == p.poleB),
        const SizedBox(height: 8),
        Text('الفارق: ${p.diff.round()} نقطة'),
        const SizedBox(height: 4),
        if (p.isTie)
          const Text('تعادل تام: لا يمكن ترجيح أي قطب.')
        else if (p.isClose)
          const Text('النتيجة متقاربة وغير حاسمة بين القطبين.')
        else
          Text(mbtiPoles[p.preferred]!.description),
      ]),
    );
  }
}

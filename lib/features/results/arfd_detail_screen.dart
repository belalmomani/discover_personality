import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../data/report/report_content.dart';
import '../../data/scoring/scoring_result.dart';

class ArfdDetailScreen extends StatelessWidget {
  const ArfdDetailScreen({super.key, required this.result});
  final ScoringResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الرمز السلوكي ${result.arfdCode}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionCard(
            title: 'ما هو A-R-F-D؟',
            child: Text(
              'نظام أصلي خاص بهذا التطبيق (وليس مقياسًا نفسيًا معتمدًا) يصف أربعة محاور: التحليل، إدارة المخاطر، التنفيذ والاستمرارية، دوافع الإنجاز. '
              'الأسئلة العكسية تُحسب بالقاعدة: الدرجة الجديدة = 6 − الدرجة الأصلية. متوسط كل محور من ثلاثة أسئلة، ويُقرَّب في الرمز بالتقريب المعتاد (أقرب عدد صحيح).',
            ),
          ),
          for (final a in result.arfd)
            SectionCard(
              title: arfdAxes[a.axis]!.name,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ScoreBar(label: 'المتوسط', fraction: (a.avg - 1) / 4, valueText: '${a.avg.toStringAsFixed(2)} من 5 → ${a.rounded}', highlight: true),
                const SizedBox(height: 6),
                Text(arfdAxes[a.axis]!.meaning),
                const SizedBox(height: 6),
                Text(a.rounded <= 2 ? arfdAxes[a.axis]!.low : (a.rounded == 3 ? arfdAxes[a.axis]!.mid : arfdAxes[a.axis]!.high)),
                const SizedBox(height: 6),
                Text('للتأمل: ${arfdAxes[a.axis]!.reflection}'),
              ]),
            ),
          const DisclaimerBanner(),
        ]),
      ),
    );
  }
}

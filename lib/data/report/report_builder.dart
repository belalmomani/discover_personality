import '../scoring/scoring_result.dart';
import 'report_content.dart';

class Report {
  const Report({
    required this.summary,
    required this.mbtiLines,
    required this.enneagramLines,
    required this.arfdLines,
    required this.strengths,
    required this.challenges,
    required this.contradictions,
    required this.reflectionQuestions,
    required this.notes,
  });

  final String summary;
  final List<String> mbtiLines;
  final List<String> enneagramLines;
  final List<String> arfdLines;
  final List<String> strengths;
  final List<String> challenges;
  final List<String> contradictions;
  final List<String> reflectionQuestions;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'mbtiLines': mbtiLines,
        'enneagramLines': enneagramLines,
        'arfdLines': arfdLines,
        'strengths': strengths,
        'challenges': challenges,
        'contradictions': contradictions,
        'reflectionQuestions': reflectionQuestions,
        'notes': notes,
      };
}

/// Deterministic, local report generation (no network, no AI).
class ReportBuilder {
  ReportBuilder._();

  static const double strongGapPct = 20.0;

  static Report build(ScoringResult r) {
    final top = r.enneagramTop;
    final topInfo = enneagramTypes[top.type]!;

    final mbtiLines = <String>[];
    for (final p in r.mbti) {
      final pref = mbtiPoles[p.preferred]!;
      final other = p.preferred == p.poleA ? p.poleB : p.poleA;
      final line = StringBuffer()
        ..write('${p.poleA} ${p.pctA.round()}٪ مقابل ${p.poleB} ${p.pctB.round()}٪ '
            '(الفارق ${p.diff.round()} نقطة). ');
      if (p.isClose) {
        line.write('النتيجة متقاربة وغير حاسمة؛ لا يمكن الجزم بتفضيل ${pref.name} على ${mbtiPoles[other]!.name}.');
      } else {
        line.write('التفضيل المرشح: ${pref.name}. ${pref.description}');
      }
      mbtiLines.add(line.toString());
    }

    final enneaLines = <String>[];
    if (r.enneagramConclusive) {
      enneaLines.add('النمط المرشح: ${topInfo.name} (${top.score} من 20). ${topInfo.motivation}');
    } else {
      final names = r.enneagramCandidates.map((c) => 'النمط ${c.type} (${c.score})').join('، ');
      enneaLines.add('الدرجات متقاربة، والاختبار لا يحسم بينها. الأنماط المحتملة: $names.');
    }
    enneaLines.add('هذه الأسئلة لا تكفي لاستنتاج الجناح أو الغرائز أو مستويات الصحة النفسية.');

    final arfdLines = <String>[];
    for (final a in r.arfd) {
      final info = arfdAxes[a.axis]!;
      final level = a.rounded <= 2 ? info.low : (a.rounded == 3 ? info.mid : info.high);
      arfdLines.add('${info.name}: المتوسط ${a.avg.toStringAsFixed(2)} من 5 (يُقرَّب إلى ${a.rounded}). $level');
    }

    final strengths = <String>[];
    final challenges = <String>[];
    for (final p in r.mbti) {
      if (!p.isClose) {
        strengths.add(mbtiPoles[p.preferred]!.strength);
        challenges.add(mbtiPoles[p.preferred]!.challenge);
      }
    }
    for (final c in r.enneagramCandidates.take(r.enneagramConclusive ? 1 : 2)) {
      strengths.add(enneagramTypes[c.type]!.strength);
      challenges.add(enneagramTypes[c.type]!.challenge);
    }
    for (final a in r.arfd) {
      if (a.rounded >= 4) strengths.add('${arfdAxes[a.axis]!.name}: ${arfdAxes[a.axis]!.high}');
      if (a.rounded <= 2) challenges.add('${arfdAxes[a.axis]!.name}: ${arfdAxes[a.axis]!.low}');
    }

    final contradictions = _contradictions(r);

    final reflections = <String>[
      enneagramTypes[top.type]!.reflection,
      for (final a in r.arfd.where((x) => x.rounded <= 3)) arfdAxes[a.axis]!.reflection,
      'أي جزء من هذه النتائج لا يشبهك؟ وما الموقف الذي يوضح السبب؟',
      'اسأل شخصًا يعرفك جيدًا: هل يرى هذه الصفات فيك؟',
    ];

    final summary = 'الرمز المرشح لتفضيلاتك الحالية: MBTI ${r.mbtiType}'
        '${r.mbtiAnyClose ? " (مع أبعاد متقاربة)" : ""}، '
        '${r.enneagramConclusive ? "النمط ${top.type}" : "أنماط محتملة متقاربة"}، '
        'ورمز A-R-F-D ${r.arfdCode}. هذه فرضيات للتأمل وليست حكمًا نهائيًا.';

    return Report(
      summary: summary,
      mbtiLines: mbtiLines,
      enneagramLines: enneaLines,
      arfdLines: arfdLines,
      strengths: strengths,
      challenges: challenges,
      contradictions: contradictions,
      reflectionQuestions: reflections,
      notes: const [
        disclaimerShort,
        'رمز A-R-F-D نظام أصلي خاص بالتطبيق وليس مقياسًا نفسيًا معتمدًا.',
        'ما تقيسه الإجابات مباشرة هو درجاتك؛ أما الأوصاف فهي تفسير محتمل.',
      ],
    );
  }

  static List<String> _contradictions(ScoringResult r) {
    final out = <String>[];
    final pairs = {for (final p in r.mbti) p.poleA: p};
    final j = pairs['J']!;
    final tf = pairs['T']!;
    final f = r.axis('F');
    final risk = r.axis('R');
    final d = r.axis('D');
    final top = r.enneagramTop.type;

    if (j.preferred == 'J' && j.diff >= strongGapPct && f.rounded <= 2) {
      out.add('تفضيل واضح للتخطيط والحسم (J) مع درجة منخفضة في التنفيذ والاستمرارية (F): قد تخطط جيدًا لكن يصعب الاستمرار؛ تحقق إن كان السبب الحماس أم الخطة.');
    }
    if (j.preferred == 'P' && j.diff >= strongGapPct && f.rounded >= 4) {
      out.add('تفضيل المرونة (P) مع تنفيذ واستمرارية عاليين (F): قد تكون مرنًا في الطريقة منضبطًا في النتيجة.');
    }
    if (tf.preferred == 'T' && tf.diff >= strongGapPct && top == 2) {
      out.add('تفضيل التفكير المنطقي (T) مع نمط العطاء (2) كأعلى درجة: قد تعطي بدافع المنطق أو الواجب أكثر من العاطفة؛ تأمل دافعك.');
    }
    if (top == 7 && risk.rounded <= 2) {
      out.add('نمط التنوع والتجارب (7) مع تجنب للمخاطر (R منخفض): قد تحب التجديد لكن بشرط الأمان.');
    }
    if (top == 3 && d.rounded <= 2) {
      out.add('نمط الإنجاز (3) مع درجة منخفضة في دوافع الإنجاز (D): تحقق مما إذا كانت أهدافك تعبّر عن أولوياتك أم عن توقعات الآخرين.');
    }
    return out;
  }

  /// Minimal payload for the optional AI explainer: scores only, never raw answers.
  static Map<String, dynamic> aiPayload(ScoringResult r) => {
        'locale': 'ar',
        'mbti_type': r.mbtiType,
        'mbti_percent': {
          for (final p in r.mbti) ...{p.poleA: p.pctA.round(), p.poleB: p.pctB.round()}
        },
        'enneagram_scores': {for (final s in r.enneagramRanking) '${s.type}': s.score},
        'enneagram_conclusive': r.enneagramConclusive,
        'arfd_code': r.arfdCode,
        'arfd_averages': {for (final a in r.arfd) a.axis: double.parse(a.avg.toStringAsFixed(2))},
      };
}

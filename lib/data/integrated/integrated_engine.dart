import 'dart:math' as math;

import '../models/extra_test.dart';
import '../models/question.dart';
import '../report/report_builder.dart';
import '../scoring/extra_scoring.dart';
import '../scoring/scoring_result.dart';
import 'observer.dart';

/// Deterministic integration of all results. No AI, no randomness.
/// Thresholds below are explicit design choices (shown to the user), NOT validated norms.

enum Level { low, mid, high }

Level levelOf(double pct) => pct < 35 ? Level.low : (pct > 65 ? Level.high : Level.mid);

String levelName(Level l) => l == Level.low ? 'منخفض' : (l == Level.high ? 'مرتفع' : 'متوسط');

enum Convergence { none, good, partial, divergent }

class SourceValue {
  const SourceValue(this.label, this.pct);
  final String label;
  final double pct;
}

class Construct {
  const Construct(this.id, this.name, this.sources);
  final String id;
  final String name;
  final List<SourceValue> sources;

  bool get hasData => sources.isNotEmpty;
  double get pct => sources.map((s) => s.pct).reduce((a, b) => a + b) / sources.length;
  Level get level => levelOf(pct);
  double get spread => sources.length < 2 ? 0 : sources.map((s) => s.pct).reduce(math.max) - sources.map((s) => s.pct).reduce(math.min);
  Convergence get convergence {
    if (sources.length < 2) return Convergence.none;
    if (spread <= 20) return Convergence.good;
    if (spread <= 35) return Convergence.partial;
    return Convergence.divergent;
  }
}

String convergenceName(Convergence c) {
  switch (c) {
    case Convergence.none:
      return 'مصدر واحد فقط';
    case Convergence.good:
      return 'مصادر متفقة';
    case Convergence.partial:
      return 'اتفاق جزئي';
    case Convergence.divergent:
      return 'مصادر متباينة';
  }
}

class QualityFlag {
  const QualityFlag(this.id, this.text);
  final String id;
  final String text;
}

enum ConfidenceLevel { low, medium, highRelative }

String confidenceName(ConfidenceLevel l) => l == ConfidenceLevel.low ? 'منخفضة' : (l == ConfidenceLevel.medium ? 'متوسطة' : 'مرتفعة نسبيًا');

class Confidence {
  const Confidence(this.subject, this.level, this.points, this.reasons);
  final String subject;
  final ConfidenceLevel level;
  final int points;
  final List<String> reasons;
}

class Statement {
  const Statement(this.text, this.evidence, {required this.multiSource});
  final String text;
  final String evidence;
  final bool multiSource;
}

class SelfOthersRow {
  const SelfOthersRow({required this.dimName, required this.selfPct, required this.othersPct, required this.observers, required this.observerSpread});
  final String dimName;
  final double selfPct;
  final double othersPct;
  final int observers;
  final double observerSpread;
  double get gap => othersPct - selfPct;
  String get status {
    final g = gap.abs();
    if (g < 15) return 'متقاربة';
    if (g < 25) return 'فرق متوسط';
    return gap > 0 ? 'الآخرون يرونك أعلى مما تصف نفسك' : 'الآخرون يرونك أقل مما تصف نفسك';
  }
}

class SelfOthers {
  const SelfOthers({required this.needsBigFive, required this.observerCount, required this.rows});
  final bool needsBigFive;
  final int observerCount;
  final List<SelfOthersRow> rows;
  bool get measured => !needsBigFive && observerCount > 0 && rows.isNotEmpty;
  bool get preliminary => observerCount < 3;
}

class IntegratedInput {
  const IntegratedInput({
    required this.questions,
    required this.answers,
    required this.result,
    required this.extraTests,
    required this.extraAnswers,
    required this.observers,
  });
  final List<Question> questions;
  final Map<int, int> answers;
  final ScoringResult result;
  final List<ExtraTest> extraTests;

  /// testId -> answers (only completed tests).
  final Map<String, Map<int, int>> extraAnswers;
  final List<ObserverRating> observers;
}

double _mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;

double _sd(Iterable<double> v) {
  final l = v.toList();
  if (l.length < 2) return 0;
  final m = _mean(l);
  return math.sqrt(l.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / l.length);
}

class IntegratedReport {
  const IntegratedReport({
    required this.headline,
    required this.constructs,
    required this.themes,
    required this.strengths,
    required this.stumbles,
    required this.contradictions,
    required this.decisionLines,
    required this.stressLines,
    required this.stressMeasured,
    required this.selfOthers,
    required this.flags,
    required this.confidences,
    required this.extraConfidences,
    this.careerLines = const [],
    this.wellbeingLines = const [],
  });
  final List<String> careerLines;
  final List<String> wellbeingLines;
  final String headline;
  final List<Construct> constructs;
  final List<String> themes;
  final List<Statement> strengths;
  final List<Statement> stumbles;
  final List<String> contradictions;
  final List<String> decisionLines;
  final List<String> stressLines;
  final bool stressMeasured;
  final SelfOthers selfOthers;
  final List<QualityFlag> flags;
  final List<Confidence> confidences;
  final List<Confidence> extraConfidences;

  String toText() {
    final b = StringBuffer();
    b.writeln('التحليل المتكامل — اكتشف شخصيتك');
    b.writeln('(وصف أولي للتأمل الذاتي وليس تشخيصًا؛ أسئلة غير محققة علميًا)');
    b.writeln();
    b.writeln(headline);
    b.writeln();
    b.writeln('## كيف تتكامل النتائج');
    for (final t in themes) {
      b.writeln('- $t');
    }
    b.writeln();
    b.writeln('## المحاور المدمجة');
    for (final c in constructs.where((c) => c.hasData)) {
      b.writeln('- ${c.name}: ${levelName(c.level)} (${c.pct.round()}٪) — ${convergenceName(c.convergence)}؛ المصادر: ${c.sources.map((s) => "${s.label} ${s.pct.round()}٪").join("، ")}');
    }
    b.writeln();
    b.writeln('## نقاط القوة');
    for (final s in strengths) {
      b.writeln('- ${s.text} (${s.evidence})');
    }
    b.writeln();
    b.writeln('## مصادر التعثر');
    for (final s in stumbles) {
      b.writeln('- ${s.text} (${s.evidence})');
    }
    if (contradictions.isNotEmpty) {
      b.writeln();
      b.writeln('## تناقضات محتملة');
      for (final c in contradictions) {
        b.writeln('- $c');
      }
    }
    if (careerLines.isNotEmpty) {
      b.writeln();
      b.writeln('## الميول المهنية');
      for (final l in careerLines) {
        b.writeln('- $l');
      }
    }
    if (wellbeingLines.isNotEmpty) {
      b.writeln();
      b.writeln('## الرفاه والنظرة للنفس');
      for (final l in wellbeingLines) {
        b.writeln('- $l');
      }
    }
    b.writeln();
    b.writeln('## اتخاذ القرار');
    for (final l in decisionLines) {
      b.writeln('- $l');
    }
    b.writeln();
    b.writeln('## التعامل مع الضغط');
    for (final l in stressLines) {
      b.writeln('- $l');
    }
    b.writeln();
    b.writeln('## صورتك لدى الآخرين مقابل وصفك لنفسك');
    if (selfOthers.needsBigFive) {
      b.writeln('- لم يُقَس: أكمل اختبار Big Five أولًا.');
    } else if (selfOthers.observerCount == 0) {
      b.writeln('- لم يُقَس بعد: لا توجد تقييمات من أشخاص يعرفونك.');
    } else {
      b.writeln('- عدد المقيِّمين: ${selfOthers.observerCount}${selfOthers.preliminary ? " (مبدئي؛ يُفضّل 3 فأكثر)" : ""}');
      for (final r in selfOthers.rows) {
        b.writeln('- ${r.dimName}: أنت ${r.selfPct.round()}٪ • الآخرون ${r.othersPct.round()}٪ — ${r.status}');
      }
    }
    b.writeln();
    b.writeln('## درجة الثقة في كل نتيجة');
    for (final c in [...confidences, ...extraConfidences]) {
      b.writeln('- ${c.subject}: ${confidenceName(c.level)} — ${c.reasons.join("؛ ")}');
    }
    if (flags.isNotEmpty) {
      b.writeln();
      b.writeln('## ملاحظات على جودة الإجابات');
      for (final f in flags) {
        b.writeln('- ${f.text}');
      }
    }
    return b.toString();
  }
}

class IntegratedEngine {
  IntegratedEngine._();

  // ---------- thresholds (explicit, disclosed)
  static const double closeConvergence = 20; // spread <= 20 points: sources agree
  static const double partialConvergence = 35;
  static const int straightRun = 10; // identical answers in a row
  static const double acquiescenceHigh = 4.3;
  static const double acquiescenceLow = 1.7;
  static const double gapMedium = 15;
  static const double gapLarge = 25;

  // ---------- main-test helpers
  static List<double> _raw(IntegratedInput i, {AssessmentSystem? system, String? dim}) => [
        for (final q in i.questions)
          if ((system == null || q.system == system) && (dim == null || q.dimension == dim)) i.answers[q.id]!.toDouble(),
      ];

  static List<double> _adjusted(IntegratedInput i, AssessmentSystem system, String dim) => [
        for (final q in i.questions)
          if (q.system == system && q.dimension == dim) (q.reverse ? 6 - i.answers[q.id]! : i.answers[q.id]!).toDouble(),
      ];

  static int _longestRun(List<int> v) {
    var best = 0, cur = 0;
    int? last;
    for (final x in v) {
      cur = (x == last) ? cur + 1 : 1;
      last = x;
      if (cur > best) best = cur;
    }
    return best;
  }

  static List<QualityFlag> mainFlags(IntegratedInput i) {
    final flags = <QualityFlag>[];
    final ordered = ([...i.questions]..sort((a, b) => a.id.compareTo(b.id))).map((q) => i.answers[q.id]!).toList();
    final run = _longestRun(ordered);
    if (run >= straightRun) {
      flags.add(QualityFlag('straight', 'ظهر تتابع $run إجابة متطابقة متتالية في الاختبار الرئيسي، وقد يدل على إجابة غير متأنية.'));
    }
    final all = ordered.map((e) => e.toDouble()).toList();
    final mean = _mean(all);
    if (mean > acquiescenceHigh || mean < acquiescenceLow) {
      flags.add(QualityFlag('acquiescence', 'متوسط إجاباتك ${mean.toStringAsFixed(2)} من 5 شديد القرب من أحد الطرفين، وقد يدل على ميل للموافقة (أو الرفض) على كل شيء.'));
    }
    if (_sd(all) < 0.6) {
      flags.add(const QualityFlag('flat', 'تباين إجاباتك ضعيف جدًا، فيصعب التمييز بين سماتك.'));
    }
    // reverse-item contradictions in A-R-F-D
    var contradictions = 0;
    for (final axis in ['A', 'R', 'F', 'D']) {
      final fwd = [for (final q in i.questions) if (q.system == AssessmentSystem.arfd && q.dimension == axis && !q.reverse) i.answers[q.id]!.toDouble()];
      final rev = [for (final q in i.questions) if (q.system == AssessmentSystem.arfd && q.dimension == axis && q.reverse) (6 - i.answers[q.id]!).toDouble()];
      if (fwd.isEmpty || rev.isEmpty) continue;
      if ((rev.first - _mean(fwd)).abs() >= 3) contradictions++;
    }
    if (contradictions >= 2) {
      flags.add(QualityFlag('reverse', 'تعارضت إجاباتك في $contradictions من محاور A-R-F-D مع صياغتها العكسية، وهذا يضعف الثقة في رمز A-R-F-D.'));
    }
    return flags;
  }

  static List<QualityFlag> extraFlags(ExtraTest t, Map<int, int> a) {
    final flags = <QualityFlag>[];
    final ordered = ([...t.items]..sort((x, y) => x.id.compareTo(y.id))).map((q) => a[q.id]!).toList();
    final run = _longestRun(ordered);
    if (run >= math.max(8, (ordered.length * 0.6).ceil())) {
      flags.add(QualityFlag('straight', 'في «${t.title}» ظهر تتابع $run إجابة متطابقة.'));
    }
    if (ordered.length >= 9) {
      final m = _mean(ordered.map((e) => e.toDouble()));
      if (m > acquiescenceHigh || m < acquiescenceLow) {
        flags.add(QualityFlag('acquiescence', 'في «${t.title}» متوسط الإجابات ${m.toStringAsFixed(2)}، وهو قريب جدًا من أحد الطرفين.'));
      }
    }
    var contradictions = 0;
    for (final d in t.dimensions) {
      final fwd = [for (final q in t.items) if (q.dim == d.id && !q.reverse) a[q.id]!.toDouble()];
      final rev = [for (final q in t.items) if (q.dim == d.id && q.reverse) (6 - a[q.id]!).toDouble()];
      if (fwd.length >= 2 && rev.isNotEmpty && (rev.first - _mean(fwd)).abs() >= 3) contradictions++;
    }
    if (contradictions >= 2) {
      flags.add(QualityFlag('reverse', 'في «${t.title}» تعارضت إجاباتك مع الصياغات العكسية في $contradictions أبعاد.'));
    }
    return flags;
  }

  // ---------- constructs
  static List<Construct> constructs(IntegratedInput i) {
    final r = i.result;
    double? ex(String test, String dim) {
      final t = i.extraTests.where((x) => x.id == test);
      final a = i.extraAnswers[test];
      if (t.isEmpty || a == null) return null;
      final s = ExtraScoring.compute(t.first, a);
      return s.dims.where((d) => d.dim.id == dim).first.pct;
    }

    double? exMean(String test) {
      final t = i.extraTests.where((x) => x.id == test);
      final a = i.extraAnswers[test];
      if (t.isEmpty || a == null) return null;
      return _mean(ExtraScoring.compute(t.first, a).dims.map((d) => d.pct));
    }

    double pole(MbtiPairResult p, bool first) => first ? (p.pctA + (100 - p.pctB)) / 2 : (p.pctB + (100 - p.pctA)) / 2;
    double arfd(String axis) => (r.axis(axis).avg - 1) / 4 * 100;

    List<SourceValue> src(List<SourceValue?> l) => [for (final s in l) if (s != null) s];
    SourceValue? sv(String label, double? v) => v == null ? null : SourceValue(label, v);

    return [
      Construct('social', 'الطاقة الاجتماعية', src([
        SourceValue('MBTI E/I', pole(r.mbti[0], true)),
        sv('Big Five (الانبساط)', ex('bigfive', 'E')),
        sv('HEXACO (الانبساطية)', ex('hexaco', 'X')),
        sv('DISC (التأثير)', ex('disc', 'I')),
        sv('أسلوب العمل (الاجتماعية)', ex('workstyle', 'S')),
      ])),
      Construct('structure', 'التنظيم والانضباط', src([
        SourceValue('MBTI J/P', pole(r.mbti[3], true)),
        sv('Big Five (يقظة الضمير)', ex('bigfive', 'C')),
        sv('HEXACO (الضمير)', ex('hexaco', 'C')),
        sv('أسلوب العمل (الحذر والانضباط)', ex('workstyle', 'P')),
        sv('التسويف (معكوس)', ex('procrast', 'T') == null ? null : 100 - ex('procrast', 'T')!),
      ])),
      Construct('openness', 'الانفتاح على الجديد', src([
        SourceValue('MBTI S/N (الحدس)', pole(r.mbti[1], false)),
        sv('Big Five (الانفتاح)', ex('bigfive', 'O')),
        sv('HEXACO (الانفتاح)', ex('hexaco', 'O')),
        sv('أسلوب العمل (الفضول)', ex('workstyle', 'Q')),
        sv('الميول المهنية (الفني)', ex('riasec', 'A')),
      ])),
      Construct('logic', 'الميل للمنطق مقابل القيم', src([SourceValue('MBTI T/F', pole(r.mbti[2], true))])),
      Construct('analysis', 'التحليل قبل القرار', src([
        SourceValue('A-R-F-D (A)', arfd('A')),
        sv('التفكير العميق', ex('nfc', 'N')),
        sv('أسلوب التفكير (تحليلي)', ex('cognitive', 'A')),
        sv('أسلوب القرار (عقلاني)', ex('decision', 'R')),
      ])),
      Construct('risk', 'تقبّل المخاطرة', src([
        SourceValue('A-R-F-D (R)', arfd('R')),
        sv('اختبار المخاطرة', exMean('risk')),
      ])),
      Construct('follow', 'الاستمرارية والتنفيذ', src([
        SourceValue('A-R-F-D (F)', arfd('F')),
        sv('Big Five (يقظة الضمير)', ex('bigfive', 'C')),
        sv('العزيمة (Grit)', exMean('grit')),
        sv('التسويف (معكوس)', ex('procrast', 'T') == null ? null : 100 - ex('procrast', 'T')!),
      ])),
      Construct('drive', 'الدافع والاستقلالية', src([
        SourceValue('A-R-F-D (D)', arfd('D')),
        sv('أسلوب العمل (الطموح)', ex('workstyle', 'M')),
        sv('القيم (الإنجاز والمكانة)', ex('values', 'A')),
        sv('عقلية النمو', ex('growth', 'G')),
      ])),
      Construct('empathy', 'التعاطف والتعاون', src([
        sv('Big Five (الوِد)', ex('bigfive', 'A')),
        sv('HEXACO (الموافقة)', ex('hexaco', 'A')),
        sv('الذكاء العاطفي (التعاطف)', ex('eq', 'E')),
        sv('أسلوب العمل (الدفء)', ex('workstyle', 'W')),
        sv('الأسس الأخلاقية (الرعاية)', ex('moral', 'C')),
        (ex('empathy', 'P') == null || ex('empathy', 'E') == null) ? null : SourceValue('اختبار التعاطف', (ex('empathy', 'P')! + ex('empathy', 'E')!) / 2),
      ])),
      Construct('reactivity', 'الحساسية للضغط', src([
        sv('Big Five (الحساسية الانفعالية)', ex('bigfive', 'N')),
        sv('HEXACO (الانفعالية)', ex('hexaco', 'E')),
        sv('المرونة النفسية (معكوسة)', ex('resilience', 'R') == null ? null : 100 - ex('resilience', 'R')!),
        sv('رأس المال النفسي (معكوس)', exMean('psycap') == null ? null : 100 - exMean('psycap')!),
        sv('الذكاء العاطفي: تنظيم الانفعال (معكوس)', ex('eq', 'R') == null ? null : 100 - ex('eq', 'R')!),
        sv('الحساسية العالية للمؤثرات', ex('hsp', 'H')),
        sv('اختبار التعاطف (الضيق الشخصي)', ex('empathy', 'D')),
        sv('تقدير الذات (معكوس)', ex('selfesteem', 'S') == null ? null : 100 - ex('selfesteem', 'S')!),
        sv('الرضا عن الحياة (معكوس)', ex('lifesat', 'L') == null ? null : 100 - ex('lifesat', 'L')!),
        sv('اختبار التفاؤل (معكوس)', ex('optimism', 'O') == null ? null : 100 - ex('optimism', 'O')!),
      ])),
    ];
  }

  // ---------- confidence
  static (int, List<String>) _points({
    required int consistency, // -1, 0, 1
    required int separation,
    required Convergence convergence,
    required bool flagged,
    required List<String> reasons,
  }) {
    var p = consistency + separation;
    switch (convergence) {
      case Convergence.good:
        p += 1;
        break;
      case Convergence.divergent:
        p -= 1;
        break;
      default:
        break;
    }
    if (flagged) p -= 1;
    return (p, reasons);
  }

  static ConfidenceLevel _level(int points, Convergence convergence) {
    if (points >= 2 && convergence == Convergence.good) return ConfidenceLevel.highRelative;
    if (points >= 1) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  static Confidence _confidence(String subject, {required int consistency, required int separation, required Convergence conv, required bool flagged, required List<String> reasons}) {
    final (p, rs) = _points(consistency: consistency, separation: separation, convergence: conv, flagged: flagged, reasons: reasons);
    final level = _level(p, conv);
    final extra = <String>[...rs];
    if (conv == Convergence.none) extra.add('لا يوجد مقياس آخر أنجزته يؤكد هذه النتيجة، لذا لا تتجاوز الثقة «متوسطة»');
    if (flagged) extra.add('أُنقصت درجة بسبب ملاحظات جودة الإجابات');
    return Confidence(subject, level, p, extra);
  }

  static Convergence _convFor(List<Construct> cs, List<String> ids, String mainLabelPrefix) {
    // best (strongest) agreement among constructs that include sources beyond the main test
    var best = Convergence.none;
    for (final c in cs.where((c) => ids.contains(c.id))) {
      final others = c.sources.where((s) => !s.label.startsWith('MBTI') && !s.label.startsWith('A-R-F-D')).toList();
      if (others.isEmpty) continue;
      final own = c.sources.where((s) => s.label.startsWith(mainLabelPrefix)).toList();
      if (own.isEmpty) continue;
      final spread = others.map((s) => (s.pct - own.first.pct).abs()).reduce(math.max);
      final conv = spread <= closeConvergence ? Convergence.good : (spread <= partialConvergence ? Convergence.partial : Convergence.divergent);
      if (best == Convergence.none || conv.index > best.index) {
        // order: none(0) good(1) partial(2) divergent(3): prefer worst to stay honest
        best = conv;
      }
    }
    return best;
  }

  static List<Confidence> mainConfidences(IntegratedInput i, List<Construct> cs, List<QualityFlag> flags) {
    final r = i.result;
    final out = <Confidence>[];
    const mbtiConstructs = [['social'], ['openness'], ['logic'], ['structure']];
    for (var k = 0; k < r.mbti.length; k++) {
      final p = r.mbti[k];
      final sdA = _sd(_raw(i, system: AssessmentSystem.mbti, dim: p.poleA));
      final sdB = _sd(_raw(i, system: AssessmentSystem.mbti, dim: p.poleB));
      final avgSd = (sdA + sdB) / 2;
      final g = (p.pctA - (100 - p.pctB)).abs();
      final cons = (avgSd <= 0.8 && g <= 25) ? 1 : ((avgSd <= 1.3 && g <= 50) ? 0 : -1);
      final sep = p.diff >= 30 ? 1 : (p.diff >= 10 ? 0 : -1);
      final conv = _convFor(cs, mbtiConstructs[k], 'MBTI');
      out.add(_confidence(
        '${p.poleA}/${p.poleB} في MBTI',
        consistency: cons,
        separation: sep,
        conv: conv,
        flagged: flags.any((f) => f.id != 'reverse'),
        reasons: [
          'اتساق أسئلة القطبين: ${cons == 1 ? "جيد" : (cons == 0 ? "مقبول" : "ضعيف")} (تشتت ${avgSd.toStringAsFixed(2)}، وتعارض بين القطبين $g نقطة)',
          'الفارق بين القطبين ${p.diff.round()} نقطة: ${sep == 1 ? "واضح" : (sep == 0 ? "متوسط" : "ضعيف")}',
          'عدد الأسئلة 3 لكل قطب (قليل)',
          if (conv != Convergence.none) 'مقارنة مع مقاييس أخرى: ${convergenceName(conv)}',
        ],
      ));
    }
    // Enneagram
    final top = r.enneagramTop;
    final topSd = _sd(_raw(i, system: AssessmentSystem.enneagram, dim: '${top.type}'));
    final gap = top.score - r.enneagramRanking[1].score;
    out.add(_confidence(
      r.enneagramConclusive ? 'Enneagram: النمط ${top.type}' : 'Enneagram: الأنماط المتقاربة',
      consistency: topSd <= 0.8 ? 1 : (topSd <= 1.3 ? 0 : -1),
      separation: gap >= 4 ? 1 : (gap >= 2 ? 0 : -1),
      conv: Convergence.none,
      flagged: flags.any((f) => f.id != 'reverse'),
      reasons: [
        'اتساق أسئلة النمط الأعلى: ${topSd <= 0.8 ? "جيد" : (topSd <= 1.3 ? "مقبول" : "ضعيف")} (تشتت ${topSd.toStringAsFixed(2)})',
        'الفارق عن النمط الثاني $gap نقاط: ${gap >= 4 ? "واضح" : (gap >= 2 ? "متوسط" : "ضعيف")}',
        '4 أسئلة لكل نمط فقط',
      ],
    ));
    // A-R-F-D axes
    const arfdConstructs = {'A': 'analysis', 'R': 'risk', 'F': 'follow', 'D': 'drive'};
    for (final a in r.arfd) {
      final adj = _adjusted(i, AssessmentSystem.arfd, a.axis);
      final sd = _sd(adj);
      final conv = _convFor(cs, [arfdConstructs[a.axis]!], 'A-R-F-D');
      out.add(_confidence(
        'A-R-F-D: محور ${a.axis}',
        consistency: sd <= 0.6 ? 1 : (sd <= 1.2 ? 0 : -1),
        separation: 0,
        conv: conv,
        flagged: flags.isNotEmpty,
        reasons: [
          'اتساق أسئلة المحور (مع احتساب السؤال العكسي): ${sd <= 0.6 ? "جيد" : (sd <= 1.2 ? "مقبول" : "ضعيف")} (تشتت ${sd.toStringAsFixed(2)})',
          '3 أسئلة فقط للمحور، ومنها سؤال عكسي',
          'نظام أصلي غير معتمد',
          if (conv != Convergence.none) 'مقارنة مع مقاييس أخرى: ${convergenceName(conv)}',
        ],
      ));
    }
    return out;
  }

  static List<Confidence> extraConfidences(IntegratedInput i, List<Construct> cs) {
    final out = <Confidence>[];
    for (final t in i.extraTests) {
      final a = i.extraAnswers[t.id];
      if (a == null) continue;
      final sds = <double>[];
      for (final d in t.dimensions) {
        final adj = [for (final q in t.items) if (q.dim == d.id) (q.reverse ? 6 - a[q.id]! : a[q.id]!).toDouble()];
        if (adj.length >= 3) sds.add(_sd(adj));
      }
      final avg = sds.isEmpty ? 0.0 : _mean(sds);
      final flags = extraFlags(t, a);
      // convergence: constructs that list this test as a source vs the other sources
      var conv = Convergence.none;
      for (final c in cs) {
        final mine = c.sources.where((s) => s.label.contains(_shortName[t.id] ?? '\u0000')).toList();
        final others = c.sources.where((s) => !s.label.contains(_shortName[t.id] ?? '\u0000')).toList();
        if (mine.isEmpty || others.isEmpty) continue;
        final spread = others.map((s) => (s.pct - mine.first.pct).abs()).reduce(math.max);
        final cv = spread <= closeConvergence ? Convergence.good : (spread <= partialConvergence ? Convergence.partial : Convergence.divergent);
        if (conv == Convergence.none || cv.index > conv.index) conv = cv;
      }
      final cons = avg <= 0.8 ? 1 : (avg <= 1.3 ? 0 : -1);
      final perDim = t.items.length / t.dimensions.length;
      out.add(_confidence(
        t.title,
        consistency: cons,
        separation: 0,
        conv: conv,
        flagged: flags.isNotEmpty,
        reasons: [
          'اتساق إجاباتك داخل الأبعاد: ${cons == 1 ? "جيد" : (cons == 0 ? "مقبول" : "ضعيف")} (متوسط التشتت ${avg.toStringAsFixed(2)})',
          'عدد الأسئلة ${perDim.toStringAsFixed(perDim == perDim.roundToDouble() ? 0 : 1)} لكل بُعد',
          'أسئلة أصلية غير محققة علميًا',
          if (conv != Convergence.none) 'مقارنة مع مقاييس أخرى: ${convergenceName(conv)}',
          ...flags.map((f) => f.text),
        ],
      ));
    }
    return out;
  }

  static const Map<String, String> _shortName = {
    'bigfive': 'Big Five',
    'hexaco': 'HEXACO',
    'disc': 'DISC',
    'workstyle': 'أسلوب العمل',
    'nfc': 'التفكير العميق',
    'cognitive': 'أسلوب التفكير',
    'decision': 'أسلوب القرار',
    'risk': 'اختبار المخاطرة',
    'values': 'القيم',
    'eq': 'الذكاء العاطفي',
    'moral': 'الأسس الأخلاقية',
    'resilience': 'المرونة النفسية',
    'psycap': 'رأس المال النفسي',
    'riasec': 'الميول المهنية',
    'grit': 'العزيمة',
    'procrast': 'التسويف',
    'growth': 'عقلية النمو',
    'empathy': 'اختبار التعاطف',
    'hsp': 'الحساسية العالية',
    'selfesteem': 'تقدير الذات',
    'lifesat': 'الرضا عن الحياة',
    'optimism': 'اختبار التفاؤل',
  };

  // ---------- strengths / stumbling rules
  static List<Statement> _single(Construct c, bool strengths) {
    final lv = c.level;
    String? s, t;
    switch (c.id) {
      case 'structure':
        if (lv == Level.high) { s = 'انضباط وتنظيم يسهّلان الإنجاز المنتظم'; t = 'قد تقل مرونتك عند تغيّر الخطط فجأة'; }
        if (lv == Level.low) { s = 'مرونة وقدرة على التكيف مع المتغيرات'; t = 'قد تتأخر المهام وتتبعثر الأولويات دون إطار'; }
        break;
      case 'follow':
        if (lv == Level.high) { s = 'استمرارية وإكمال ما تبدأ به'; }
        if (lv == Level.low) { t = 'بدء مشاريع كثيرة دون إكمالها'; }
        break;
      case 'analysis':
        if (lv == Level.high) { s = 'قرارات مدروسة بعد مقارنة الخيارات'; t = 'خطر الإفراط في التحليل وتأخير الحسم'; }
        if (lv == Level.low) { s = 'سرعة في الحسم'; t = 'قرارات قد تُتخذ بمعلومات ناقصة'; }
        break;
      case 'risk':
        if (lv == Level.high) { s = 'جرأة في تجربة الفرص'; t = 'قد تتحمل مخاطرة أكبر مما ينبغي'; }
        if (lv == Level.low) { s = 'حذر يحميك من الخسائر'; t = 'قد تفوتك فرص لأنك تنتظر الضمان'; }
        break;
      case 'drive':
        if (lv == Level.high) { s = 'دافع قوي للاستقلالية والإنجاز'; t = 'قد تُرهق نفسك أو تصطدم بالتوجيه'; }
        if (lv == Level.low) { t = 'زخم أقل نحو الأهداف الطويلة'; }
        break;
      case 'social':
        if (lv == Level.high) { s = 'سهولة في بناء العلاقات والتأثير'; t = 'قد تنشغل بالتفاعل على حساب التركيز الهادئ'; }
        if (lv == Level.low) { s = 'تركيز عميق وهدوء'; t = 'قد تتأخر في طلب الدعم أو في بناء شبكة علاقات'; }
        break;
      case 'empathy':
        if (lv == Level.high) { s = 'تعاون وتعاطف يقويان الفريق'; t = 'قد تتجنب المواجهة أو تتنازل أكثر من اللازم'; }
        if (lv == Level.low) { s = 'صراحة وقدرة على قول ما لا يُرضي'; t = 'قد تُفسَّر صراحتك على أنها حدّة'; }
        break;
      case 'openness':
        if (lv == Level.high) { s = 'خيال وفضول وتقبّل للأفكار الجديدة'; t = 'قد تفضّل الجديد على إتقان القائم'; }
        if (lv == Level.low) { s = 'واقعية واعتماد على ما جُرّب'; t = 'قد تقاوم التغيير أو الأفكار غير المألوفة'; }
        break;
      case 'logic':
        if (lv == Level.high) { s = 'موضوعية ومعايير ثابتة'; t = 'قد لا تُوازن بين المنطق وأثر القرار على الناس'; }
        if (lv == Level.low) { s = 'مراعاة القيم والناس في القرار'; t = 'قد تؤجل قرارات صعبة تزعج الآخرين'; }
        break;
      case 'reactivity':
        if (lv == Level.high) { t = 'تأثر أكبر بالضغط والقلق'; }
        if (lv == Level.low) { s = 'هدوء نسبي تحت الضغط'; }
        break;
    }
    final ev = '${c.name}: ${levelName(lv)} من ${c.sources.length == 1 ? "مصدر واحد" : "${c.sources.length} مصادر"}';
    final multi = c.sources.length >= 2;
    final txt = strengths ? s : t;
    return txt == null ? [] : [Statement(txt, ev, multiSource: multi)];
  }

  static List<(List<(String, Level)>, String?, String?)> get _combos => const [
        ([('analysis', Level.high), ('follow', Level.low)], null, 'تحليل أكثر من تنفيذ: الخطة جاهزة والإطلاق متأخر'),
        ([('structure', Level.high), ('risk', Level.low)], 'تنفيذ موثوق ومحسوب', 'ميل مزدوج للانضباط والحذر قد يُبقيك في المنطقة الآمنة'),
        ([('risk', Level.high), ('structure', Level.low)], null, 'جرأة دون إطار تنظيمي قد تكرّر الأخطاء نفسها'),
        ([('drive', Level.high), ('empathy', Level.low)], null, 'إصرار على الهدف قد يُشعر المحيطين بالضغط'),
        ([('drive', Level.high), ('follow', Level.high)], 'دافع واستمرارية معًا: تقدّم ثابت نحو الأهداف', null),
        ([('analysis', Level.high), ('reactivity', Level.high)], null, 'احتمال اجترار التفكير تحت الضغط'),
        ([('social', Level.high), ('structure', Level.low)], null, 'التزامات اجتماعية كثيرة مع تنظيم أقل قد يشتت وقتك'),
        ([('openness', Level.high), ('follow', Level.low)], null, 'أفكار وتجارب كثيرة وإكمال أقل'),
        ([('empathy', Level.high), ('logic', Level.high)], 'قدرة على الجمع بين الحزم المنطقي والتعاون', null),
        ([('analysis', Level.high), ('risk', Level.high)], 'تحليل مع جرأة: مخاطرة محسوبة', null),
      ];

  static (List<Statement>, List<Statement>) strengthsAndStumbles(List<Construct> cs) {
    final byId = {for (final c in cs) c.id: c};
    final strengths = <Statement>[];
    final stumbles = <Statement>[];
    for (final c in cs.where((c) => c.hasData)) {
      strengths.addAll(_single(c, true));
      stumbles.addAll(_single(c, false));
    }
    for (final combo in _combos) {
      final ok = combo.$1.every((c) {
        final k = byId[c.$1];
        return k != null && k.hasData && k.level == c.$2;
      });
      if (!ok) continue;
      final names = combo.$1.map((c) => '${byId[c.$1]!.name}: ${levelName(c.$2)}').join(' + ');
      final multi = combo.$1.every((c) => byId[c.$1]!.sources.length >= 2);
      if (combo.$2 != null) strengths.add(Statement(combo.$2!, 'تركيبة: $names', multiSource: multi));
      if (combo.$3 != null) stumbles.add(Statement(combo.$3!, 'تركيبة: $names', multiSource: multi));
    }
    int order(Statement s) => (s.evidence.startsWith('تركيبة') ? 0 : 1) + (s.multiSource ? 0 : 2);
    strengths.sort((a, b) => order(a).compareTo(order(b)));
    stumbles.sort((a, b) => order(a).compareTo(order(b)));
    return (strengths.take(8).toList(), stumbles.take(8).toList());
  }

  // ---------- decision / stress
  static List<String> decisionLines(IntegratedInput i, List<Construct> cs) {
    final byId = {for (final c in cs) c.id: c};
    final lines = <String>[];
    final a = byId['analysis']!;
    lines.add(a.level == Level.high
        ? 'تجمع المعلومات وتقارن الخيارات قبل الحسم (التحليل ${levelName(a.level)}).'
        : a.level == Level.low
            ? 'تميل إلى الحسم بتحليل أقل وسرعة أعلى (التحليل ${levelName(a.level)}).'
            : 'توازن بين التحليل والسرعة (التحليل متوسط).');
    final lg = byId['logic']!;
    lines.add(lg.level == Level.high
        ? 'تقدّم المنطق والمعايير الثابتة عند المفاضلة.'
        : lg.level == Level.low
            ? 'تراعي القيم وأثر القرار على الناس بقوة.'
            : 'تجمع بين المنطق والقيم دون ميل واضح لأحدهما.');
    final rk = byId['risk']!;
    lines.add(rk.level == Level.high
        ? 'تقبل المخاطرة المحسوبة بسهولة.'
        : rk.level == Level.low
            ? 'تفضّل الحذر وتتجنب الفرص غير المضمونة.'
            : 'تقبل المخاطرة أحيانًا بحسب الموقف.');
    final exec = (byId['structure']!.pct + byId['follow']!.pct) / 2;
    lines.add(levelOf(exec) == Level.high
        ? 'تنتقل من القرار إلى خطة وتنفيذ بانتظام.'
        : levelOf(exec) == Level.low
            ? 'قد يبقى القرار بلا خطة وتنفيذ منتظمين.'
            : 'تنفيذك للقرارات متوسط الانتظام.');
    for (final id in ['decision', 'cognitive']) {
      final t = i.extraTests.where((x) => x.id == id);
      final ans = i.extraAnswers[id];
      if (t.isEmpty || ans == null) continue;
      final s = ExtraScoring.compute(t.first, ans);
      if (s.topDims.isNotEmpty) {
        lines.add('في «${t.first.title}» وصفتَ نفسك: ${s.topDims.map((d) => d.dim.name).join("، ")}.');
      }
    }
    return lines;
  }

  static (List<String>, bool) stressLines(IntegratedInput i, List<Construct> cs) {
    final byId = {for (final c in cs) c.id: c};
    final re = byId['reactivity']!;
    if (!re.hasData) {
      return (
        const [
          'لم يُقَس هذا الجانب: الاختبار الرئيسي لا يحتوي أسئلة عن الضغط والتعافي، ولا نخمّن منه.',
          'أكمل أحد هذه الاختبارات الإضافية لتفعيل القسم: Big Five، HEXACO، المرونة النفسية، رأس المال النفسي، الذكاء العاطفي.',
        ],
        false
      );
    }
    final lines = <String>[];
    lines.add('حساسيتك للضغط ${levelName(re.level)} (${re.pct.round()}٪) بحسب: ${re.sources.map((s) => s.label).join("، ")}.');
    double? ex(String test, String dim) {
      final t = i.extraTests.where((x) => x.id == test);
      final a = i.extraAnswers[test];
      if (t.isEmpty || a == null) return null;
      return ExtraScoring.compute(t.first, a).dims.where((d) => d.dim.id == dim).first.pct;
    }

    final res = ex('resilience', 'R');
    final loc = ex('locus', 'L');
    final reg = ex('eq', 'R');
    final reappraisal = ex('emoreg', 'R');
    final suppression = ex('emoreg', 'S');
    final resources = <String>[];
    if (reappraisal != null) resources.add('إعادة التقييم ${levelName(levelOf(reappraisal))}');
    if (suppression != null) resources.add('كبت التعبير ${levelName(levelOf(suppression))}');
    if (res != null) resources.add('المرونة النفسية ${levelName(levelOf(res))}');
    if (reg != null) resources.add('تنظيم الانفعال ${levelName(levelOf(reg))}');
    if (loc != null) resources.add('مركز التحكم الداخلي ${levelName(levelOf(loc))}');
    if (resources.isNotEmpty) lines.add('موارد التكيف التي قستها: ${resources.join("، ")}.');
    final resLevel = res == null ? null : levelOf(res);
    if (re.level == Level.high && resLevel == Level.low) {
      lines.add('احتمال التعثر تحت الضغط أعلى: يفيدك روتين دعم ثابت (نوم، حديث مع شخص تثق به، تقسيم المهام).');
    } else if (re.level == Level.high && resLevel == Level.high) {
      lines.add('تتأثر بالضغط لكنك تتعافى سريعًا بحسب وصفك لنفسك.');
    } else if (re.level == Level.low) {
      lines.add('تبدو أكثر ثباتًا تحت الضغط بحسب وصفك لنفسك.');
    }
    if (re.level == Level.high && byId['analysis']!.level == Level.high) {
      lines.add('مع ارتفاع التحليل قد يتحول الضغط إلى اجترار؛ حدّد وقتًا محدودًا للتفكير ثم اتخذ خطوة.');
    }
    lines.add('هذه أوصاف ذاتية لا قياسات سلوكية للضغط الفعلي.');
    return (lines, true);
  }

  // ---------- career interests (RIASEC) and well-being (only when measured)
  static List<String> careerLines(IntegratedInput i) {
    final t = i.extraTests.where((x) => x.id == 'riasec');
    final a = i.extraAnswers['riasec'];
    if (t.isEmpty || a == null) return const [];
    final sc = ExtraScoring.compute(t.first, a);
    final order = [...sc.dims]..sort((x, y) {
        final c = y.pct.compareTo(x.pct);
        return c != 0 ? c : sc.dims.indexOf(x).compareTo(sc.dims.indexOf(y));
      });
    final top = order.take(3).toList();
    return [
      'رمزك المهني (على طريقة هولاند): ${top.map((d) => d.dim.id).join()} — ${top.map((d) => "${d.dim.name} ${d.pct.round()}٪").join("، ")}.',
      'هذا ميل لما تحب لا حكم على ما تُتقن، وليس إرشادًا مهنيًا؛ استعمله لتوليد أفكار تجرّبها.',
    ];
  }

  static List<String> wellbeingLines(IntegratedInput i) {
    double? pct(String test, String dim) {
      final t = i.extraTests.where((x) => x.id == test);
      final a = i.extraAnswers[test];
      if (t.isEmpty || a == null) return null;
      return ExtraScoring.compute(t.first, a).dims.where((d) => d.dim.id == dim).first.pct;
    }

    final lines = <String>[];
    void add(String label, double? v) {
      if (v != null) lines.add('$label: ${levelName(levelOf(v))} (${v.round()}٪)');
    }

    add('الرضا عن الحياة', pct('lifesat', 'L'));
    add('تقدير الذات', pct('selfesteem', 'S'));
    add('التفاؤل', pct('optimism', 'O'));
    add('عقلية النمو', pct('growth', 'G'));
    if (lines.isNotEmpty) lines.add('أوصاف ذاتية لحظية قد تتغير مع الظروف؛ وليست تشخيصًا. إن شعرت بضيق مستمر فاستشر مختصًا.');
    return lines;
  }

  // ---------- self vs others
  static SelfOthers selfOthers(IntegratedInput i) {
    final t = i.extraTests.where((x) => x.id == 'bigfive');
    final a = i.extraAnswers['bigfive'];
    final complete = i.observers.where((o) => ObserverRating.isComplete(o.answers)).toList();
    if (t.isEmpty || a == null) return SelfOthers(needsBigFive: true, observerCount: complete.length, rows: const []);
    final self = ExtraScoring.compute(t.first, a);
    final rows = <SelfOthersRow>[];
    if (complete.isNotEmpty) {
      for (final dim in ['O', 'C', 'E', 'A', 'N']) {
        final sp = self.dims.where((d) => d.dim.id == dim).first.pct;
        final vals = complete.map((o) => o.dimPct(dim)).toList();
        rows.add(SelfOthersRow(dimName: observerDimNames[dim]!, selfPct: sp, othersPct: _mean(vals), observers: complete.length, observerSpread: _sd(vals)));
      }
    }
    return SelfOthers(needsBigFive: false, observerCount: complete.length, rows: rows);
  }

  // ---------- build
  static IntegratedReport build(IntegratedInput i) {
    final cs = constructs(i);
    final flags = mainFlags(i);
    final (strengths, stumbles) = strengthsAndStumbles(cs);
    final (stress, stressMeasured) = stressLines(i, cs);
    final r = i.result;
    final top = r.enneagramTop;
    final headline = 'MBTI ${r.mbtiType}${r.mbtiAnyClose ? " (أبعاد متقاربة)" : ""} • '
        '${r.enneagramConclusive ? "Enneagram النمط ${top.type}" : "Enneagram: أنماط متقاربة"} • A-R-F-D ${r.arfdCode}';

    final withData = cs.where((c) => c.hasData).toList()..sort((a, b) => b.pct.compareTo(a.pct));
    final themes = <String>[
      'أبرز ما يميّزك: ${withData.take(3).map((c) => "${c.name} (${c.pct.round()}٪)").join("، ")}.',
      'أقل ما يظهر لديك: ${withData.reversed.take(2).map((c) => "${c.name} (${c.pct.round()}٪)").join("، ")}.',
    ];
    final agreeing = cs.where((c) => c.convergence == Convergence.good).map((c) => c.name).toList();
    final diverging = cs.where((c) => c.convergence == Convergence.divergent).map((c) => c.name).toList();
    if (agreeing.isNotEmpty) themes.add('مقاييس متفقة على: ${agreeing.join("، ")} (نتيجة أقوى).');
    if (diverging.isNotEmpty) themes.add('مقاييس متباينة في: ${diverging.join("، ")}؛ قد تقيس جوانب مختلفة أو تتأثر بالحالة المزاجية، فتعامل معها بحذر.');
    if (cs.every((c) => c.sources.length <= 1 || c.convergence == Convergence.none)) {
      themes.add('لم تُقارَن النتائج بمقاييس أخرى بعد: أكمل اختبارات إضافية (مثل Big Five وHEXACO) لتتحقق النتائج من بعضها.');
    }

    final extraAnswers = i.extraAnswers;
    return IntegratedReport(
      headline: headline,
      constructs: cs,
      themes: themes,
      strengths: strengths,
      stumbles: stumbles,
      contradictions: ReportBuilder.build(r).contradictions,
      decisionLines: decisionLines(i, cs),
      stressLines: stress,
      stressMeasured: stressMeasured,
      selfOthers: selfOthers(i),
      flags: [
        ...flags,
        for (final t in i.extraTests)
          if (extraAnswers[t.id] != null) ...extraFlags(t, extraAnswers[t.id]!),
      ],
      confidences: mainConfidences(i, cs, flags),
      extraConfidences: extraConfidences(i, cs),
      careerLines: careerLines(i),
      wellbeingLines: wellbeingLines(i),
    );
  }
}

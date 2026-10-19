import 'package:discover_personality/data/integrated/integrated_engine.dart';
import 'package:discover_personality/data/integrated/observer.dart';
import 'package:discover_personality/data/models/extra_test.dart';
import 'package:discover_personality/data/models/question.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final qs = loadBank().questions;
  final tests = loadExtraTests();

  IntegratedInput inp(Map<int, int> main, {Map<String, Map<int, int>> extras = const {}, List<ObserverRating> obs = const []}) => IntegratedInput(
        questions: qs,
        answers: main,
        result: ScoringEngine.compute(qs, main),
        extraTests: tests,
        extraAnswers: extras,
        observers: obs,
      );

  // A coherent, varied profile: prefers E, N, T, J; strong type 5; high A-R-F-D axes with consistent reverse items.
  Map<int, int> coherent() => buildAnswers(qs, (q) {
        switch (q.system) {
          case AssessmentSystem.mbti:
            final pref = {'E', 'N', 'T', 'J'}.contains(q.dimension);
            final idx = q.id % 3;
            return pref ? (idx == 0 ? 4 : 5) : (idx == 0 ? 2 : 1);
          case AssessmentSystem.enneagram:
            if (q.dimension == '5') return [5, 5, 4, 5][q.id % 4];
            return (q.id * 7) % 3 + 1;
          case AssessmentSystem.arfd:
            return q.reverse ? 2 : 4;
        }
      });

  ExtraTest t(String id) => tests.firstWhere((x) => x.id == id);

  Map<int, int> extra(String id, int Function(ExtraItem i) f) => {for (final i in t(id).items) i.id: f(i)};

  Map<int, int> bigfiveE(int eValue) => extra('bigfive', (i) => i.dim == 'E' ? (i.reverse ? 6 - eValue : eValue) : 3);

  Confidence conf(IntegratedReport r, String startsWith) => r.confidences.firstWhere((c) => c.subject.startsWith(startsWith));

  ObserverRating observer(int Function(ObserverItem i) f) =>
      ObserverRating(id: 'o', createdAt: DateTime.utc(2026), relation: 'صديق', answers: {for (final i in observerItems) i.id: f(i)});

  test('a clean coherent profile has no quality flags and 9 main confidence entries', () {
    final r = IntegratedEngine.build(inp(coherent()));
    expect(r.flags, isEmpty);
    expect(r.confidences.length, 9); // 4 MBTI pairs + Enneagram + 4 A-R-F-D axes
  });

  test('without any independent measure confidence never exceeds "medium" (and says why)', () {
    final r = IntegratedEngine.build(inp(coherent()));
    for (final c in r.confidences) {
      expect(c.level, isNot(ConfidenceLevel.highRelative), reason: c.subject);
    }
    final ei = conf(r, 'E/I');
    expect(ei.level, ConfidenceLevel.medium);
    expect(ei.reasons.join(' '), contains('لا تتجاوز الثقة'));
  });

  test('straight-lined answers raise flags and lower confidence', () {
    final r = IntegratedEngine.build(inp(allSame(qs, 3)));
    expect(r.flags.map((f) => f.id), containsAll(['straight', 'flat']));
    for (final p in r.confidences.where((c) => c.subject.contains('MBTI'))) {
      expect(p.level, ConfidenceLevel.low, reason: p.subject);
    }
  });

  test('yes-saying (almost all 5s) is flagged as acquiescence', () {
    final r = IntegratedEngine.build(inp(allSame(qs, 5)));
    expect(r.flags.map((f) => f.id), contains('acquiescence'));
  });

  test('reverse-item contradictions in A-R-F-D are detected and reduce A-R-F-D confidence', () {
    final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd ? 5 : (q.id * 7) % 5 + 1);
    final r = IntegratedEngine.build(inp(a));
    expect(r.flags.map((f) => f.id), contains('reverse'));
    final axis = conf(r, 'A-R-F-D: محور A');
    expect(axis.level, ConfidenceLevel.low);
  });

  test('a second measure that agrees allows "relatively high" confidence', () {
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(5)}));
    final social = r.constructs.firstWhere((c) => c.id == 'social');
    expect(social.convergence, Convergence.good);
    expect(conf(r, 'E/I').level, ConfidenceLevel.highRelative);
    expect(r.themes.join(' '), contains('مقاييس متفقة'));
  });

  test('a second measure that disagrees is reported and lowers confidence', () {
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(1)}));
    final social = r.constructs.firstWhere((c) => c.id == 'social');
    expect(social.convergence, Convergence.divergent);
    expect(r.themes.join(' '), contains('متباينة'));
    expect(conf(r, 'E/I').level, ConfidenceLevel.medium);
    expect(conf(r, 'E/I').reasons.join(' '), contains('متباينة'));
  });

  test('convergence thresholds are 20 / 35 points', () {
    Construct c(double a, double b) => Construct('x', 'x', [SourceValue('a', a), SourceValue('b', b)]);
    expect(c(50, 70).convergence, Convergence.good);
    expect(c(50, 71).convergence, Convergence.partial);
    expect(c(50, 85).convergence, Convergence.partial);
    expect(c(50, 86).convergence, Convergence.divergent);
    expect(Construct('x', 'x', [const SourceValue('a', 50)]).convergence, Convergence.none);
  });

  test('stress is reported as NOT measured when no stress-related test exists', () {
    final r = IntegratedEngine.build(inp(coherent()));
    expect(r.stressMeasured, isFalse);
    expect(r.stressLines.join(' '), contains('لم يُقَس'));
  });

  test('stress section activates from Big Five / resilience answers and shows its sources', () {
    final r = IntegratedEngine.build(inp(coherent(), extras: {
      'bigfive': extra('bigfive', (i) => i.dim == 'N' ? (i.reverse ? 1 : 5) : 3),
      'resilience': extra('resilience', (i) => i.reverse ? 5 : 1),
    }));
    expect(r.stressMeasured, isTrue);
    final txt = r.stressLines.join(' ');
    expect(txt, contains('حساسيتك للضغط مرتفع'));
    expect(txt, contains('يفيدك روتين دعم'));
  });

  test('self vs others: needs Big Five first, then observers; nothing is invented', () {
    var r = IntegratedEngine.build(inp(coherent()));
    expect(r.selfOthers.needsBigFive, isTrue);
    expect(r.selfOthers.measured, isFalse);
    r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(5)}));
    expect(r.selfOthers.needsBigFive, isFalse);
    expect(r.selfOthers.observerCount, 0);
    expect(r.selfOthers.measured, isFalse);
    expect(r.toText(), contains('لم يُقَس بعد'));
  });

  test('self vs others: gap is computed from real observer ratings, marked preliminary under 3 observers', () {
    final obs = observer((i) => i.dim == 'E' ? (i.reverse ? 1 : 5) : (i.dim == 'N' ? (i.reverse ? 1 : 5) : 3));
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(5)}, obs: [obs]));
    final so = r.selfOthers;
    expect(so.measured, isTrue);
    expect(so.preliminary, isTrue);
    final e = so.rows.firstWhere((x) => x.dimName == 'الانبساط');
    expect(e.selfPct, 100);
    expect(e.othersPct, 100);
    expect(e.status, 'متقاربة');
    final n = so.rows.firstWhere((x) => x.dimName == 'الحساسية الانفعالية');
    expect(n.selfPct, 50);
    expect(n.othersPct, 100);
    expect(n.status, contains('أعلى'));
  });

  test('incomplete observer ratings are ignored', () {
    final partial = ObserverRating(id: 'p', createdAt: DateTime.utc(2026), relation: 'صديق', answers: {1: 5, 2: 5});
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(5)}, obs: [partial]));
    expect(r.selfOthers.observerCount, 0);
  });

  test('observer rating json round trip and per-dimension percentage', () {
    final o = observer((i) => i.reverse ? 1 : 5);
    final back = ObserverRating.fromJson(o.toJson());
    expect(back.answers, o.answers);
    for (final d in ['O', 'C', 'E', 'A', 'N']) {
      expect(back.dimPct(d), 100);
    }
  });

  test('combination rule: high analysis + low follow-through is named as a stumbling source', () {
    final a = buildAnswers(qs, (q) {
      if (q.system != AssessmentSystem.arfd) return (q.id * 7) % 5 + 1;
      if (q.dimension == 'A') return q.reverse ? 1 : 5; // adjusted 5
      if (q.dimension == 'F') return q.reverse ? 5 : 1; // adjusted 1
      return 3;
    });
    final r = IntegratedEngine.build(inp(a));
    expect(r.stumbles.map((s) => s.text).join(' '), contains('تحليل أكثر من تنفيذ'));
  });

  test('every statement carries its evidence', () {
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': bigfiveE(5)}));
    expect(r.strengths, isNotEmpty);
    for (final s in [...r.strengths, ...r.stumbles]) {
      expect(s.evidence.trim(), isNotEmpty);
    }
  });

  test('extra-test confidence reflects flagged straight-lining', () {
    final r = IntegratedEngine.build(inp(coherent(), extras: {'bigfive': extra('bigfive', (i) => 3), 'eq': extra('eq', (i) => (i.id * 3) % 5 + 1)}));
    final big = r.extraConfidences.firstWhere((c) => c.subject.contains('Big Five'));
    expect(big.level, ConfidenceLevel.low);
    expect(r.extraConfidences.length, 2);
  });

  test('text export contains every section and is deterministic', () {
    final input = inp(coherent(), extras: {'bigfive': bigfiveE(5)});
    final a = IntegratedEngine.build(input).toText();
    final b = IntegratedEngine.build(input).toText();
    expect(a, b);
    for (final h in ['كيف تتكامل النتائج', 'نقاط القوة', 'مصادر التعثر', 'اتخاذ القرار', 'التعامل مع الضغط', 'صورتك لدى الآخرين', 'درجة الثقة في كل نتيجة']) {
      expect(a, contains(h));
    }
  });
}

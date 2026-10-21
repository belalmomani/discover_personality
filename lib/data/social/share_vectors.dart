import '../models/extra_test.dart';
import '../scoring/extra_scoring.dart';
import '../scoring/scoring_result.dart';

/// Per-test score vector (each value 0..1) published for the weighted similarity.
/// Raw answers are never shared. Sensitive tests (dark traits, attachment) are never shared.
class TestVector {
  const TestVector(this.testId, this.dims);
  final String testId;
  final List<double> dims;

  Map<String, dynamic> toJson() => {'test_id': testId, 'dims': dims};
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Main-test vectors: MBTI (4 poles), Enneagram (9 types), A-R-F-D (4 axes).
List<TestVector> mainVectors(ScoringResult r) {
  final m = r.mbti;
  final mbti = [
    (m[0].pctA + (100 - m[0].pctB)) / 2 / 100, // E
    (m[1].pctB + (100 - m[1].pctA)) / 2 / 100, // N
    (m[2].pctA + (100 - m[2].pctB)) / 2 / 100, // T
    (m[3].pctA + (100 - m[3].pctB)) / 2 / 100, // J
  ];
  final byType = {for (final s in r.enneagramRanking) s.type: s.score};
  final ennea = [for (var t = 1; t <= 9; t++) (byType[t]! - 4) / 16];
  final arfd = [for (final a in r.arfd) (a.avg - 1) / 4];
  return [
    TestVector('main_mbti', mbti.map(_clamp01).toList()),
    TestVector('main_enneagram', ennea.map(_clamp01).toList()),
    TestVector('main_arfd', arfd.map(_clamp01).toList()),
  ];
}

/// All shareable vectors: main test + every completed, non-sensitive additional test.
List<TestVector> buildShareVectors({
  required ScoringResult main,
  required List<ExtraTest> tests,
  required Map<String, Map<int, int>> extraAnswers,
}) {
  final out = <TestVector>[...mainVectors(main)];
  for (final t in tests) {
    final a = extraAnswers[t.id];
    if (t.sensitive || a == null || !ExtraScoring.isComplete(t, a)) continue;
    final s = ExtraScoring.compute(t, a);
    out.add(TestVector('x_${t.id}', s.dims.map((d) => _clamp01(d.pct / 100)).toList()));
  }
  return out;
}

/// Weight of a test in the similarity = its number of questions (matches the server catalog).
Map<String, ({int dims, int items})> expectedCatalog(List<ExtraTest> tests) => {
      'main_mbti': (dims: 4, items: 24),
      'main_enneagram': (dims: 9, items: 36),
      'main_arfd': (dims: 4, items: 12),
      for (final t in tests)
        if (!t.sensitive) 'x_${t.id}': (dims: t.dimensions.length, items: t.items.length),
    };

/// Client-side mirror of the server formula (used for tests and previews only; the server is the authority).
({int similarity, int testsUsed, int questionsUsed})? weightedSimilarity(
  Map<String, List<double>> a,
  Map<String, List<double>> b,
  Map<String, ({int dims, int items})> catalog,
) {
  var weighted = 0.0, weights = 0, used = 0;
  for (final e in a.entries) {
    final other = b[e.key];
    final c = catalog[e.key];
    if (other == null || c == null || other.length != e.value.length) continue;
    var sum = 0.0;
    for (var i = 0; i < other.length; i++) {
      final d = e.value[i] - other[i];
      sum += d * d;
    }
    final dist = _sqrt(sum);
    final sim = 100 * (1 - dist / _sqrt(e.value.length.toDouble()));
    weighted += c.items * sim;
    weights += c.items;
    used++;
  }
  if (used == 0) return null;
  return (similarity: (weighted / weights).round(), testsUsed: used, questionsUsed: weights);
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  var g = x > 1 ? x / 2 : 1.0;
  for (var i = 0; i < 40; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}

import '../../core/config.dart';
import '../models/question.dart';
import 'scoring_result.dart';

class ScoringException implements Exception {
  ScoringException(this.message);
  final String message;
  @override
  String toString() => 'ScoringException: $message';
}

/// Deterministic scoring. No AI, no randomness, no clock.
///
/// MBTI: pole mean -> pct = ((mean - 1) / 4) * 100; a pair is "close" when the
/// gap is below [mbtiCloseThresholdPct] percentage points.
/// Enneagram: sum of 4 answers per type (4..20); candidates are the types whose
/// score is within [enneagramCloseThreshold] points of the top (max 3).
/// A-R-F-D: reverse items -> 6 - x, mean per axis, code uses standard rounding.
class ScoringEngine {
  ScoringEngine._();

  static const int expectedQuestions = 72;
  static const double mbtiCloseThresholdPct = 10.0;
  static const int enneagramCloseThreshold = 2;

  static const List<List<String>> mbtiPairs = [
    ['E', 'I'],
    ['S', 'N'],
    ['T', 'F'],
    ['J', 'P'],
  ];
  static const List<String> arfdAxes = ['A', 'R', 'F', 'D'];

  /// Throws [ScoringException] when answers are missing, unknown or outside 1..5.
  static void validate(List<Question> questions, Map<int, int> answers) {
    if (questions.length != expectedQuestions) {
      throw ScoringException(
          'Expected $expectedQuestions questions, got ${questions.length}.');
    }
    final ids = questions.map((q) => q.id).toSet();
    for (final id in answers.keys) {
      if (!ids.contains(id)) throw ScoringException('Unknown question id $id.');
    }
    for (final q in questions) {
      final v = answers[q.id];
      if (v == null) throw ScoringException('Missing answer for question ${q.id}.');
      if (v < 1 || v > 5) {
        throw ScoringException('Answer for question ${q.id} out of range: $v.');
      }
    }
  }

  static bool isComplete(List<Question> questions, Map<int, int> answers) {
    try {
      validate(questions, answers);
      return true;
    } on ScoringException {
      return false;
    }
  }

  static ScoringResult compute(List<Question> questions, Map<int, int> answers) {
    validate(questions, answers);

    double mean(Iterable<int> values) =>
        values.reduce((a, b) => a + b) / values.length;

    // ---- MBTI
    List<int> mbtiValues(String pole) => questions
        .where((q) => q.system == AssessmentSystem.mbti && q.dimension == pole)
        .map((q) => answers[q.id]!)
        .toList();

    final pairs = <MbtiPairResult>[];
    for (final p in mbtiPairs) {
      final va = mbtiValues(p[0]);
      final vb = mbtiValues(p[1]);
      if (va.isEmpty || vb.isEmpty) {
        throw ScoringException('MBTI pole without questions: ${p[0]}/${p[1]}.');
      }
      final avgA = mean(va);
      final avgB = mean(vb);
      final pctA = ((avgA - 1) / 4) * 100;
      final pctB = ((avgB - 1) / 4) * 100;
      final diff = (pctA - pctB).abs();
      pairs.add(MbtiPairResult(
        poleA: p[0],
        poleB: p[1],
        avgA: avgA,
        avgB: avgB,
        pctA: pctA,
        pctB: pctB,
        isClose: diff < mbtiCloseThresholdPct,
        isTie: pctA == pctB,
      ));
    }

    // ---- Enneagram
    final scores = <EnneagramScore>[];
    for (var t = 1; t <= 9; t++) {
      final vals = questions
          .where((q) =>
              q.system == AssessmentSystem.enneagram && q.dimension == '$t')
          .map((q) => answers[q.id]!)
          .toList();
      if (vals.length != 4) {
        throw ScoringException('Enneagram type $t must have 4 questions.');
      }
      scores.add(EnneagramScore(t, vals.reduce((a, b) => a + b)));
    }
    scores.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.type.compareTo(b.type);
    });
    final top = scores.first;
    final close = scores
        .where((s) => s.score >= top.score - enneagramCloseThreshold)
        .toList();
    final candidates = close.take(3).toList();

    // ---- A-R-F-D
    final axes = <ArfdAxisResult>[];
    for (final axis in arfdAxes) {
      final vals = questions
          .where((q) => q.system == AssessmentSystem.arfd && q.dimension == axis)
          .map((q) => q.reverse ? 6 - answers[q.id]! : answers[q.id]!)
          .toList();
      if (vals.length != 3) {
        throw ScoringException('A-R-F-D axis $axis must have 3 questions.');
      }
      final avg = mean(vals);
      axes.add(ArfdAxisResult(axis: axis, avg: avg, rounded: avg.round()));
    }

    return ScoringResult(
      mbti: pairs,
      enneagramRanking: scores,
      enneagramCandidates: candidates,
      enneagramConclusive: close.length == 1,
      arfd: axes,
      scoringVersion: AppConfig.scoringVersion,
    );
  }
}

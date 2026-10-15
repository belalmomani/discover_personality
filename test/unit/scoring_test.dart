import 'package:discover_personality/data/models/question.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:discover_personality/data/scoring/scoring_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final qs = loadBank().questions;

  Map<int, int> base(int v) => allSame(qs, v);

  test('all answers 3: MBTI ties/close, Enneagram inconclusive, A-R-F-D 3s', () {
    final r = ScoringEngine.compute(qs, base(3));
    for (final p in r.mbti) {
      expect(p.pctA, 50);
      expect(p.pctB, 50);
      expect(p.isTie, isTrue);
      expect(p.isClose, isTrue);
    }
    expect(r.mbtiType, 'ESTJ'); // deterministic tie-break: first pole
    expect(r.enneagramRanking.every((s) => s.score == 12), isTrue);
    expect(r.enneagramConclusive, isFalse);
    expect(r.enneagramCandidates.length, 3); // capped at 3
    expect(r.enneagramCandidates.map((c) => c.type).toList(), [1, 2, 3]);
    expect(r.arfd.every((a) => a.avg == 3 && a.rounded == 3), isTrue);
    expect(r.arfdCode, 'A3-R3-F3-D3');
  });

  test('MBTI formula: ((mean-1)/4)*100 and clear preference', () {
    final a = buildAnswers(qs, (q) {
      if (q.system != AssessmentSystem.mbti) return 3;
      return q.dimension == 'E' ? 5 : (q.dimension == 'I' ? 1 : 3);
    });
    final r = ScoringEngine.compute(qs, a);
    final ei = r.mbti[0];
    expect(ei.avgA, 5);
    expect(ei.pctA, 100);
    expect(ei.avgB, 1);
    expect(ei.pctB, 0);
    expect(ei.preferred, 'E');
    expect(ei.diff, 100);
    expect(ei.isClose, isFalse);
    expect(ei.isTie, isFalse);
  });

  test('MBTI each of the four dimensions is computed from its own questions', () {
    // Prefer I, N, F, P.
    final a = buildAnswers(qs, (q) {
      if (q.system != AssessmentSystem.mbti) return 3;
      return {'I', 'N', 'F', 'P'}.contains(q.dimension) ? 5 : 1;
    });
    expect(ScoringEngine.compute(qs, a).mbtiType, 'INFP');
    final b = buildAnswers(qs, (q) {
      if (q.system != AssessmentSystem.mbti) return 3;
      return {'E', 'S', 'T', 'J'}.contains(q.dimension) ? 5 : 1;
    });
    expect(ScoringEngine.compute(qs, b).mbtiType, 'ESTJ');
  });

  test('MBTI closeness threshold: gap 8.33 is close, gap 16.67 is not', () {
    Map<int, int> withE(List<int> e) {
      final ids = qs.where((q) => q.system == AssessmentSystem.mbti && q.dimension == 'E').map((q) => q.id).toList();
      final a = base(3);
      for (var i = 0; i < 3; i++) {
        a[ids[i]] = e[i];
      }
      return a;
    }

    final close = ScoringEngine.compute(qs, withE([3, 3, 4])).mbti[0];
    expect(close.diff, closeTo(8.33, 0.01));
    expect(close.isClose, isTrue);
    expect(close.preferred, 'E');
    final notClose = ScoringEngine.compute(qs, withE([4, 4, 3])).mbti[0];
    expect(notClose.diff, closeTo(16.67, 0.01));
    expect(notClose.isClose, isFalse);
  });

  test('Enneagram: each of the nine groups sums its own four answers (4..20)', () {
    for (var t = 1; t <= 9; t++) {
      final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.enneagram && q.dimension == '$t' ? 5 : 1);
      final r = ScoringEngine.compute(qs, a);
      expect(r.enneagramTop.type, t);
      expect(r.enneagramTop.score, 20);
      expect(r.enneagramRanking.last.score, 4);
      expect(r.enneagramConclusive, isTrue);
      expect(r.enneagramCandidates.length, 1);
    }
  });

  test('Enneagram: ties sorted by type number (deterministic)', () {
    final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.enneagram && (q.dimension == '7' || q.dimension == '3') ? 5 : 1);
    final r = ScoringEngine.compute(qs, a);
    expect(r.enneagramRanking.take(2).map((s) => s.type).toList(), [3, 7]);
    expect(r.enneagramCandidates.map((c) => c.type).toList(), [3, 7]);
    expect(r.enneagramConclusive, isFalse);
  });

  test('Enneagram: within 2 points counts as close, 3 points does not', () {
    Map<int, int> typeScores(int top, int second) {
      final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.enneagram ? 1 : 3);
      void setSum(int type, int sum) {
        final ids = qs.where((q) => q.system == AssessmentSystem.enneagram && q.dimension == '$type').map((q) => q.id).toList();
        // distribute sum (4..20) over 4 answers
        var rest = sum;
        for (var i = 0; i < 4; i++) {
          final v = (rest - (3 - i)).clamp(1, 5);
          a[ids[i]] = v;
          rest -= v;
        }
      }

      setSum(5, top);
      setSum(2, second);
      return a;
    }

    final near = ScoringEngine.compute(qs, typeScores(16, 14));
    expect(near.enneagramCandidates.map((c) => c.type).toList(), [5, 2]);
    expect(near.enneagramConclusive, isFalse);
    final far = ScoringEngine.compute(qs, typeScores(16, 13));
    expect(far.enneagramCandidates.map((c) => c.type).toList(), [5]);
    expect(far.enneagramConclusive, isTrue);
  });

  test('A-R-F-D reverse scoring: 6 - x', () {
    final r = ScoringEngine.compute(qs, buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd ? 5 : 3));
    // two forward 5s + one reversed 5->1 = 11/3
    for (final a in r.arfd) {
      expect(a.avg, closeTo(11 / 3, 1e-9));
      expect(a.rounded, 4);
    }
    expect(r.arfdCode, 'A4-R4-F4-D4');
    final low = ScoringEngine.compute(qs, buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd ? 1 : 3));
    // two forward 1s + one reversed 1->5 = 7/3
    for (final a in low.arfd) {
      expect(a.avg, closeTo(7 / 3, 1e-9));
      expect(a.rounded, 2);
    }
    expect(low.arfdCode, 'A2-R2-F2-D2');
  });

  test('A-R-F-D reversed single item changes only its own axis', () {
    final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd ? 3 : 3);
    a[66] = 5; // R reverse item -> becomes 1
    final r = ScoringEngine.compute(qs, a);
    expect(r.axis('R').avg, closeTo((3 + 3 + 1) / 3, 1e-9));
    expect(r.axis('A').avg, 3);
    expect(r.axis('F').avg, 3);
    expect(r.axis('D').avg, 3);
  });

  group('validation', () {
    test('missing answers block scoring', () {
      final a = base(3)..remove(10);
      expect(() => ScoringEngine.compute(qs, a), throwsA(isA<ScoringException>()));
      expect(ScoringEngine.isComplete(qs, a), isFalse);
    });
    test('empty answers block scoring', () {
      expect(() => ScoringEngine.compute(qs, {}), throwsA(isA<ScoringException>()));
    });
    test('out of range values are rejected', () {
      expect(() => ScoringEngine.compute(qs, base(3)..[1] = 0), throwsA(isA<ScoringException>()));
      expect(() => ScoringEngine.compute(qs, base(3)..[1] = 6), throwsA(isA<ScoringException>()));
    });
    test('unknown question ids are rejected', () {
      expect(() => ScoringEngine.compute(qs, base(3)..[999] = 3), throwsA(isA<ScoringException>()));
    });
    test('wrong number of questions is rejected', () {
      final fewer = qs.take(71).toList();
      expect(() => ScoringEngine.compute(fewer, allSame(fewer, 3)), throwsA(isA<ScoringException>()));
    });
    test('complete valid answers pass', () {
      expect(ScoringEngine.isComplete(qs, base(4)), isTrue);
    });
  });

  test('same input always gives the same output', () {
    final a = buildAnswers(qs, (q) => (q.id * 7) % 5 + 1);
    final r1 = ScoringEngine.compute(qs, a).toJson();
    final r2 = ScoringEngine.compute(qs, Map<int, int>.from(a)).toJson();
    expect(r1, r2);
  });

  test('result survives a JSON round trip', () {
    final a = buildAnswers(qs, (q) => (q.id * 3) % 5 + 1);
    final r = ScoringEngine.compute(qs, a);
    final back = ScoringResult.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(back.mbtiType, r.mbtiType);
    expect(back.arfdCode, r.arfdCode);
  });
}

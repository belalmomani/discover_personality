import 'package:discover_personality/data/models/question.dart';
import 'package:discover_personality/data/report/plan_generator.dart';
import 'package:discover_personality/data/report/report_builder.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final qs = loadBank().questions;

  test('plan has 30 days, 4 weeks, 3 measurable goals and nothing completed', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 3));
    final plan = PlanGenerator.generate('rid', r);
    expect(plan.days.length, 30);
    expect(plan.days.map((d) => d.day).toList(), List<int>.generate(30, (i) => i + 1));
    expect(plan.weeks.length, 4);
    expect(plan.goals.length, 3);
    expect(plan.doneCount, 0);
    expect(plan.days.every((d) => d.text.trim().isNotEmpty), isTrue);
  });

  test('weakest axis is chosen deterministically (first axis wins ties)', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 3));
    expect(PlanGenerator.weakestAxis(r).axis, 'A');
    final a = buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd && q.dimension == 'F' ? 1 : 3);
    final r2 = ScoringEngine.compute(qs, a);
    expect(PlanGenerator.weakestAxis(r2).axis, 'F');
  });

  test('plans differ for different results (not one-size-fits-all)', () {
    final lowF = ScoringEngine.compute(qs, buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd && q.dimension == 'F' ? 1 : 3));
    final lowR = ScoringEngine.compute(qs, buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd && q.dimension == 'R' ? 1 : 3));
    final p1 = PlanGenerator.generate('a', lowF).days.map((d) => d.text).toList();
    final p2 = PlanGenerator.generate('b', lowR).days.map((d) => d.text).toList();
    expect(p1, isNot(p2));
  });

  test('plan edits and completion persist through JSON', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 3));
    final plan = PlanGenerator.generate('rid', r);
    plan.days[0].done = true;
    plan.days[0].text = 'مهمة معدّلة';
    plan.goals[0].current = 5;
    plan.weeks[0].review = 'مراجعة';
    plan.finalSummary = 'ملخص';
    final back = plan.toJson();
    expect(back['finalSummary'], 'ملخص');
    expect(((back['days'] as List).first as Map)['done'], true);
    expect(((back['days'] as List).first as Map)['text'], 'مهمة معدّلة');
  });

  test('report: no invented contradictions for a neutral result', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 3));
    final rep = ReportBuilder.build(r);
    expect(rep.contradictions, isEmpty);
    expect(rep.mbtiLines.every((l) => l.contains('متقارب')), isTrue);
    expect(rep.notes.join(' '), contains('ليست تشخيصًا'));
  });

  test('report: contradiction appears only when supported (J strong + low F)', () {
    final a = buildAnswers(qs, (q) {
      if (q.system == AssessmentSystem.mbti) return q.dimension == 'J' ? 5 : (q.dimension == 'P' ? 1 : 3);
      if (q.system == AssessmentSystem.arfd && q.dimension == 'F') return q.reverse ? 5 : 1; // F avg = 1
      return 3;
    });
    final rep = ReportBuilder.build(ScoringEngine.compute(qs, a));
    expect(rep.contradictions.length, 1);
    expect(rep.contradictions.first, contains('(J)'));
  });

  test('AI payload contains scores only (no raw answers, no personal data)', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 4));
    final p = ReportBuilder.aiPayload(r);
    expect(p.keys.toSet(), {'locale', 'mbti_type', 'mbti_percent', 'enneagram_scores', 'enneagram_conclusive', 'arfd_code', 'arfd_averages'});
    expect((p['enneagram_scores'] as Map).length, 9);
  });
}

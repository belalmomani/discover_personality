import 'package:discover_personality/data/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final bank = loadBank();
  final qs = bank.questions;

  test('there are exactly 72 questions', () => expect(qs.length, 72));

  test('24 MBTI, 36 Enneagram, 12 A-R-F-D', () {
    int c(AssessmentSystem s) => qs.where((q) => q.system == s).length;
    expect(c(AssessmentSystem.mbti), 24);
    expect(c(AssessmentSystem.enneagram), 36);
    expect(c(AssessmentSystem.arfd), 12);
  });

  test('ids are 1..72, unique and ordered', () {
    expect(qs.map((q) => q.id).toList(), List<int>.generate(72, (i) => i + 1));
    expect(qs.map((q) => q.id).toSet().length, 72);
  });

  test('every question has non-empty text and no leftover "reverse" notes', () {
    for (final q in qs) {
      expect(q.text.trim(), isNotEmpty);
      expect(q.text.contains('هذا السؤال عكسي'), isFalse);
    }
  });

  test('MBTI: three questions for each of the eight poles', () {
    for (final p in ['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P']) {
      expect(qs.where((q) => q.system == AssessmentSystem.mbti && q.dimension == p).length, 3, reason: p);
    }
  });

  test('Enneagram: four questions per type, type number and topic stored', () {
    for (var t = 1; t <= 9; t++) {
      final list = qs.where((q) => q.system == AssessmentSystem.enneagram && q.dimension == '$t');
      expect(list.length, 4, reason: 'type $t');
      expect(list.every((q) => q.topic.isNotEmpty), isTrue);
    }
  });

  test('A-R-F-D: three questions per axis; reverse items are exactly 63, 66, 69, 72', () {
    for (final a in ['A', 'R', 'F', 'D']) {
      expect(qs.where((q) => q.system == AssessmentSystem.arfd && q.dimension == a).length, 3, reason: a);
    }
    expect(qs.where((q) => q.reverse).map((q) => q.id).toList(), [63, 66, 69, 72]);
  });

  test('scale has 5 options with values 1..5', () {
    expect(bank.scale.map((s) => s.value).toList(), [1, 2, 3, 4, 5]);
  });
}

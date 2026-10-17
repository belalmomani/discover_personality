import 'dart:io';

import 'package:discover_personality/data/models/extra_test.dart';
import 'package:discover_personality/data/models/question.dart';
import 'package:discover_personality/data/repositories/question_repository.dart';

/// Loads the real question bank straight from the asset file (no Flutter bindings needed).
QuestionBank loadBank() =>
    QuestionRepository.parse(File('assets/data/questions_ar.json').readAsStringSync());

/// Builds an answer map by applying [f] to every question.
Map<int, int> buildAnswers(List<Question> qs, int Function(Question q) f) =>
    {for (final q in qs) q.id: f(q)};

Map<int, int> allSame(List<Question> qs, int v) => buildAnswers(qs, (_) => v);

/// Loads the additional-tests asset straight from disk.
List<ExtraTest> loadExtraTests() =>
    ExtraTestRepository.parse(File('assets/data/extra_tests.json').readAsStringSync());

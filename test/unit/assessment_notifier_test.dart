import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final qs = loadBank().questions;

  Future<LocalStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return LocalStore(await SharedPreferences.getInstance());
  }

  test('answers are persisted and restored by a new notifier', () async {
    final s = await store();
    final n1 = AssessmentNotifier(s, qs);
    await n1.answer(1, 5);
    await n1.answer(2, 2);
    await n1.goTo(2);
    final n2 = AssessmentNotifier(s, qs); // simulates an app restart
    expect(n2.state.answers, {1: 5, 2: 2});
    expect(n2.state.index, 2);
    expect(n2.state.sessionId, n1.state.sessionId);
    expect(n2.hasProgress, isTrue);
  });

  test('results are NOT produced before all answers exist', () async {
    final s = await store();
    final n = AssessmentNotifier(s, qs);
    for (final q in qs.take(71)) {
      await n.answer(q.id, 3);
    }
    expect(n.isComplete, isFalse);
    expect(n.firstUnansweredIndex(), 71);
    await expectLater(n.finish(), throwsA(isA<ScoringException>()));
    expect(s.loadProgress(), isNotNull, reason: 'progress must survive a failed finish');
  });

  test('finish works when complete, clears progress and starts a new session', () async {
    final s = await store();
    final n = AssessmentNotifier(s, qs);
    final oldSession = n.state.sessionId;
    for (final q in qs) {
      await n.answer(q.id, 4);
    }
    expect(n.isComplete, isTrue);
    final saved = await n.finish();
    expect(saved.id, oldSession);
    expect(saved.answers.length, 72);
    expect(s.loadProgress(), isNull);
    expect(n.state.answers, isEmpty);
    expect(n.state.sessionId, isNot(oldSession));
  });

  test('values outside 1..5 are rejected', () async {
    final n = AssessmentNotifier(await store(), qs);
    await expectLater(n.answer(1, 0), throwsArgumentError);
    await expectLater(n.answer(1, 6), throwsArgumentError);
    expect(n.state.answers, isEmpty);
  });

  test('restore ignores stale or invalid saved answers', () async {
    SharedPreferences.setMockInitialValues({
      'progress.v1': '{"sessionId":"x","startedAt":"2026-01-01T00:00:00.000Z","answers":{"1":3,"999":3,"2":9},"index":500}',
    });
    final n = AssessmentNotifier(LocalStore(await SharedPreferences.getInstance()), qs);
    expect(n.state.answers, {1: 3});
    expect(n.state.index, 71);
  });
}

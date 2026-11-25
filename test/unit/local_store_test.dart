import 'package:discover_personality/data/models/saved_result.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalStore> freshStore([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return LocalStore(await SharedPreferences.getInstance());
  }

  test('progress is saved and restored', () async {
    final store = await freshStore();
    final p = AssessmentProgress(sessionId: 'sid', startedAt: DateTime.utc(2026, 1, 1), answers: {1: 4, 5: 2}, index: 7);
    await store.saveProgress(p);
    final back = store.loadProgress()!;
    expect(back.sessionId, 'sid');
    expect(back.answers, {1: 4, 5: 2});
    expect(back.index, 7);
    await store.clearProgress();
    expect(store.loadProgress(), isNull);
  });

  test('corrupt stored data is discarded instead of crashing', () async {
    final store = await freshStore({'progress.v1': '{not json', 'history.v1': 'oops', 'settings.v1': '[]'});
    expect(store.loadProgress(), isNull);
    expect(store.loadHistory(), isEmpty);
    expect(store.loadSettings().onboardingDone, isFalse);
    expect(store.loadPlans(), isEmpty);
  });

  test('history round trip keeps answers and result', () async {
    final qs = loadBank().questions;
    final answers = allSame(qs, 4);
    final saved = SavedResult(id: 'r1', createdAt: DateTime.utc(2026, 2, 2), answers: answers, result: ScoringEngine.compute(qs, answers));
    final store = await freshStore();
    await store.saveHistory([saved]);
    final back = store.loadHistory();
    expect(back.length, 1);
    expect(back.first.answers.length, 72);
    expect(back.first.result.arfdCode, saved.result.arfdCode);
    expect(back.first.synced, isFalse);
  });

  test('clearUserData removes progress/history/plans but keeps settings', () async {
    final store = await freshStore();
    await store.saveSettings(const AppSettings(onboardingDone: true));
    await store.saveProgress(AssessmentProgress(sessionId: 's', startedAt: DateTime.now(), answers: {1: 1}, index: 0));
    await store.saveHistory([]);
    await store.clearUserData();
    expect(store.loadProgress(), isNull);
    expect(store.loadSettings().onboardingDone, isTrue);
  });

  test('ads and AI consent default to false', () async {
    final store = await freshStore();
    final s = store.loadSettings();
    expect(s.adsConsent, isFalse);
    expect(s.aiConsent, isFalse);
  });
}

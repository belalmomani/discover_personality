import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// End-to-end flow at the state level (no device): answer -> finish -> persist -> restore -> plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final qs = loadBank().questions;

  test('full journey: answer 72, compute, save, restart, restore, plan progress persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);

    final n = AssessmentNotifier(store, qs);
    for (final q in qs) {
      await n.answer(q.id, (q.id * 7) % 5 + 1);
    }
    final saved = await n.finish();
    await HistoryNotifier(store).add(saved);

    // "restart the app"
    final history2 = HistoryNotifier(store);
    expect(history2.state.length, 1);
    expect(history2.state.first.result.toJson(), saved.result.toJson());

    final plans = PlansNotifier(store);
    final plan = plans.ensure(history2.state.first);
    plan.days[2].done = true;
    plan.goals[1].current = 4;
    await plans.commit();

    final plans2 = PlansNotifier(store);
    final restored = plans2.state[saved.id]!;
    expect(restored.days[2].done, isTrue);
    expect(restored.goals[1].current, 4);
    expect(restored.doneCount, 1);

    // retest: a second assessment is stored next to the first, newest first
    final n2 = AssessmentNotifier(store, qs);
    for (final q in qs) {
      await n2.answer(q.id, 3);
    }
    final second = await n2.finish();
    await history2.add(second);
    expect(HistoryNotifier(store).state.map((r) => r.id).toList(), [second.id, saved.id]);

    // user deletes local data
    await store.clearUserData();
    expect(HistoryNotifier(store).state, isEmpty);
    expect(PlansNotifier(store).state, isEmpty);
  });
}

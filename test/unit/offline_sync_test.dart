import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/models/dev_plan.dart';
import 'package:discover_personality/data/models/saved_result.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:discover_personality/data/services/sync_service.dart';
import 'package:discover_personality/data/supabase/cloud_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class FailingCloud implements CloudApi {
  int calls = 0;
  @override
  bool get isConfigured => true;
  @override
  String? get userId => 'user-1';
  @override
  String? get accessToken => 'token';
  @override
  Future<void> upsertResult(SavedResult r) async {
    calls++;
    throw Exception('no internet');
  }

  @override
  Future<void> upsertPlan(DevPlan p) async {
    calls++;
    throw Exception('no internet');
  }

  @override
  Future<void> deleteAccount() async {}
}

class OkCloud extends FailingCloud {
  @override
  Future<void> upsertResult(SavedResult r) async => calls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final qs = loadBank().questions;

  SavedResult sample(String id, {bool synced = false}) {
    final a = allSame(qs, 3);
    return SavedResult(id: id, createdAt: DateTime.utc(2026), answers: a, result: ScoringEngine.compute(qs, a), synced: synced);
  }

  test('the whole assessment works with no cloud at all (offline / unconfigured)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final n = AssessmentNotifier(store, qs);
    for (final q in qs) {
      await n.answer(q.id, 3);
    }
    final saved = await n.finish();
    final sync = SyncService(NoCloudApi());
    expect(sync.canSync, isFalse);
    expect(await sync.syncResults([saved]), isEmpty);
    expect(saved.result.arfdCode, 'A3-R3-F3-D3');
  });

  test('a failing network never throws; results stay unsynced for a later retry', () async {
    final cloud = FailingCloud();
    final sync = SyncService(cloud);
    expect(await sync.syncResults([sample('a'), sample('b')]), isEmpty);
    expect(cloud.calls, 2);
    expect(await sync.syncPlan(DevPlan(id: 'p', resultId: 'a', createdAt: DateTime.utc(2026), weeks: [], days: [], goals: [])), isFalse);
  });

  test('only unsynced results are uploaded', () async {
    final cloud = OkCloud();
    final ok = await SyncService(cloud).syncResults([sample('a'), sample('b', synced: true)]);
    expect(ok, ['a']);
    expect(cloud.calls, 1);
  });

  test('history notifier marks synced ids and persists them', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final h = HistoryNotifier(store);
    await h.add(sample('a'));
    await h.markSynced(['a']);
    expect(HistoryNotifier(store).state.first.synced, isTrue);
  });
}

import 'package:flutter/foundation.dart';

import '../models/dev_plan.dart';
import '../models/saved_result.dart';
import '../supabase/cloud_api.dart';

/// Best-effort cloud sync. Offline / unconfigured / signed-out => silent no-op.
class SyncService {
  SyncService(this._cloud);
  final CloudApi _cloud;

  bool get canSync => _cloud.isConfigured && _cloud.userId != null;

  /// Returns ids that were synced successfully.
  Future<List<String>> syncResults(List<SavedResult> results) async {
    if (!canSync) return const [];
    final ok = <String>[];
    for (final r in results.where((e) => !e.synced)) {
      try {
        await _cloud.upsertResult(r);
        ok.add(r.id);
      } catch (e) {
        debugPrint('sync result failed (will retry later): $e');
      }
    }
    return ok;
  }

  Future<bool> syncPlan(DevPlan plan) async {
    if (!canSync) return false;
    try {
      await _cloud.upsertPlan(plan);
      return true;
    } catch (e) {
      debugPrint('sync plan failed: $e');
      return false;
    }
  }
}

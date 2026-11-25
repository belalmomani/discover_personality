import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../models/dev_plan.dart';
import '../models/saved_result.dart';
import '../report/report_builder.dart';

/// Cloud operations. Everything is optional: the app never requires Supabase.
abstract class CloudApi {
  bool get isConfigured;
  String? get userId;
  String? get accessToken;
  Future<void> upsertResult(SavedResult r);
  Future<void> upsertPlan(DevPlan p);
  Future<void> deleteAccount();
}

class NoCloudApi implements CloudApi {
  @override
  bool get isConfigured => false;
  @override
  String? get userId => null;
  @override
  String? get accessToken => null;
  @override
  Future<void> upsertResult(SavedResult r) async {}
  @override
  Future<void> upsertPlan(DevPlan p) async {}
  @override
  Future<void> deleteAccount() async {}
}

class SupabaseCloudApi implements CloudApi {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  bool get isConfigured => AppConfig.supabaseConfigured;

  @override
  String? get userId => _c.auth.currentUser?.id;

  @override
  String? get accessToken => _c.auth.currentSession?.accessToken;

  @override
  Future<void> upsertResult(SavedResult r) async {
    final uid = userId;
    if (uid == null) throw StateError('not signed in');
    final now = DateTime.now().toUtc().toIso8601String();
    await _c.from('assessment_sessions').upsert({
      'id': r.id,
      'user_id': uid,
      'status': 'completed',
      'scoring_version': r.result.scoringVersion,
      'started_at': r.createdAt.toUtc().toIso8601String(),
      'completed_at': r.createdAt.toUtc().toIso8601String(),
    });
    await _c.from('answers').upsert(
      [
        for (final e in r.answers.entries)
          {'session_id': r.id, 'user_id': uid, 'question_id': e.key, 'value': e.value},
      ],
      onConflict: 'session_id,question_id',
    );
    await _c.from('assessment_results').upsert({
      'session_id': r.id,
      'user_id': uid,
      'mbti': r.result.mbti.map((e) => e.toJson()).toList(),
      'enneagram': r.result.enneagramRanking.map((e) => e.toJson()).toList(),
      'arfd': r.result.arfd.map((e) => e.toJson()).toList(),
      'mbti_type': r.result.mbtiType,
      'arfd_code': r.result.arfdCode,
    });
    await _c.from('reports').upsert({
      'session_id': r.id,
      'user_id': uid,
      'content': ReportBuilder.build(r.result).toJson(),
      'source': 'local',
      'updated_at': now,
    });
  }

  @override
  Future<void> upsertPlan(DevPlan p) async {
    final uid = userId;
    if (uid == null) throw StateError('not signed in');
    await _c.from('development_plans').upsert({
      'id': p.id,
      'user_id': uid,
      'session_id': p.resultId,
      'plan': p.toJson(),
    });
    await _c.from('progress_logs').upsert(
      [
        for (final d in p.days)
          {'plan_id': p.id, 'user_id': uid, 'day': d.day, 'done': d.done, 'note': d.note},
      ],
      onConflict: 'plan_id,day',
    );
  }

  @override
  Future<void> deleteAccount() async {
    await _c.rpc('delete_my_account');
    await _c.auth.signOut();
  }
}

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/utils.dart';
import '../data/ads/ad_service.dart';
import '../data/ads/startio_backend.dart';
import '../data/ai/ai_explainer.dart';
import '../data/models/dev_plan.dart';
import '../data/models/extra_result.dart';
import '../data/integrated/observer.dart';
import '../data/models/extra_test.dart';
import '../data/models/question.dart';
import '../data/models/saved_result.dart';
import '../data/report/plan_generator.dart';
import '../data/repositories/local_store.dart';
import '../data/scoring/scoring_engine.dart';
import '../data/services/sync_service.dart';
import '../data/social/social_api.dart';
import '../data/supabase/cloud_api.dart';

// ---- Overridden in main() / tests
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final questionBankProvider = Provider<QuestionBank>((ref) => throw UnimplementedError());

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPrefsProvider)));

final cloudApiProvider = Provider<CloudApi>((ref) => NoCloudApi());
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref.watch(cloudApiProvider)));

final adServiceProvider = Provider<AdService>((ref) => AdService(
      enabled: AppConfig.adsEnabled,
      testMode: AppConfig.startIoTestMode,
      backendFactory: () => StartIoBackend(),
    ));

final aiExplainerProvider = Provider<AiExplainer>((ref) {
  if (!AppConfig.aiConfigured) return DisabledAiExplainer();
  final cloud = ref.watch(cloudApiProvider);
  return ProxyAiExplainer(
    url: AppConfig.aiProxyUrl,
    tokenProvider: () => cloud.accessToken ?? (AppConfig.supabaseConfigured ? AppConfig.supabaseAnonKey : null),
  );
});

// ---- Settings
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._store) : super(_store.loadSettings());
  final LocalStore _store;

  Future<void> _set(AppSettings s) async {
    state = s;
    await _store.saveSettings(s);
  }

  Future<void> setTheme(ThemeMode m) => _set(state.copyWith(themeMode: m));
  Future<void> setAiConsent(bool v) => _set(state.copyWith(aiConsent: v));
  Future<void> setAdsConsent(bool v) => _set(state.copyWith(adsConsent: v));
  Future<void> completeOnboarding() => _set(state.copyWith(onboardingDone: true));
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier(ref.watch(localStoreProvider)));

// ---- History
class HistoryNotifier extends StateNotifier<List<SavedResult>> {
  HistoryNotifier(this._store) : super(_store.loadHistory());
  final LocalStore _store;

  /// Newest first.
  Future<void> add(SavedResult r) async {
    state = [r, ...state];
    await _store.saveHistory(state);
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    state = [for (final r in state) ids.contains(r.id) ? r.copyWith(synced: true) : r];
    await _store.saveHistory(state);
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _store.saveHistory(state);
  }

  Future<void> clear() async {
    state = [];
    await _store.saveHistory(state);
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<SavedResult>>((ref) => HistoryNotifier(ref.watch(localStoreProvider)));

// ---- Assessment (in-progress)
class AssessmentState {
  const AssessmentState({
    required this.sessionId,
    required this.startedAt,
    required this.answers,
    required this.index,
  });
  final String sessionId;
  final DateTime startedAt;
  final Map<int, int> answers;
  final int index;

  AssessmentState copyWith({Map<int, int>? answers, int? index}) => AssessmentState(
        sessionId: sessionId,
        startedAt: startedAt,
        answers: answers ?? this.answers,
        index: index ?? this.index,
      );
}

class AssessmentNotifier extends StateNotifier<AssessmentState> {
  AssessmentNotifier(this._store, this.questions)
      : super(_restore(_store, questions));

  final LocalStore _store;
  final List<Question> questions;

  static AssessmentState _restore(LocalStore store, List<Question> qs) {
    final p = store.loadProgress();
    if (p != null) {
      final ids = qs.map((q) => q.id).toSet();
      final clean = Map<int, int>.fromEntries(
          p.answers.entries.where((e) => ids.contains(e.key) && e.value >= 1 && e.value <= 5));
      final idx = p.index.clamp(0, qs.length - 1);
      return AssessmentState(sessionId: p.sessionId, startedAt: p.startedAt, answers: clean, index: idx);
    }
    return AssessmentState(sessionId: newUuid(), startedAt: DateTime.now(), answers: const {}, index: 0);
  }

  bool get hasProgress => state.answers.isNotEmpty;
  int get answeredCount => state.answers.length;
  bool get isComplete => ScoringEngine.isComplete(questions, state.answers);
  int? firstUnansweredIndex() {
    for (var i = 0; i < questions.length; i++) {
      if (!state.answers.containsKey(questions[i].id)) return i;
    }
    return null;
  }

  Future<void> _persist() => _store.saveProgress(AssessmentProgress(
        sessionId: state.sessionId,
        startedAt: state.startedAt,
        answers: state.answers,
        index: state.index,
      ));

  Future<void> answer(int questionId, int value) async {
    if (value < 1 || value > 5) throw ArgumentError('value must be 1..5');
    state = state.copyWith(answers: {...state.answers, questionId: value});
    await _persist();
  }

  Future<void> goTo(int index) async {
    state = state.copyWith(index: index.clamp(0, questions.length - 1));
    await _persist();
  }

  /// Computes the result ONLY when every answer exists. Throws [ScoringException] otherwise.
  Future<SavedResult> finish() async {
    final result = ScoringEngine.compute(questions, state.answers);
    final saved = SavedResult(
      id: state.sessionId,
      createdAt: DateTime.now(),
      answers: Map<int, int>.from(state.answers),
      result: result,
    );
    await _store.clearProgress();
    state = AssessmentState(sessionId: newUuid(), startedAt: DateTime.now(), answers: const {}, index: 0);
    return saved;
  }

  Future<void> restart() async {
    await _store.clearProgress();
    state = AssessmentState(sessionId: newUuid(), startedAt: DateTime.now(), answers: const {}, index: 0);
  }
}

final assessmentProvider = StateNotifierProvider<AssessmentNotifier, AssessmentState>(
    (ref) => AssessmentNotifier(ref.watch(localStoreProvider), ref.watch(questionBankProvider).questions));

// ---- Plans
class PlansNotifier extends StateNotifier<Map<String, DevPlan>> {
  PlansNotifier(this._store) : super(_store.loadPlans());
  final LocalStore _store;

  DevPlan ensure(SavedResult r) {
    final existing = state[r.id];
    if (existing != null) return existing;
    final plan = PlanGenerator.generate(r.id, r.result);
    state = {...state, r.id: plan};
    _store.savePlans(state);
    return plan;
  }

  /// Plan objects are mutable; call after editing one to persist and notify listeners.
  Future<void> commit() async {
    state = Map<String, DevPlan>.from(state);
    await _store.savePlans(state);
  }

  Future<void> regenerate(SavedResult r) async {
    state = {...state, r.id: PlanGenerator.generate(r.id, r.result)};
    await _store.savePlans(state);
  }

  Future<void> removeFor(String resultId) async {
    state = Map<String, DevPlan>.from(state)..remove(resultId);
    await _store.savePlans(state);
  }

  Future<void> clear() async {
    state = {};
    await _store.savePlans(state);
  }
}

final plansProvider = StateNotifierProvider<PlansNotifier, Map<String, DevPlan>>(
    (ref) => PlansNotifier(ref.watch(localStoreProvider)));

// ---- Additional tests + personal profile
final extraTestsProvider = Provider<List<ExtraTest>>((ref) => const <ExtraTest>[]);

class ExtraResultsNotifier extends StateNotifier<Map<String, ExtraResult>> {
  ExtraResultsNotifier(this._store) : super(_store.loadExtra());
  final LocalStore _store;

  Future<void> save(String testId, Map<int, int> answers) async {
    state = {...state, testId: ExtraResult(testId: testId, createdAt: DateTime.now(), answers: Map<int, int>.from(answers))};
    await _store.saveExtra(state);
  }

  Future<void> clear() async {
    state = {};
    await _store.saveExtra(state);
  }
}

final extraResultsProvider = StateNotifierProvider<ExtraResultsNotifier, Map<String, ExtraResult>>(
    (ref) => ExtraResultsNotifier(ref.watch(localStoreProvider)));

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._store) : super(_store.loadProfile());
  final LocalStore _store;

  Future<void> setBirthDate(DateTime d) async {
    state = state.copyWith(birthDate: DateTime(d.year, d.month, d.day));
    await _store.saveProfile(state);
  }

  Future<void> setCountry(String code) async {
    state = state.copyWith(countryCode: code);
    await _store.saveProfile(state);
  }

  Future<void> clear() async {
    state = const UserProfile();
    await _store.saveProfile(state);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((ref) => ProfileNotifier(ref.watch(localStoreProvider)));

// ---- Social layer (similar people, chat, gifts). Off unless Supabase is configured.
final socialApiProvider = Provider<SocialApi>((ref) => NoSocialApi());

// ---- Ratings from other people about the user (device-only)
class ObserversNotifier extends StateNotifier<List<ObserverRating>> {
  ObserversNotifier(this._store) : super(_store.loadObservers());
  final LocalStore _store;

  Future<void> add(String relation, Map<int, int> answers) async {
    if (!ObserverRating.isComplete(answers)) throw ArgumentError('incomplete rating');
    state = [...state, ObserverRating(id: newUuid(), createdAt: DateTime.now(), relation: relation, answers: Map<int, int>.from(answers))];
    await _store.saveObservers(state);
  }

  Future<void> clear() async {
    state = [];
    await _store.saveObservers(state);
  }
}

final observersProvider =
    StateNotifierProvider<ObserversNotifier, List<ObserverRating>>((ref) => ObserversNotifier(ref.watch(localStoreProvider)));

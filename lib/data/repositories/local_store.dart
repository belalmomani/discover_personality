import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../integrated/observer.dart';
import '../models/dev_plan.dart';
import '../models/extra_result.dart';
import '../models/saved_result.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.aiConsent = false,
    this.adsConsent = false,
    this.onboardingDone = false,
  });
  final ThemeMode themeMode;
  final bool aiConsent;
  final bool adsConsent;
  final bool onboardingDone;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? aiConsent,
    bool? adsConsent,
    bool? onboardingDone,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        aiConsent: aiConsent ?? this.aiConsent,
        adsConsent: adsConsent ?? this.adsConsent,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'aiConsent': aiConsent,
        'adsConsent': adsConsent,
        'onboardingDone': onboardingDone,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
            (m) => m.name == j['themeMode'],
            orElse: () => ThemeMode.system),
        aiConsent: (j['aiConsent'] as bool?) ?? false,
        adsConsent: (j['adsConsent'] as bool?) ?? false,
        onboardingDone: (j['onboardingDone'] as bool?) ?? false,
      );
}

/// All on-device persistence (works fully offline). Corrupt data is discarded, never thrown.
class LocalStore {
  LocalStore(this._p);
  final SharedPreferences _p;

  static const _kProgress = 'progress.v1';
  static const _kHistory = 'history.v1';
  static const _kPlans = 'plans.v1';
  static const _kSettings = 'settings.v1';
  static const _kExtra = 'extra.v1';
  static const _kProfile = 'profile.v1';
  static const _kObservers = 'observers.v1';
  static const _kExtraProgress = 'extra_progress.v1';

  Map<String, dynamic>? _readMap(String key) {
    final s = _p.getString(key);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? _readList(String key) {
    final s = _p.getString(key);
    if (s == null) return null;
    try {
      return jsonDecode(s) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Progress
  AssessmentProgress? loadProgress() {
    final m = _readMap(_kProgress);
    if (m == null) return null;
    try {
      return AssessmentProgress.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(AssessmentProgress p) =>
      _p.setString(_kProgress, jsonEncode(p.toJson()));
  Future<void> clearProgress() => _p.remove(_kProgress);

  // History
  List<SavedResult> loadHistory() {
    final l = _readList(_kHistory);
    if (l == null) return [];
    final out = <SavedResult>[];
    for (final e in l) {
      try {
        out.add(SavedResult.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveHistory(List<SavedResult> h) =>
      _p.setString(_kHistory, jsonEncode(h.map((e) => e.toJson()).toList()));

  // Plans (resultId -> plan)
  Map<String, DevPlan> loadPlans() {
    final m = _readMap(_kPlans);
    if (m == null) return {};
    final out = <String, DevPlan>{};
    m.forEach((k, v) {
      try {
        out[k] = DevPlan.fromJson(v as Map<String, dynamic>);
      } catch (_) {}
    });
    return out;
  }

  Future<void> savePlans(Map<String, DevPlan> plans) => _p.setString(
      _kPlans, jsonEncode(plans.map((k, v) => MapEntry(k, v.toJson()))));

  // Settings
  AppSettings loadSettings() {
    final m = _readMap(_kSettings);
    if (m == null) return const AppSettings();
    try {
      return AppSettings.fromJson(m);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) =>
      _p.setString(_kSettings, jsonEncode(s.toJson()));

  // Additional tests (testId -> latest result). Never synced to the cloud.
  Map<String, ExtraResult> loadExtra() {
    final m = _readMap(_kExtra);
    if (m == null) return {};
    final out = <String, ExtraResult>{};
    m.forEach((k, v) {
      try {
        out[k] = ExtraResult.fromJson(v as Map<String, dynamic>);
      } catch (_) {}
    });
    return out;
  }

  Future<void> saveExtra(Map<String, ExtraResult> r) =>
      _p.setString(_kExtra, jsonEncode(r.map((k, v) => MapEntry(k, v.toJson()))));

  // Personal profile (birth date, country). Local only.
  UserProfile loadProfile() {
    final m = _readMap(_kProfile);
    if (m == null) return const UserProfile();
    try {
      return UserProfile.fromJson(m);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile p) => _p.setString(_kProfile, jsonEncode(p.toJson()));

  // Unfinished additional tests (testId -> answers so far)
  Map<String, Map<int, int>> loadExtraProgress() {
    final m = _readMap(_kExtraProgress);
    if (m == null) return {};
    final out = <String, Map<int, int>>{};
    m.forEach((k, v) {
      try {
        final a = (v as Map<String, dynamic>).map((ik, iv) => MapEntry(int.parse(ik), iv as int));
        if (a.values.every((x) => x >= 1 && x <= 5)) out[k] = a;
      } catch (_) {}
    });
    return out;
  }

  Future<void> saveExtraProgress(Map<String, Map<int, int>> p) => _p.setString(
      _kExtraProgress, jsonEncode(p.map((k, v) => MapEntry(k, v.map((ik, iv) => MapEntry('$ik', iv))))));

  // Ratings by other people (device-only)
  List<ObserverRating> loadObservers() {
    final l = _readList(_kObservers);
    if (l == null) return [];
    final out = <ObserverRating>[];
    for (final e in l) {
      try {
        final r = ObserverRating.fromJson(e as Map<String, dynamic>);
        if (ObserverRating.isComplete(r.answers)) out.add(r);
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveObservers(List<ObserverRating> r) =>
      _p.setString(_kObservers, jsonEncode(r.map((e) => e.toJson()).toList()));

  /// Deletes every assessment-related value on this device (settings are kept).
  Future<void> clearUserData() async {
    await _p.remove(_kProgress);
    await _p.remove(_kHistory);
    await _p.remove(_kPlans);
    await _p.remove(_kExtra);
    await _p.remove(_kProfile);
    await _p.remove(_kObservers);
    await _p.remove(_kExtraProgress);
  }
}

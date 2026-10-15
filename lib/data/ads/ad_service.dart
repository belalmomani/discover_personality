import 'package:flutter/widgets.dart';

import 'ad_backend.dart';

/// Where an ad could appear. [assessment] is ALWAYS blocked.
enum AdPlacement {
  homeBanner,
  resultsBanner,
  resultsExitInterstitial,
  assessment,
}

/// Single entry point for ads. Default state: disabled.
///
/// Rules enforced here (and covered by tests):
/// - nothing is created/loaded unless [enabled] AND the user's consent is true;
/// - never during the assessment;
/// - interstitials only on leaving the results screen, max [maxInterstitialsPerSession]
///   per session and at least [minInterstitialGap] apart;
/// - every failure is swallowed (returns null/false), never thrown.
class AdService {
  AdService({
    required this.enabled,
    required this.testMode,
    required AdBackend Function() backendFactory,
    DateTime Function()? clock,
  })  : _factory = backendFactory,
        _clock = clock ?? DateTime.now;

  final bool enabled;
  final bool testMode;
  final AdBackend Function() _factory;
  final DateTime Function() _clock;

  static const int maxInterstitialsPerSession = 2;
  static const Duration minInterstitialGap = Duration(minutes: 3);

  AdBackend? _backend;
  bool _initialized = false;
  int _shownThisSession = 0;
  DateTime? _lastShown;

  bool _allowed(bool consent) => enabled && consent;

  Future<AdBackend?> _ensure(bool consent) async {
    if (!_allowed(consent)) return null;
    try {
      _backend ??= _factory();
      if (!_initialized) {
        await _backend!.initialize(testMode: testMode);
        _initialized = true;
      }
      return _backend;
    } catch (e) {
      debugPrint('AdService init failed: $e');
      return null;
    }
  }

  Future<Widget?> bannerFor(AdPlacement placement, {required bool consent}) async {
    if (placement != AdPlacement.homeBanner &&
        placement != AdPlacement.resultsBanner) {
      return null;
    }
    final b = await _ensure(consent);
    if (b == null) return null;
    try {
      return await b.createBanner();
    } catch (e) {
      debugPrint('Banner failed: $e');
      return null;
    }
  }

  /// Call when the user leaves the results screen. Never blocks navigation.
  Future<bool> maybeShowInterstitial(AdPlacement placement, {required bool consent}) async {
    if (placement != AdPlacement.resultsExitInterstitial) return false;
    if (_shownThisSession >= maxInterstitialsPerSession) return false;
    final last = _lastShown;
    if (last != null && _clock().difference(last) < minInterstitialGap) return false;
    final b = await _ensure(consent);
    if (b == null) return false;
    try {
      await b.preloadInterstitial();
      final shown = await b.showInterstitialIfReady();
      if (shown) {
        _shownThisSession++;
        _lastShown = _clock();
      }
      return shown;
    } catch (e) {
      debugPrint('Interstitial failed: $e');
      return false;
    }
  }
}

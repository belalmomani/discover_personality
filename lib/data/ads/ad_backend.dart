import 'package:flutter/widgets.dart';

/// Abstraction over the ad network so the app (and tests) never touch the SDK directly.
abstract class AdBackend {
  Future<void> initialize({required bool testMode});

  /// Returns a ready-to-embed banner widget, or null when none is available.
  Future<Widget?> createBanner();

  Future<void> preloadInterstitial();

  /// Shows a preloaded interstitial. Returns true only if it was displayed.
  Future<bool> showInterstitialIfReady();
}

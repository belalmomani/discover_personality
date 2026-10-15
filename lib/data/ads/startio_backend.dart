import 'package:flutter/widgets.dart';
import 'package:startapp_sdk/startapp_sdk.dart';

import 'ad_backend.dart';

/// Start.io implementation using the official `startapp_sdk` Flutter plugin
/// (API as documented at https://pub.dev/packages/startapp_sdk).
/// Only created by [AdService] when ads are enabled AND the user consented.
class StartIoBackend implements AdBackend {
  StartAppSdk? _sdk;
  StartAppInterstitialAd? _interstitial;

  StartAppSdk get _s => _sdk ??= StartAppSdk();

  @override
  Future<void> initialize({required bool testMode}) async {
    _s.setTestAdsEnabled(testMode);
  }

  @override
  Future<Widget?> createBanner() async {
    final ad = await _s.loadBannerAd(StartAppBannerType.BANNER);
    return StartAppBanner(ad);
  }

  @override
  Future<void> preloadInterstitial() async {
    if (_interstitial != null) return;
    StartAppInterstitialAd? loaded;
    loaded = await _s.loadInterstitialAd(
      onAdHidden: () {
        loaded?.dispose();
      },
      onAdNotDisplayed: () {
        loaded?.dispose();
        if (identical(_interstitial, loaded)) _interstitial = null;
      },
    );
    _interstitial = loaded;
  }

  @override
  Future<bool> showInterstitialIfReady() async {
    final ad = _interstitial;
    if (ad == null) return false;
    final shown = await ad.show();
    if (shown) _interstitial = null; // one-time use, disposed in onAdHidden
    return shown;
  }
}

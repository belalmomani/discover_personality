import 'package:discover_personality/data/ads/ad_backend.dart';
import 'package:discover_personality/data/ads/ad_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBackend implements AdBackend {
  int inits = 0, banners = 0, preloads = 0, shows = 0;
  bool fail = false;

  @override
  Future<void> initialize({required bool testMode}) async {
    inits++;
    if (fail) throw Exception('init failed');
  }

  @override
  Future<Widget?> createBanner() async {
    banners++;
    if (fail) throw Exception('banner failed');
    return const SizedBox(key: Key('banner'));
  }

  @override
  Future<void> preloadInterstitial() async {
    preloads++;
    if (fail) throw Exception('load failed');
  }

  @override
  Future<bool> showInterstitialIfReady() async {
    shows++;
    return true;
  }
}

void main() {
  late FakeBackend backend;
  late int factoryCalls;
  late DateTime now;

  AdService make({required bool enabled}) {
    factoryCalls = 0;
    return AdService(
      enabled: enabled,
      testMode: true,
      backendFactory: () {
        factoryCalls++;
        return backend;
      },
      clock: () => now,
    );
  }

  setUp(() {
    backend = FakeBackend();
    now = DateTime(2026, 1, 1, 12);
  });

  test('ADS_ENABLED=false: nothing is created, initialised or loaded', () async {
    final s = make(enabled: false);
    expect(await s.bannerFor(AdPlacement.homeBanner, consent: true), isNull);
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isFalse);
    expect(factoryCalls, 0);
    expect(backend.inits + backend.banners + backend.preloads + backend.shows, 0);
  });

  test('enabled but no user consent: nothing is requested', () async {
    final s = make(enabled: true);
    expect(await s.bannerFor(AdPlacement.homeBanner, consent: false), isNull);
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: false), isFalse);
    expect(factoryCalls, 0);
  });

  test('assessment placement is always blocked, even when everything is enabled', () async {
    final s = make(enabled: true);
    expect(await s.bannerFor(AdPlacement.assessment, consent: true), isNull);
    expect(await s.maybeShowInterstitial(AdPlacement.assessment, consent: true), isFalse);
    expect(backend.banners + backend.preloads + backend.shows, 0);
  });

  test('banner is returned only for banner placements', () async {
    final s = make(enabled: true);
    expect(await s.bannerFor(AdPlacement.homeBanner, consent: true), isNotNull);
    expect(await s.bannerFor(AdPlacement.resultsBanner, consent: true), isNotNull);
    expect(await s.bannerFor(AdPlacement.resultsExitInterstitial, consent: true), isNull);
    expect(backend.inits, 1, reason: 'backend initialised once');
  });

  test('a failing ad network never throws and returns nothing', () async {
    backend.fail = true;
    final s = make(enabled: true);
    expect(await s.bannerFor(AdPlacement.homeBanner, consent: true), isNull);
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isFalse);
  });

  test('interstitial: only after results, min gap and per-session cap', () async {
    final s = make(enabled: true);
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isFalse, reason: 'too soon');
    now = now.add(const Duration(minutes: 4));
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isTrue);
    now = now.add(const Duration(minutes: 10));
    expect(await s.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: true), isFalse, reason: 'session cap');
    expect(backend.shows, 2);
  });
}

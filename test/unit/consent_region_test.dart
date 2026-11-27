import 'package:discover_personality/data/ads/consent_region.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EEA, UK and Switzerland require consent', () {
    for (final c in ['DE', 'fr', 'GB', 'CH', 'NO', 'ES']) {
      expect(adsConsentRequired(countryCode: c, timeZoneName: 'UTC'), isTrue, reason: c);
    }
  });

  test('regions outside them do not, when the time zone does not suggest Europe', () {
    for (final c in ['JO', 'SA', 'US', 'AE', 'IN']) {
      expect(adsConsentRequired(countryCode: c, timeZoneName: '+03'), isFalse, reason: c);
    }
  });

  test('a European time zone requires consent even with a non-European region', () {
    expect(adsConsentRequired(countryCode: 'SA', timeZoneName: 'CEST'), isTrue);
  });

  test('unknown region is treated as required', () {
    expect(adsConsentRequired(countryCode: null, timeZoneName: null), isTrue);
    expect(adsConsentRequired(countryCode: '', timeZoneName: ''), isTrue);
  });

  test('adsPermitted: free outside the consent regions, needs acceptance inside', () {
    const none = AppSettings();
    const accepted = AppSettings(adsConsent: true, adsConsentAsked: true);
    const declined = AppSettings(adsConsent: false, adsConsentAsked: true);
    expect(adsPermitted(none, consentRequired: false), isTrue);
    expect(adsPermitted(none, consentRequired: true), isFalse);
    expect(adsPermitted(declined, consentRequired: true), isFalse);
    expect(adsPermitted(accepted, consentRequired: true), isTrue);
  });
}

import 'dart:ui' as ui;

import '../repositories/local_store.dart';

/// EEA (EU + Iceland, Liechtenstein, Norway), United Kingdom and Switzerland: ads need prior consent there.
const Set<String> consentCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU',
  'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'GB', 'CH',
};

/// Time-zone abbreviations used in those countries. Deliberately over-inclusive: asking too often is safe, too rarely is not.
const Set<String> consentTimeZones = {'CET', 'CEST', 'WET', 'WEST', 'EET', 'EEST', 'BST', 'GMT', 'MET', 'MEST'};

/// Pure rule (testable): true when the ads-consent prompt must be shown / honoured.
/// Unknown region => required (conservative).
bool adsConsentRequired({String? countryCode, String? timeZoneName}) {
  final c = countryCode?.toUpperCase();
  if (c != null && consentCountries.contains(c)) return true;
  final tz = timeZoneName?.toUpperCase();
  if (tz != null && consentTimeZones.contains(tz)) return true;
  if ((c == null || c.isEmpty) && (tz == null || tz.isEmpty)) return true;
  return false;
}

/// Uses the device region and time zone only (no location permission, nothing leaves the device).
bool adsConsentRequiredNow() => adsConsentRequired(
      countryCode: ui.PlatformDispatcher.instance.locale.countryCode,
      timeZoneName: DateTime.now().timeZoneName,
    );

/// Ads may be requested: outside the consent regions always; inside them only after the user accepted.
bool adsPermitted(AppSettings s, {bool? consentRequired}) =>
    !(consentRequired ?? adsConsentRequiredNow()) || (s.adsConsentAsked && s.adsConsent);

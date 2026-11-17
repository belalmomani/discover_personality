/// Compile-time configuration. Values come from --dart-define (see .env.example).
/// Nothing secret is stored here: only the public Supabase anon key is ever used.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Master ads switch. Default: OFF.
  static const bool adsEnabled =
      bool.fromEnvironment('ADS_ENABLED', defaultValue: false);

  /// Start.io test mode. Default: ON. Set STARTIO_TEST_MODE=false only for production.
  static const bool startIoTestMode =
      bool.fromEnvironment('STARTIO_TEST_MODE', defaultValue: true);

  /// Optional AI proxy endpoint (never an AI provider key).
  static const String aiProxyUrl = String.fromEnvironment('AI_PROXY_URL');

  static const String _contactEmail = String.fromEnvironment('CONTACT_EMAIL');

  /// Public contact e-mail shown in the privacy policy. Set CONTACT_EMAIL (GitHub variable) before release.
  static String get privacyContactEmail =>
      _contactEmail.isNotEmpty ? _contactEmail : 'ADD_CONTACT_EMAIL_BEFORE_PUBLISHING';

  /// Bump when scoring rules change.
  static const int scoringVersion = 1;

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get aiConfigured => aiProxyUrl.isNotEmpty;
}

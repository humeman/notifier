/// Build-time settings, passed with `--dart-define-from-file` (see
/// `task app:config`, which writes config/notifier.json from terraform outputs).
///
/// When unset, the app runs on mock data — handy for UI work and tests.
abstract final class AppConfig {
  /// Base URL of the notifier function, without a trailing slash.
  static const apiUrl = String.fromEnvironment('NOTIFIER_URL');

  /// Key for the app endpoints (terraform's notifier_app_key output).
  static const appKey = String.fromEnvironment('NOTIFIER_APP_KEY');

  static bool get hasApi => apiUrl.isNotEmpty && appKey.isNotEmpty;
}

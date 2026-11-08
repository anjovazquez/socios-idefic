/// Compile-time configuration passed with `--dart-define`.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Public address of the web app, used in the card QR (VS-016). On the
  /// web it defaults to the current origin.
  static const publicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');

  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required',
      );
    }
  }
}

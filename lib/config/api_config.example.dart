/// ---------------------------------------------------------------------------
/// API CONFIGURATION
///
/// >>> PASTE YOUR GEMINI API KEY BELOW <<<
///
/// How to get a key:
///   1. Go to https://aistudio.google.com/apikey
///   2. Sign in with your Google account.
///   3. Click "Create API key" and copy it.
///   4. Replace PASTE_YOUR_GEMINI_API_KEY_HERE below with your key
///      (keep the quotes).
///
/// NOTE: Never commit a real API key to a public repository.
/// ---------------------------------------------------------------------------
class ApiConfig {
  /// Your Gemini API key.
  static const String geminiApiKey =
      'PASTE_YOUR_GEMINI_API_KEY_HERE';

  /// The Gemini model used for all AI features (Flash = fast + cheap).
  static const String geminiModel = 'gemini-2.5-flash';

  /// True if the key above has not been filled in yet.
  static bool get isKeyMissing =>
      geminiApiKey.isEmpty || geminiApiKey == 'PASTE_YOUR_GEMINI_API_KEY_HERE';
}

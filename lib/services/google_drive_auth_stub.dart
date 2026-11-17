class GoogleDriveAuth {
  static Future<String?> initialize(String clientId) async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static Future<String?> signIn() async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static Future<String> acquireToken({int minValidityMs = 0}) async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static bool isSignedIn() => false;

  static Future<void> signOut() async {}
}

class GoogleDriveAuth {
  static Future<String?> initialize(String clientId) async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static Future<String?> signIn() async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static Future<String> acquireToken() async {
    throw UnsupportedError('Google Drive web authentication is unavailable.');
  }

  static Future<void> signOut() async {}
}

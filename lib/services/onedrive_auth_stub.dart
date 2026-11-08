class OneDriveAuth {
  static Future<String?> initialize(String clientId, String redirectUri) async {
    throw UnsupportedError('OneDrive web authentication is unavailable.');
  }

  static Future<String?> signIn() async {
    throw UnsupportedError('OneDrive web authentication is unavailable.');
  }

  static Future<String> acquireToken() async {
    throw UnsupportedError('OneDrive web authentication is unavailable.');
  }

  static Future<void> signOut() async {}
}

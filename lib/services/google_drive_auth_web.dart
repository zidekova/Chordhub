import 'dart:js_interop';

@JS('window.chordHubGoogleAuth.initialize')
external JSPromise<JSString?> _initialize(JSString clientId);

@JS('window.chordHubGoogleAuth.signIn')
external JSPromise<JSString?> _signIn();

@JS('window.chordHubGoogleAuth.acquireToken')
external JSPromise<JSString> _acquireToken(JSNumber minValidityMs);

@JS('window.chordHubGoogleAuth.isSignedIn')
external JSBoolean _isSignedIn();

@JS('window.chordHubGoogleAuth.signOut')
external JSPromise<JSAny?> _signOut();

class GoogleDriveAuth {
  static Future<String?> initialize(String clientId) async {
    final username = await _initialize(clientId.toJS).toDart;
    return username?.toDart;
  }

  static Future<String?> signIn() async {
    final username = await _signIn().toDart;
    return username?.toDart;
  }

  /// [minValidityMs]: token sa obnoví, ak mu zostáva menej času než táto hodnota.
  static Future<String> acquireToken({int minValidityMs = 0}) async {
    return (await _acquireToken(minValidityMs.toJS).toDart).toDart;
  }

  static bool isSignedIn() => _isSignedIn().toDart;

  static Future<void> signOut() async {
    await _signOut().toDart;
  }
}

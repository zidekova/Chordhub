import 'dart:js_interop';

@JS('window.chordHubGoogleAuth.initialize')
external JSPromise<JSString?> _initialize(JSString clientId);

@JS('window.chordHubGoogleAuth.signIn')
external JSPromise<JSString?> _signIn();

@JS('window.chordHubGoogleAuth.acquireToken')
external JSPromise<JSString> _acquireToken();

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

  static Future<String> acquireToken() async {
    return (await _acquireToken().toDart).toDart;
  }

  static Future<void> signOut() async {
    await _signOut().toDart;
  }
}

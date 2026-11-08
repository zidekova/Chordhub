import 'dart:js_interop';

@JS('window.chordHubOneDriveAuth.initialize')
external JSPromise<JSString?> _initialize(
  JSString clientId,
  JSString redirectUri,
);

@JS('window.chordHubOneDriveAuth.signIn')
external JSPromise<JSString?> _signIn();

@JS('window.chordHubOneDriveAuth.acquireToken')
external JSPromise<JSString> _acquireToken();

@JS('window.chordHubOneDriveAuth.signOut')
external JSPromise<JSAny?> _signOut();

class OneDriveAuth {
  static Future<String?> initialize(String clientId, String redirectUri) async {
    final username = await _initialize(clientId.toJS, redirectUri.toJS).toDart;
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

import 'dart:js_interop';

@JS('hamnavaCanRecord')
external JSBoolean _canRecord();
@JS('hamnavaCanRecognize')
external JSBoolean _canRecognize();
@JS('hamnavaStart')
external JSPromise<JSBoolean> _start(
  JSString key,
  JSString locale,
  JSFunction callback,
);
@JS('hamnavaStop')
external JSPromise<JSString> _stop();
@JS('hamnavaCancel')
external void _cancel();
@JS('hamnavaPlay')
external JSPromise<JSBoolean> _play(JSString key);
@JS('hamnavaRemoveAudio')
external JSPromise<JSAny?> _remove(JSString key);
@JS('hamnavaSpeak')
external JSPromise<JSBoolean> _speak(JSString text, JSString locale);
@JS('hamnavaStopPlayback')
external void _stopPlayback();
@JS('hamnavaDownload')
external void _download(JSString text, JSString filename);
@JS('hamnavaDownloadAudio')
external JSPromise<JSBoolean> _downloadAudio(JSString key);
@JS('hamnavaDraft')
external JSString _draft(JSString key);
@JS('hamnavaSetDraft')
external void _setDraft(JSString key, JSString text);
@JS('hamnavaPickAudio')
external JSPromise<JSString> _pickAudio(JSString key);
@JS('hamnavaPickReceipt')
external JSPromise<JSString> _pickReceipt(JSBoolean camera);
@JS('hamnavaDownloadBinary')
external void _downloadBinary(JSString data, JSString filename, JSString mime);

class BrowserTools {
  static bool get canRecord => _canRecord().toDart;
  static bool get canRecognize => _canRecognize().toDart;
  static Future<bool> start(
    String key,
    String locale,
    void Function(String) event,
  ) async => (await _start(
    key.toJS,
    locale.toJS,
    ((JSString value) => event(value.toDart)).toJS,
  ).toDart).toDart;
  static Future<String> stop() async => (await _stop().toDart).toDart;
  static void cancel() => _cancel();
  static Future<bool> play(String key) async =>
      (await _play(key.toJS).toDart).toDart;
  static Future<void> removeAudio(String key) async {
    await _remove(key.toJS).toDart;
  }

  static Future<bool> speak(String text, String locale) async =>
      (await _speak(text.toJS, locale.toJS).toDart).toDart;
  static void stopPlayback() => _stopPlayback();
  static void download(String text, String filename) =>
      _download(text.toJS, filename.toJS);
  static Future<bool> downloadAudio(String key) async =>
      (await _downloadAudio(key.toJS).toDart).toDart;
  static String draft(String key) => _draft(key.toJS).toDart;
  static void setDraft(String key, String text) =>
      _setDraft(key.toJS, text.toJS);
  static Future<String> pickAudio(String key) async =>
      (await _pickAudio(key.toJS).toDart).toDart;
  static Future<String> pickReceipt({bool camera = false}) async =>
      (await _pickReceipt(camera.toJS).toDart).toDart;
  static void downloadBinary(String data, String filename, String mime) =>
      _downloadBinary(data.toJS, filename.toJS, mime.toJS);
}

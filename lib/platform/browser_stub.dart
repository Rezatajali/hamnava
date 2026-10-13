class BrowserTools {
  static bool get canRecord => false;
  static bool get canRecognize => false;
  static Future<bool> start(
    String key,
    String locale,
    void Function(String) event,
  ) async => false;
  static Future<String> stop() async => '';
  static void cancel() {}
  static Future<bool> play(String key) async => false;
  static Future<void> removeAudio(String key) async {}
  static Future<bool> speak(String text, String locale) async => false;
  static void stopPlayback() {}
  static void download(String text, String filename) {}
  static Future<bool> downloadAudio(String key) async => false;
  static String draft(String key) => '';
  static void setDraft(String key, String text) {}
  static Future<String> pickAudio(String key) async => '';
  static Future<String> pickReceipt({bool camera = false}) async => '';
  static void downloadBinary(String data, String filename, String mime) {}
}

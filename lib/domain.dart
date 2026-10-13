enum TransactionKind { income, expense }

class JournalEntry {
  const JournalEntry({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;
}

class MoneyTransaction {
  const MoneyTransaction({required this.cents, required this.kind,
    required this.category, required this.createdAt});
  final int cents;
  final TransactionKind kind;
  final String category;
  final DateTime createdAt;
}

/// Accept Persian/Arabic digits and a decimal separator, without floating-point money.
int? parseCents(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var normalized = input.trim();
  for (var i = 0; i < 10; i++) {
    normalized = normalized.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  normalized = normalized.replaceAll('٫', '.').replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final cents = int.parse(parts[0]) * 100 +
    (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return cents > 0 ? cents : null;
}

int monthTotal(Iterable<MoneyTransaction> items, DateTime month, TransactionKind kind) =>
  items.where((t) => t.kind == kind && t.createdAt.year == month.year &&
    t.createdAt.month == month.month).fold(0, (sum, t) => sum + t.cents);

/// Capability boundary: a provider must report availability for the actual device.
abstract interface class VoiceService {
  Future<bool> supportsTranscription(String locale);
  Future<String> transcribe(String locale);
  Future<bool> supportsPlayback(String locale);
  Future<void> speak(String text, String locale);
  Future<void> stop();
}

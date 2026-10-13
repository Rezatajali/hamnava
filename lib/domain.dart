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

class SpokenTransaction {
  const SpokenTransaction({required this.cents, required this.kind, required this.category});
  final int cents;
  final TransactionKind kind;
  final String category;
}

/// Suggestions only: users must review the amount before any write.
SpokenTransaction? suggestTransaction(String sentence) {
  final normalized = sentence.replaceAll('ي', 'ی').replaceAll('ك', 'ک');
  if (RegExp(r'دلار|تومان|ریال|پوند').hasMatch(normalized)) return null;
  final numeric = RegExp(r'[0-9۰-۹٠-٩]+(?:[.,٫][0-9۰-۹٠-٩]+)?').firstMatch(normalized);
  int? cents = numeric == null ? null : parseCents(numeric.group(0)!);
  if (numeric != null && cents == null) return null;
  if (cents == null) {
    const values = <String, int>{'یک':1,'دو':2,'سه':3,'چهار':4,'پنج':5,'شش':6,'هفت':7,'هشت':8,'نه':9,
      'ده':10,'یازده':11,'دوازده':12,'سیزده':13,'چهارده':14,'پانزده':15,'شانزده':16,'هفده':17,'هجده':18,'نوزده':19,
      'بیست':20,'سی':30,'چهل':40,'پنجاه':50,'شصت':60,'هفتاد':70,'هشتاد':80,'نود':90,
      'صد':100,'دویست':200,'سیصد':300,'چهارصد':400,'پانصد':500,'ششصد':600,'هفتصد':700,'هشتصد':800,'نهصد':900};
    var total = 0, segment = 0;
    var started = false;
    for (final word in normalized.split(RegExp(r'\s+'))) {
      if (values.containsKey(word)) { segment += values[word]!; started = true; }
      else if (word == 'هزار') { total += (segment == 0 ? 1 : segment) * 1000; segment = 0; started = true; }
      else if (started && word != 'و') break;
    }
    if (started && total + segment > 0) cents = (total + segment) * 100;
  }
  if (cents == null) return null;
  final income = RegExp(r'حقوق|درآمد|دریافت|واریز').hasMatch(normalized) && !RegExp(r'خرج|هزینه|پرداخت').hasMatch(normalized);
  String category = 'سایر';
  for (final entry in <String,String>{'ناهار|شام|صبحانه|غذا|قهوه':'غذا','اتوبوس|مترو|تاکسی|بنزین':'رفت‌وآمد',
    'خرید|لباس':'خرید','اجاره|خانه|قبض':'خانه','حقوق':'حقوق'}.entries) {
    if (RegExp(entry.key).hasMatch(normalized)) { category = entry.value; break; }
  }
  return SpokenTransaction(cents: cents, kind: income ? TransactionKind.income : TransactionKind.expense, category: category);
}

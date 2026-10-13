import 'package:flutter_test/flutter_test.dart';
import 'package:hamna/domain.dart';

void main() {
  test('Persian and Arabic amounts preserve cents', () {
    expect(parseCents('۱۲٫۵۰'), 1250);
    expect(parseCents('١٢,٥'), 1250);
    expect(parseCents('0.01'), 1);
    for (final invalid in ['0', '-2', '1.234', '1,000.00', 'ناهار']) {
      expect(parseCents(invalid), isNull);
    }
  });
  test('Monthly totals exclude different months, years and transaction kinds', () {
    MoneyTransaction item(int cents, int year, int month, TransactionKind kind) =>
      MoneyTransaction(cents: cents, kind: kind, category: 'غذا', createdAt: DateTime(year, month));
    final items = [item(1250, 2026, 10, TransactionKind.expense),
      item(1, 2026, 10, TransactionKind.expense),
      item(9000, 2026, 9, TransactionKind.expense),
      item(9000, 2025, 10, TransactionKind.expense),
      item(5000, 2026, 10, TransactionKind.income)];
    expect(monthTotal(items, DateTime(2026, 10), TransactionKind.expense), 1251);
    expect(monthTotal(items, DateTime(2026, 10), TransactionKind.income), 5000);
  });
}

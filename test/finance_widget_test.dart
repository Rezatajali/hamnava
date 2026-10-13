import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamnava/finance_widgets.dart';
import 'package:hamnava/repository.dart';
import 'package:hamnava/theme.dart';
import 'package:hamnava/screens/finance.dart';

class _NoDatabase extends Fake implements FirebaseFirestore {}

Widget host(
  Widget child, {
  double scale = 1,
  bool scroll = true,
}) => MaterialApp(
  theme: hamnavaTheme(),
  locale: const Locale('fa'),
  supportedLocales: const [Locale('fa')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: scroll ? SingleChildScrollView(child: child) : child),
);

void main() {
  final items = [
    FinanceItem(
      id: 'lunch',
      category: 'غذا',
      cents: 1250,
      income: false,
      date: DateTime(2026, 10, 1),
      note: 'ناهار',
    ),
    FinanceItem(
      id: 'coffee',
      category: 'غذا',
      cents: 250,
      income: false,
      date: DateTime(2026, 10, 2),
      note: 'قهوه',
    ),
    FinanceItem(
      id: 'bus',
      category: 'رفت‌وآمد',
      cents: 500,
      income: false,
      date: DateTime(2026, 10, 2),
      note: '',
    ),
    FinanceItem(
      id: 'salary',
      category: 'حقوق',
      cents: 10000,
      income: true,
      date: DateTime(2026, 10, 1),
      note: '',
    ),
  ];

  testWidgets(
    'category chart totals expenses once; details still allow edit and delete',
    (tester) async {
      String? edited, deleted;
      await tester.pumpWidget(
        host(
          FinanceOverview(
            items: items,
            onEdit: (id) => edited = id,
            onDelete: (id) => deleted = id,
          ),
        ),
      );
      expect(find.text('80.00 €'), findsOneWidget);
      expect(find.text('20.00 €'), findsOneWidget);
      expect(find.text('15.00 €'), findsOneWidget);
      expect(find.text('75٪'), findsOneWidget);
      expect(find.text('غذا'), findsOneWidget);
      expect(find.text('ناهار'), findsNothing);
      await tester.ensureVisible(find.text('ریز تراکنش‌ها'));
      await tester.tap(find.text('ریز تراکنش‌ها'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ناهار'));
      await tester.tap(find.text('ناهار'));
      expect(edited, 'lunch');
      await tester.tap(find.byTooltip('گزینه‌های تراکنش').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(deleted, 'lunch');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finance chart works at mobile width with double-sized text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        Padding(
          padding: const EdgeInsets.all(24),
          child: FinanceOverview(
            items: items,
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
        scale: 2,
      ),
    );
    await tester.ensureVisible(find.text('ریز تراکنش‌ها'));
    await tester.tap(find.text('ریز تراکنش‌ها'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ناهار'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('income-only and empty months have no invalid percentage chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FinanceOverview(items: [items.last], onEdit: (_) {}, onDelete: (_) {}),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(
      host(FinanceOverview(items: const [], onEdit: (_) {}, onDelete: (_) {})),
    );
    expect(find.text('این ماه هنوز تراکنشی نداری.'), findsOneWidget);
    expect(find.text('ریز تراکنش‌ها'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual editor fits a phone with double-sized text and validates before writing', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(TransactionEditor(
      repo: PersonalRepository('test', database: _NoDatabase()), initialDate: DateTime(2026, 10)), scale: 2, scroll: false));
    await tester.ensureVisible(find.text('تأیید اطلاعات و ذخیره'));
    await tester.tap(find.text('تأیید اطلاعات و ذخیره'));
    await tester.pump();
    expect(find.text('مبلغ مثبت با حداکثر دو رقم اعشار و توضیح تا ۲۰۰۰ کاراکتر وارد کن.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual finance entry stays primary; optional sentence produces a reviewed proposal',
    (tester) async {
      await tester.pumpWidget(
        host(
          TransactionEditor(
            repo: PersonalRepository('test', database: _NoDatabase()),
            initialDate: DateTime(2026, 10),
          ),
          scroll: false,
        ),
      );
      expect(find.widgetWithText(TextField, 'مبلغ'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'جمله مالی'), findsNothing);
      await tester.ensureVisible(find.text('ورود با جمله یا صدا (اختیاری)'));
      await tester.tap(find.text('ورود با جمله یا صدا (اختیاری)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'جمله مالی'),
        'دوازده یورو برای ناهار خرج کردم',
      );
      await tester.ensureVisible(find.text('پیشنهاد مبلغ و دسته'));
      await tester.tap(find.text('پیشنهاد مبلغ و دسته'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'مبلغ'))
            .controller!
            .text,
        '12.00',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'غذا'))
            .selected,
        isTrue,
      );
      expect(
        find.text(
          'این فقط یک پیشنهاد است؛ مبلغ، نوع و دسته را قبل از ذخیره بررسی کن.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

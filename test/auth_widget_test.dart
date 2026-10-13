import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamnava/screens/auth.dart';

void main() {
  testWidgets('invalid login remains in the form without a Firebase request', (tester) async {
    await tester.pumpWidget(const MaterialApp(locale: Locale('fa'), supportedLocales: [Locale('fa')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates, home: AuthScreen()));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'ورود'));
    await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
    await tester.pump();
    expect(find.text('ایمیل معتبر وارد کن.'), findsOneWidget);
    expect(find.text('حداقل شش کاراکتر'), findsOneWidget);
    await tester.ensureVisible(find.text('حساب ندارم؛ ثبت‌نام'));
    await tester.tap(find.text('حساب ندارم؛ ثبت‌نام'));
    await tester.pump();
    expect(find.text('حساب دارم؛ ورود'), findsOneWidget);
  });
}

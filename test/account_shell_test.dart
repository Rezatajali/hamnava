import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamnava/app_shell.dart';

void main() {
  testWidgets(
    'private dialogs are discarded when persistent auth changes account',
    (tester) async {
      await tester.pumpWidget(
        HamnavaShell(
          accountId: 'alice',
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const AlertDialog(content: Text('رسید خصوصی آلیس')),
                ),
                child: const Text('باز کردن رسید'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('باز کردن رسید'));
      await tester.pumpAndSettle();
      expect(find.text('رسید خصوصی آلیس'), findsOneWidget);
      await tester.pumpWidget(
        const HamnavaShell(
          accountId: 'bob',
          home: Scaffold(body: Text('حساب باب')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('رسید خصوصی آلیس'), findsNothing);
      expect(find.text('حساب باب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

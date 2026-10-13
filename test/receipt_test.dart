import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hamnava/receipts.dart';
import 'package:hamnava/receipt_widgets.dart';
import 'package:hamnava/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ReceiptPhoto photo(String id) {
    final bytes = File('test/fixtures/receipt.jpg').readAsBytesSync();
    return ReceiptPhoto(
      id: id,
      name: 'رسید تست',
      originalType: 'image/jpeg',
      image: 'data:image/jpeg;base64,${base64Encode(bytes)}',
      bytes: bytes.length,
      width: 64,
      height: 128,
      createdAt: DateTime(2026, 10, 13),
    );
  }

  test(
    'receipt PDF contains every selected image on its own page with embedded font',
    () async {
      final bytes = await receiptPdf([photo('one'), photo('two')]);
      final content = latin1.decode(bytes);
      expect(content.startsWith('%PDF-'), isTrue);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(content).length, 2);
      expect(
        RegExp(r'/Subtype\s*/Image\b').allMatches(content).length,
        greaterThanOrEqualTo(1),
      );
      expect(content, contains('/FontFile2'));
    },
  );
  test('receipt PDF rejects an empty selection', () async {
    await expectLater(receiptPdf([]), throwsArgumentError);
  });
  testWidgets(
    'receipt preview and removal remain accessible on a phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var removed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: hamnavaTheme(),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ReceiptTile(
                  photo: photo('test'),
                  onRemove: () => removed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('دیدن'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('بستن عکس'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('حذف رسید'));
      expect(removed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

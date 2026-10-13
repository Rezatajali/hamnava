import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamnava/journal_widgets.dart';
import 'package:hamnava/theme.dart';
import 'package:hamnava/voice_composer.dart';

void main() {
  test(
    'journal entries are grouped by local day including pending timestamps',
    () {
      final records = <DateTime?>[
        DateTime(2026, 10, 13, 23, 59),
        DateTime(2026, 10, 13, 1),
        DateTime(2026, 10, 12, 23, 59),
        null,
      ];
      final days = groupJournalDays(records, (date) => date);
      expect(days.keys, [DateTime(2026, 10, 13), DateTime(2026, 10, 12), null]);
      expect(days[DateTime(2026, 10, 13)]!.length, 2);
      expect(days[null], [null]);
    },
  );
  testWidgets(
    'ten notes occupy one collapsed daily folder; all remain accessible',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
            body: ListView(
              children: [
                JournalDayFolder(
                  day: DateTime(2026, 10, 13),
                  count: 10,
                  audioCount: 7,
                  children: List.generate(10, (i) => Text('یادداشت شماره $i')),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('10 یادداشت · 7 فایل صوتی'), findsOneWidget);
      expect(find.text('یادداشت شماره 0'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('یادداشت شماره 0'), findsOneWidget);
      expect(find.text('یادداشت شماره 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'voice modes distinguish a recorded file from dictation on a small screen',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                child: VoiceComposer(
                  controller: controller,
                  audioKey: 'alice/test',
                  onAudio: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('در این حالت فایل صدا ضبط می‌شود؛ تبدیل به متن جداست.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'گفتار به متن'));
      await tester.pump();
      expect(
        find.text('در این حالت متن ثبت می‌شود؛ فایل صوتی ضبط نمی‌شود.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

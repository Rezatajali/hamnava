import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';

/// A new account gets a new navigator: private dialogs must not survive logout
/// or a sign-in change propagated from another tab by local auth persistence.
class HamnavaShell extends StatelessWidget {
  const HamnavaShell({super.key, required this.home, this.accountId});
  final Widget home;
  final String? accountId;
  @override
  Widget build(BuildContext context) => MaterialApp(
    key: ValueKey(accountId),
    debugShowCheckedModeBanner: false,
    title: 'هم‌نوا | Hamnava',
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: hamnavaTheme(),
    home: home,
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'theme.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  } catch (_) { startupError = 'اتصال اولیه برقرار نشد. اتصال اینترنت را بررسی کن و صفحه را دوباره باز کن.'; }
  runApp(HamnavaApp(startupError: startupError));
}

class HamnavaApp extends StatelessWidget {
  const HamnavaApp({super.key, this.startupError});
  final String? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'هم‌نوا | Hamnava',
    locale: const Locale('fa'), supportedLocales: const [Locale('fa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: hamnavaTheme(),
    home: startupError != null ? Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(32), child: Text(startupError!)))) :
      StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snapshot.data;
        return user == null ? const AuthScreen() : HomeScreen(key: ValueKey(user.uid), user: user);
      }),
  );
}

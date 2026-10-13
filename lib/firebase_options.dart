import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      throw UnsupportedError('Native targets need flutterfire configure first.');
    }
    return web;
  }

  // Public client configuration supplied by the project owner. Not an admin credential.
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyC7QcPfxaKfjKF7qgZDAMSQq9gdgY4uocY',
    appId: '1:54019379988:web:a453057a950ded0f482801',
    messagingSenderId: '54019379988',
    projectId: 'hamnava-67a58',
    authDomain: 'hamnava-67a58.firebaseapp.com',
    storageBucket: 'hamnava-67a58.firebasestorage.app',
  );
}

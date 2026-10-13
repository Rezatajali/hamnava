import 'package:flutter/material.dart';

ThemeData hamnavaTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xfff6f2e9),
  fontFamily: 'Vazirmatn',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 18, height: 1.8),
    bodyMedium: TextStyle(fontSize: 17, height: 1.8),
    bodySmall: TextStyle(fontSize: 14, height: 1.7),
    titleLarge: TextStyle(
      fontSize: 23,
      height: 1.5,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 1.6,
      fontWeight: FontWeight.bold,
    ),
    labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    labelMedium: TextStyle(fontSize: 15),
    labelSmall: TextStyle(fontSize: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff244f43),
    surface: const Color(0xfffbf9f3),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
);

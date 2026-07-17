import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1A73E8);
  static const _surfaceColor = Color(0xFF121212);
  static const _backgroundColor = Color(0xFF0D0D0D);
  static const _errorColor = Color(0xFFCF6679);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _onSurface = Color(0xFFE0E0E0);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primaryColor,
          surface: _surfaceColor,
          error: _errorColor,
          onPrimary: _onPrimary,
          onSurface: _onSurface,
        ),
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surfaceColor,
          foregroundColor: _onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: _surfaceColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
          foregroundColor: _onPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 2),
          ),
        ),
      );
}

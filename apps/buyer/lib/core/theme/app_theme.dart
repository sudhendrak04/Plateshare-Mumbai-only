import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _buyerSeed = Color(0xFFE65100);

  static ThemeData get buyer => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _buyerSeed),
      );
}

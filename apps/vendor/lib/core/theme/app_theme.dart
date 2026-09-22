import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _vendorSeed = Color(0xFF1B5E20);

  static ThemeData get vendor => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _vendorSeed),
      );
}

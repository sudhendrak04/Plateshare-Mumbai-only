import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

void main() => runApp(const PlateShareVendorApp());

const String _version =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

class PlateShareVendorApp extends StatelessWidget {
  const PlateShareVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plate Share — Vendor',
      theme: AppTheme.vendor,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 72),
              SizedBox(height: 16),
              Text('Plate Share', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Vendor', style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              Text('Version $_version'),
              SizedBox(height: 8),
              Text('Stage 1 scaffold — screens arrive in later stages.'),
            ],
          ),
        ),
      ),
    );
  }
}

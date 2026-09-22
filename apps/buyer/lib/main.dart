import 'package:flutter/material.dart';

void main() => runApp(const PlateShareBuyerApp());

const String _version =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

class PlateShareBuyerApp extends StatelessWidget {
  const PlateShareBuyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plate Share — Buyer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE65100)),
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lunch_dining, size: 72),
              SizedBox(height: 16),
              Text('Plate Share', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Buyer', style: TextStyle(fontSize: 18)),
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

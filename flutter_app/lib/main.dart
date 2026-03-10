import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/analysis/screens/analysis_screen.dart';

void main() {
  runApp(const ProviderScope(child: FakeScopeApp()));
}

class FakeScopeApp extends StatelessWidget {
  const FakeScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FakeScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1208)),
      ),
      home: const AnalysisScreen(),
    );
  }
}

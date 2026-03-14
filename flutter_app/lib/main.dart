import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/analysis/screens/analysis_screen.dart';
import 'features/analysis/screens/history_screen.dart';
import 'features/feed/screens/feed_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1208)),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _screens = const [
    FeedScreen(),
    AnalysisScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF1A1208),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Лента'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Проверить'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'История'),
        ],
      ),
    );
  }
}

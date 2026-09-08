import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/ui_text.dart';
import 'home_screen.dart';
import 'flashcard_screen.dart';
import 'verb_screen.dart';
import 'stats_screen.dart';
import 'account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    FlashcardScreen(),
    VerbScreen(),
    StatsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: uiText(lang, ar: 'الرئيسية', es: 'Inicio', other: 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style),
            label: uiText(lang, ar: 'بطاقات', es: 'Cartas', other: 'Cards'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.translate_outlined),
            selectedIcon: const Icon(Icons.translate),
            label: uiText(lang, ar: 'الأفعال', es: 'Verbos', other: 'Verbs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: uiText(
              lang,
              ar: 'إحصائيات',
              es: 'Estadísticas',
              other: 'Stats',
            ),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: uiText(lang, ar: 'حساب', es: 'Cuenta', other: 'Account'),
          ),
        ],
      ),
    );
  }
}

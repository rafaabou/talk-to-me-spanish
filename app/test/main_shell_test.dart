import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/screens/account_screen.dart';
import 'package:talk_to_me_spanish/screens/flashcard_screen.dart';
import 'package:talk_to_me_spanish/screens/home_screen.dart';
import 'package:talk_to_me_spanish/screens/main_shell.dart';
import 'package:talk_to_me_spanish/screens/stats_screen.dart';
import 'package:talk_to_me_spanish/screens/verb_screen.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'ui_lang': 'en',
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('only the home tab is built on start', (tester) async {
    await pumpShell(tester);

    // An IndexedStack builds every child, which used to parse the 2.5 MB verb
    // file, the 647 KB content index and all 73 lessons before first paint.
    // `skipOffstage: false` is required because IndexedStack keeps the
    // unselected children in the tree but marks them offstage.
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(VerbScreen, skipOffstage: false), findsNothing);
    expect(find.byType(FlashcardScreen, skipOffstage: false), findsNothing);
    expect(find.byType(StatsScreen, skipOffstage: false), findsNothing);
    expect(find.byType(AccountScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each tab is built the first time it is opened', (tester) async {
    await pumpShell(tester);

    // Five evenly spaced destinations along the bottom navigation bar.
    for (var tab = 0; tab < 5; tab++) {
      await tester.tapAt(Offset(720 / 10 * (2 * tab + 1), 1600 - 45));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: 'opening tab $tab threw');
    }

    // Visited tabs stay alive, so their state survives switching.
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(FlashcardScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(VerbScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(StatsScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(AccountScreen, skipOffstage: false), findsOneWidget);
  });
}

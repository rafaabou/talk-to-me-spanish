import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/screens/quiz_screen.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/services/course_repository.dart';

void main() {
  // Poll until [cond] is true instead of relying on a fixed number of pumps -
  // fixed loops are flaky on loaded CI runners.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() cond, {
    int maxPumps = 300,
  }) async {
    for (var i = 0; i < maxPumps && !cond(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(cond(), isTrue, reason: 'condition not met after $maxPumps pumps');
  }

  testWidgets(
    'quiz_completion_persists_best_score_matching_displayed_result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final levels = await CourseRepository.instance.loadLevels();
        for (final m in levels['A1']!.lessons) {
          await CourseRepository.instance.tryLoadLesson(m['id'] as String);
        }
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(home: QuizScreen(levelId: 'A1')),
        ),
      );

      // Questions loaded -> first set of option buttons rendered.
      await pumpUntil(tester, () => tester.any(find.byType(OutlinedButton)));

      // Answer every question: the A1 quiz length depends on how many
      // multiple-choice / fill-blank / listening drills the lessons contain, so
      // the loop stops when the result screen appears instead of assuming 10.
      final result = find.textContaining('Best score:');
      for (var i = 0; i < 60 && tester.any(result) == false; i++) {
        final option = find.byType(OutlinedButton);
        if (tester.any(option) == false) break;
        await tester.tap(option.first);
        final next = find.widgetWithText(FilledButton, 'Next');
        await pumpUntil(tester, () => tester.any(next));
        if (tester.any(result)) break;
        await tester.tap(next);
        await pumpUntil(
          tester,
          () => tester.any(next) == false && tester.any(find.byType(Text)),
        );
      }

      // Result screen reached.
      await pumpUntil(
        tester,
        () => tester.any(find.textContaining('Best score:')),
      );

      // Let async SharedPreferences write settle.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      final scoreFinder = find.textContaining(RegExp(r'\d+/10'));
      expect(scoreFinder, findsWidgets, reason: 'score text not found');
      final scoreText = tester.widget<Text>(scoreFinder.first).data!;
      final score = int.parse(scoreText.split('/').first);
      expect(scoreText.endsWith('/10'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('quiz_best_A1'), score);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

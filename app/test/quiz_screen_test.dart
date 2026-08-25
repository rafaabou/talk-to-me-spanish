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

  testWidgets('quiz_completion_persists_best_score_matching_displayed_result', (
    tester,
  ) async {
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

    // Answer all 10 questions: tap an option, wait for Next, tap Next.
    // After every Next the Next button disappears (new unanswered question
    // or result screen), which is what makes this loop deterministic.
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byType(OutlinedButton).first);
      final next = find.widgetWithText(FilledButton, 'Next');
      await pumpUntil(tester, () => tester.any(next));
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

    final scoreFinder = find.textContaining(RegExp(r'^\d+/10$'));
    final scoreText = tester.widget<Text>(scoreFinder.first).data!;
    final score = int.parse(scoreText.split('/').first);
    expect(scoreText.endsWith('/10'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('quiz_best_A1'), score);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

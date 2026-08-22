import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/screens/quiz_screen.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/services/course_repository.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitForQuestions(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (!tester.any(find.byType(OutlinedButton))) {
      fail('questions never loaded');
    }
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
    await waitForQuestions(tester);

    for (var i = 0; i < 10; i++) {
      final option = find.byType(OutlinedButton).first;
      await tester.tap(option);
      await settle(tester);
      final next = find.widgetWithText(FilledButton, 'Next');
      expect(next, findsOneWidget);
      await tester.tap(next);
      await settle(tester);
    }

    final scoreFinder = find.textContaining(RegExp(r'^\d+/10$'));
    final scoreText = tester.widget<Text>(scoreFinder.first).data!;
    final score = int.parse(scoreText.split('/').first);
    expect(scoreText.endsWith('/10'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('quiz_best_A1'), score);

    final bestFinder = find.textContaining('Best score:');
    expect(bestFinder, findsOneWidget);
  });
}

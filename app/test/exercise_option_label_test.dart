import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/screens/lesson_exercise_tile.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The real A1-01 drill the report came from: "¿Qué palabra significa 'the
  // alphabet'?". The answer is the Spanish `el alfabeto`, so the options have
  // to lead with the course language.
  final exercise = Exercise.fromJson({
    'type': 'multiple_choice',
    'prompt': {
      'es': "¿Qué palabra significa 'the alphabet'?",
      'en': "Which word means 'the alphabet'?",
      'ar': "أي كلمة تعني 'الأبجدية'؟",
    },
    'options': [
      {'es': 'el alfabeto', 'en': 'the alphabet', 'ar': 'الأبجدية'},
      {'es': 'hablar', 'en': 'to speak', 'ar': 'يتكلم'},
      {'es': 'la palabra', 'en': 'the word', 'ar': 'الكلمة'},
    ],
    'answer': 'el alfabeto',
    'explanation': {
      'es': "'el alfabeto' significa 'the alphabet'.",
      'en': "'el alfabeto' means 'the alphabet'.",
      'ar': "تعني 'el alfabeto' 'الأبجدية'.",
    },
  });

  Future<void> pumpOption(WidgetTester tester, String uiLang) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'ui_lang': uiLang});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: ExerciseTile(
              'A1-01',
              0,
              exercise,
              uiLang,
              isDone: false,
              onToggleDone: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an English interface shows the Spanish word, once', (
    tester,
  ) async {
    await pumpOption(tester, 'en');

    // The word being tested, plus each translation exactly once. The old code
    // used `o.tr(lang)`, so an English interface printed "the alphabet" as
    // the primary and again on the English line, and never showed
    // "el alfabeto" at all.
    expect(find.text('el alfabeto'), findsOneWidget);
    expect(find.text('the alphabet'), findsOneWidget);
    expect(find.text('الأبجدية'), findsOneWidget);
    expect(find.text('hablar'), findsOneWidget);
    expect(find.text('to speak'), findsOneWidget);
    expect(find.text('يتكلم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Arabic interface still leads with the Spanish word', (
    tester,
  ) async {
    await pumpOption(tester, 'ar');

    expect(find.text('el alfabeto'), findsOneWidget);
    expect(find.text('the alphabet'), findsOneWidget);
    expect(find.text('الأبجدية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Spanish interface does not repeat the word', (tester) async {
    await pumpOption(tester, 'es');

    expect(find.text('el alfabeto'), findsOneWidget);
    expect(find.text('the alphabet'), findsOneWidget);
    expect(find.text('الأبجدية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an option identical in every language is shown once', (
    tester,
  ) async {
    // Hundreds of options in the course data repeat the same text in all
    // three languages, e.g. {'es': '24', 'en': '24', 'ar': '24'}.
    final same = Exercise.fromJson({
      'type': 'multiple_choice',
      'prompt': {'es': '¿Cuántas letras?', 'en': 'How many letters?', 'ar': ''},
      'options': [
        {'es': '24', 'en': '24', 'ar': '24'},
      ],
      'answer': '24',
      'explanation': {'es': '', 'en': '', 'ar': ''},
    });

    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'ui_lang': 'en'});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: ExerciseTile(
              'A1-01',
              0,
              same,
              'en',
              isDone: false,
              onToggleDone: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('24'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

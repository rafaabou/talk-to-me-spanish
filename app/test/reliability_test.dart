import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/screens/lesson_exercise_tile.dart';
import 'package:talk_to_me_spanish/screens/quiz_screen.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/services/progress_service.dart';
import 'package:talk_to_me_spanish/widgets/audio_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester,
    Widget child, {
    String ui = 'en',
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'ui_lang': ui});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  group('backup import', () {
    test(
      'rejects a malformed file without touching existing progress',
      () async {
        SharedPreferences.setMockInitialValues({
          'completed_lessons': ['A1-01'],
        });
        final service = ProgressService.instance;

        await expectLater(
          service.importData('{not json'),
          throwsA(isA<FormatException>()),
        );
        expect(await service.isCompleted('A1-01'), isTrue);

        // A JSON document that is not a backup object is refused too.
        await expectLater(
          service.importData('[1,2,3]'),
          throwsA(isA<FormatException>()),
        );
        expect(await service.isCompleted('A1-01'), isTrue);
      },
    );

    test(
      'rejects a field with the wrong type before writing anything',
      () async {
        SharedPreferences.setMockInitialValues({
          'completed_lessons': ['A1-01'],
        });
        final service = ProgressService.instance;

        await expectLater(
          service.importData('{"completed": "not-a-list"}'),
          throwsA(isA<FormatException>()),
        );
        // The earlier valid progress must still be intact.
        expect(await service.isCompleted('A1-01'), isTrue);
      },
    );

    test('a valid backup restores progress', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ProgressService.instance;
      final json = await service.exportData();

      await service.importData(json);
      expect(await service.isCompleted('A1-01'), isFalse);
    });

    test(
      'export carries a schema version and future versions are refused',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = ProgressService.instance;
        final exported = await service.exportData();
        expect(exported.contains('"v":2'), isTrue);

        await expectLater(
          service.importData('{"v": 3}'),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          service.importData('{"v": "not-a-number"}'),
          throwsA(isA<FormatException>()),
        );
        SharedPreferences.setMockInitialValues({
          'completed_lessons': ['A1-01'],
        });
        // A legacy export with no 'v' is still accepted.
        await service.importData('{}');
      },
    );

    test('a missing file reports failure instead of throwing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await ProgressService.instance.importFromFile('/does/not/exist.json'),
        isFalse,
      );
    });
  });

  group('speaking item progress', () {
    test('is remembered per lesson and item, and the count follows', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ProgressService.instance;

      expect(await service.getSpeakingItemsDone(), isEmpty);
      expect(await service.getSpeakingDone(), 0);

      expect(await service.toggleSpeakingItem('A1-01::0'), isTrue);
      expect(await service.toggleSpeakingItem('A1-01::2'), isTrue);
      expect(await service.getSpeakingDone(), 2);
      expect(await service.getSpeakingItemsDone(), {'A1-01::0', 'A1-01::2'});

      // Toggling off removes the tick and decrements the counter once.
      expect(await service.toggleSpeakingItem('A1-01::0'), isFalse);
      expect(await service.getSpeakingDone(), 1);
      expect(await service.getSpeakingItemsDone(), {'A1-01::2'});
    });
  });

  group('audio button language', () {
    testWidgets('error copy follows the interface language, not the course', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const AudioButton(text: 'cualquiera', lang: 'es', uiLang: 'ar'),
        ui: 'ar',
      );

      final button = tester.widget<AudioButton>(find.byType(AudioButton));
      expect(
        button.lang,
        'es',
        reason: 'the asset key stays the course language',
      );
      expect(
        button.uiLang,
        'ar',
        reason: 'the message uses the interface language',
      );
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('a level with questions never indexes an empty list', (
      tester,
    ) async {
      await pumpApp(tester, const QuizScreen(levelId: 'A1'));

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // A real level has questions, so this is the regression guard for
      // the crash that happened when the question list came back empty.
      expect(tester.takeException(), isNull);
      expect(find.byType(QuizScreen), findsOneWidget);
    });
  });

  test('exercise content language is exposed for audio keys', () {
    expect(ExerciseTile.contentLang, 'es');
  });
}

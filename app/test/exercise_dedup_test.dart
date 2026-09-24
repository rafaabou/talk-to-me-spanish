import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/services/exercise_dedup.dart';

Exercise _ex(
  String type,
  String prompt,
  String answer, [
  List<String> options = const [],
  String promptEn = 'prompt-en',
]) => Exercise(
  type,
  TriText(prompt, promptEn, 'prompt-ar'),
  options.map((o) => TriText(o, 'opt-en', 'opt-ar')).toList(),
  answer,
  const [],
  null,
  TriText('', '', ''),
);

void main() {
  group('normalizeForDedup', () {
    test('strips case, accents and punctuation', () {
      expect(normalizeForDedup('  Buenos días!  '), 'buenos dias');
      expect(normalizeForDedup('¿Cómo estás?'), 'como estas');
      expect(normalizeForDedup('A, B, C...'), 'a b c');
      expect(normalizeForDedup('canción'), 'cancion');
    });
  });

  group('dedupeExercises', () {
    test('collapses an exact duplicate', () {
      final list = [
        _ex('translation', 'Traduce: Buenos días', 'Good morning'),
        _ex('translation', 'Traduce: Buenos días', 'Good morning'),
      ];
      final out = dedupeExercises(list, 'es');
      expect(out, hasLength(1));
      expect(out.first.key, 0);
    });

    test('collapses a duplicate that differs only in formatting', () {
      final list = [
        _ex('translation', 'Traduce: Buenos días!', 'Good morning'),
        _ex('translation', 'traduce: buenos días', 'Good morning.'),
      ];
      expect(dedupeExercises(list, 'es'), hasLength(1));
    });

    test('collapses the same MCQ question reworded', () {
      final list = [
        _ex('multiple_choice', '¿Cuál es la traducción?', 'Buenos días', [
          'Buenos días',
          'Buenas noches',
        ]),
        _ex('multiple_choice', 'Elige la opción correcta:', 'Buenos días', [
          'Buenas noches',
          'Buenos días',
        ]),
      ];
      expect(dedupeExercises(list, 'es'), hasLength(1));
    });

    test('keeps an MCQ with the same answer but different options', () {
      final list = [
        _ex('multiple_choice', '¿Cuál es la traducción?', 'Buenos días', [
          'Buenos días',
          'Buenas noches',
        ]),
        _ex('multiple_choice', '¿Cuál es la traducción?', 'Buenos días', [
          'Buenos días',
          'Hasta luego',
        ]),
      ];
      expect(dedupeExercises(list, 'es'), hasLength(2));
    });

    test('keeps different exercise types on the same sentence', () {
      final list = [
        _ex('translation', 'Traduce: Buenos días', 'Buenos días'),
        _ex('sentence_reorder', 'Reordena: Buenos días', 'Buenos días'),
      ];
      expect(dedupeExercises(list, 'es'), hasLength(2));
    });

    test('preserves the original indices for progress keys', () {
      final list = [
        _ex('translation', 'Traduce: Buenos días', 'Buenos días'),
        _ex('translation', 'Traduce: Buenos días', 'Buenos días'),
        _ex('translation', 'Traduce: Buenas noches', 'Buenas noches'),
      ];
      final out = dedupeExercises(list, 'es');
      expect(out.map((e) => e.key), [0, 2]);
      expect(out.last.value.answer, 'Buenas noches');
    });

    test('dedupedExerciseCount matches the rendered list', () {
      final list = [
        _ex('translation', 'Traduce: Buenos días', 'Buenos días'),
        _ex('translation', 'Traduce: Buenos días', 'Buenos días'),
        _ex('writing', 'Escribe: Buenas noches', 'Buenas noches'),
      ];
      expect(dedupedExerciseCount(list, 'es'), 2);
    });
  });
}

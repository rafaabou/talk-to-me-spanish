import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/services/audio_service.dart';
import 'package:talk_to_me_spanish/services/course_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourseRepository', () {
    test('should_load_six_levels_with_twelve_lessons_each', () async {
      final levels = await CourseRepository.instance.loadLevels();
      expect(levels.length, 6);
      expect(levels.keys.toSet(), {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'});
      for (final level in levels.values) {
        expect(level.lessons.length, 12);
        expect(level.lessons.first['id'], isA<String>());
      }
    });

    test('should_load_and_cache_a_real_lesson', () async {
      final lesson = await CourseRepository.instance.loadLesson('A1-01');
      expect(lesson.id, 'A1-01');
      expect(lesson.level, 'A1');
      expect(lesson.exercises, isNotEmpty);
      expect(lesson.vocabulary, isNotEmpty);

      final again = await CourseRepository.instance.loadLesson('A1-01');
      expect(identical(lesson, again), isTrue);
    });

    test('should_return_null_from_try_load_lesson_for_missing_id', () async {
      final lesson = await CourseRepository.instance.tryLoadLesson('Z9-99');
      expect(lesson, isNull);
    });
  });

  group('AudioService.audioKey', () {
    test('should_build_deterministic_hashed_asset_key', () {
      final k1 = AudioService.audioKey('Olá mundo!', 'pt');
      final k2 = AudioService.audioKey('Olá mundo!', 'pt');
      expect(k1, k2);
      expect(k1, startsWith('pt_'));
      expect(k1, endsWith('.opus'));
      expect(k1.length, 'pt_'.length + 12 + '.opus'.length);
    });

    test('should_vary_by_language_prefix', () {
      final pt = AudioService.audioKey('bom dia', 'pt');
      final es = AudioService.audioKey('bom dia', 'es');
      expect(pt.startsWith('pt_'), isTrue);
      expect(es.startsWith('es_'), isTrue);
    });

    test('should_vary_by_text_content', () {
      final a = AudioService.audioKey('casa', 'pt');
      final b = AudioService.audioKey('casas', 'pt');
      expect(a, isNot(b));
    });
  });
}

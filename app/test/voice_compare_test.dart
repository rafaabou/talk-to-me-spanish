import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/services/voice_compare_service.dart';

void main() {
  group('VoiceCompareService.normalize', () {
    test('lowercases and trims', () {
      expect(
        VoiceCompareService.normalize('  Hola, ¿Qué Tal?  '),
        'hola que tal',
      );
    });

    test('strips accents (PT/ES)', () {
      expect(VoiceCompareService.normalize('Coração já'), 'coracao ja');
      expect(VoiceCompareService.normalize('niño'), 'nino');
      expect(VoiceCompareService.normalize('à-là'), 'a la');
    });

    test('strips punctuation and collapses whitespace', () {
      expect(
        VoiceCompareService.normalize('Buenos días,,,\n  señor!!!'),
        'buenos dias senor',
      );
    });
  });

  group('VoiceCompareService.compare tiers', () {
    test('exact match passes with 100', () {
      final s = VoiceCompareService.compare(
        'Buenos días, ¿cómo estás?',
        'Buenos días, ¿cómo estás?',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
      expect(s.retry, isFalse);
      expect(s.failed, isFalse);
    });

    test('case and accent differences still pass', () {
      final s = VoiceCompareService.compare(
        'Hola, ¿cómo estás?',
        'hola como estas',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
    });

    test('empty heard scores 0 and fails', () {
      final s = VoiceCompareService.compare('Buenos días', '');
      expect(s.score, 0);
      expect(s.failed, isTrue);
    });

    test('unrelated sentence fails below 50', () {
      final s = VoiceCompareService.compare(
        'Gracias por la ayuda',
        'gato negro en la ventana',
      );
      expect(s.score, lessThan(50));
      expect(s.failed, isTrue);
    });

    test('small error lands in retry band', () {
      final s = VoiceCompareService.compare(
        'Me gustaría un café con leche',
        'me gustaria un cafe con leche por favor',
      );
      expect(s.score, greaterThanOrEqualTo(50));
      expect(s.score, lessThan(100));
    });

    test('one missing short word still reaches retry or pass', () {
      final s = VoiceCompareService.compare(
        'Buenos días senor',
        'Buenos día sen',
      );
      expect(s.score, greaterThanOrEqualTo(50));
    });

    test('Spanish ñ folds correctly', () {
      final s = VoiceCompareService.compare(
        'Mañana hay clase',
        'manana hay clase',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
    });

    test('sub-token heard cannot pass via containment', () {
      final s = VoiceCompareService.compareAny([
        'Buenos días, ¿cómo está usted hoy?',
      ], 'de');
      expect(s.score, lessThan(90));
      expect(s.passed, isFalse);
    });
  });

  group('thresholds', () {
    test('tier boundaries', () {
      expect(VoiceCompareService.passThreshold, 90);
      expect(VoiceCompareService.retryThreshold, 50);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/services/voice_compare_service.dart';

void main() {
  group('VoiceCompareService.normalize', () {
    test('lowercases and trims', () {
      expect(VoiceCompareService.normalize('  Oi, Tudo Bem?  '), 'oi tudo bem');
    });

    test('strips accents (PT/ES)', () {
      expect(VoiceCompareService.normalize('Coração já'), 'coracao ja');
      expect(VoiceCompareService.normalize('niño'), 'nino');
      expect(VoiceCompareService.normalize('à-là'), 'a la');
    });

    test('strips punctuation and collapses whitespace', () {
      expect(
        VoiceCompareService.normalize('Bom dia,,,\n  senhor!!!'),
        'bom dia senhor',
      );
    });
  });

  group('VoiceCompareService.compare tiers', () {
    test('exact match passes with 100', () {
      final s = VoiceCompareService.compare(
        'Bom dia, tudo bem?',
        'Bom dia, tudo bem?',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
      expect(s.retry, isFalse);
      expect(s.failed, isFalse);
    });

    test('case and accent differences still pass', () {
      final s = VoiceCompareService.compare(
        'Olá, como vai você?',
        'ola como vai voce',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
    });

    test('empty heard scores 0 and fails', () {
      final s = VoiceCompareService.compare('Bom dia', '');
      expect(s.score, 0);
      expect(s.failed, isTrue);
    });

    test('unrelated sentence fails below 50', () {
      final s = VoiceCompareService.compare(
        'Obrigado pela ajuda',
        'gato bonito janela',
      );
      expect(s.score, lessThan(50));
      expect(s.failed, isTrue);
    });

    test('small error lands in retry band', () {
      final s = VoiceCompareService.compare(
        'Eu gostaria de um café com leite',
        'eu gostaria de um cafe com leite por favor',
      );
      expect(s.score, greaterThanOrEqualTo(50));
      expect(s.score, lessThan(100));
    });

    test('one missing short word still reaches retry or pass', () {
      final s = VoiceCompareService.compare('Bom dia senhor', 'Bom dia sen');
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
  });

  group('thresholds', () {
    test('tier boundaries', () {
      expect(VoiceCompareService.passThreshold, 90);
      expect(VoiceCompareService.retryThreshold, 50);
    });
  });
}

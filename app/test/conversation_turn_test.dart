import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/services/conversation_turn_engine.dart';
import 'package:talk_to_me_spanish/services/voice_compare_service.dart';

DialogueLine _line(
  String speaker,
  String es, [
  String en = '',
  String ar = '',
]) {
  return DialogueLine(speaker, TriText(es, en, ar));
}

Exercise _writing(
  String promptEs,
  String answer, [
  List<String> accepted = const [],
]) {
  return Exercise(
    'writing',
    TriText(promptEs, '', ''),
    const [],
    answer,
    accepted,
    null,
    TriText('', '', ''),
  );
}

void main() {
  group('ConversationTurnEngine.build', () {
    test('splits dialogue into alternating partner/learner turns', () {
      final turns = ConversationTurnEngine.build(
        lines: [
          _line('Ana', '¡Buenos días!'),
          _line('Pedro', '¡Buenos días, ¿cómo estás?'),
          _line('Ana', 'Bien, gracias.'),
          _line('Pedro', '¡Genial!'),
        ],
        exercises: const [],
        targetLang: 'es',
      );
      expect(turns, hasLength(4));
      expect(turns[0].role, TurnRole.partner);
      expect(turns[1].role, TurnRole.learner);
      expect(turns[2].role, TurnRole.partner);
      expect(turns[3].role, TurnRole.learner);
    });

    test('learnerParity 0 flips roles', () {
      final turns = ConversationTurnEngine.build(
        lines: [_line('Ana', '¡Hola!'), _line('Pedro', '¡Hola!')],
        exercises: const [],
        targetLang: 'es',
        learnerParity: 0,
      );
      expect(turns[0].role, TurnRole.learner);
      expect(turns[1].role, TurnRole.partner);
    });

    test('marks freeAnswer after a question', () {
      final turns = ConversationTurnEngine.build(
        lines: [
          _line('Ana', '¿Quieres café?'),
          _line('Pedro', 'Sí, por favor.'),
          _line('Ana', 'Bien.'),
          _line('Pedro', 'Gracias.'),
        ],
        exercises: const [],
        targetLang: 'es',
      );
      expect(turns[0].freeAnswer, isFalse); // partner
      expect(turns[1].freeAnswer, isTrue); // answers the question
      expect(turns[3].freeAnswer, isFalse); // previous was not a question
    });

    test('accepted always contains scripted line', () {
      final turns = ConversationTurnEngine.build(
        lines: [_line('Ana', 'Hola, ¿qué tal?'), _line('Pedro', '¡Bien!')],
        exercises: const [],
        targetLang: 'es',
      );
      expect(turns[1].accepted, contains('¡Bien!'));
    });

    test('merges exercise answers into free-answer turn', () {
      final turns = ConversationTurnEngine.build(
        lines: [
          _line('Ana', '¿Cómo se dice goodbye?'),
          _line('Pedro', 'Adiós.'),
        ],
        exercises: [
          _writing(
            'Escribe otra forma de decir goodbye',
            'hasta luego',
            ['hasta luego'],
          ),
          _writing('Escribe algo sin relación', 'zzz'),
        ],
        targetLang: 'es',
      );
      // Question "¿Cómo se dice goodbye" shares content word with prompt.
      expect(turns[1].freeAnswer, isTrue);
      expect(turns[1].accepted, contains('Adiós.'));
      expect(turns[1].accepted, contains('hasta luego'));
    });

    test('excludes listening_mcq answers from free-answer enrichment', () {
      final listeningMcq = Exercise(
        'listening_mcq',
        TriText('¿Cómo te llamas?', '', ''),
        const [],
        'Me llamo Ana.',
        const [],
        null,
        TriText('', '', ''),
      );
      final turns = ConversationTurnEngine.build(
        lines: [
          _line('Ana', '¿Cómo te llamas?'),
          _line('Pedro', 'Me llamo Pedro.'),
        ],
        exercises: [listeningMcq],
        targetLang: 'es',
      );
      expect(turns[1].accepted, contains('Me llamo Pedro.'));
      expect(turns[1].accepted, isNot(contains('Me llamo Ana.')));
    });

    test('empty lines yield empty turns', () {
      final turns = ConversationTurnEngine.build(
        lines: const [],
        exercises: const [],
        targetLang: 'es',
      );
      expect(turns, isEmpty);
    });
  });

  group('scoreLearner / compareAny', () {
    test('exact scripted reply passes', () {
      final turns = ConversationTurnEngine.build(
        lines: [
          _line('Ana', '¡Buenos días!'),
          _line('Pedro', 'Buenos días, señor.'),
        ],
        exercises: const [],
        targetLang: 'es',
      );
      final s = ConversationTurnEngine.scoreLearner(
        turns[1],
        'Buenos días, señor.',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
    });

    test('short containment answer passes free response', () {
      final score = VoiceCompareService.compareAny([
        '¡Claro! Te lo prestaría con gusto.',
      ], 'Claro');
      expect(score.score, greaterThanOrEqualTo(90));
      expect(score.passed, isTrue);
    });

    test('sub-token answer fails containment floor', () {
      final score = VoiceCompareService.compareAny([
        'Buenos días, ¿cómo está usted hoy?',
      ], 'de');
      expect(score.score, lessThan(90));
      expect(score.passed, isFalse);
    });

    test('wrong answer fails below retry band', () {
      final score = VoiceCompareService.compareAny([
        'Sí, me gustaría viajar.',
      ], 'gato negro en la ventana');
      expect(score.score, lessThan(50));
      expect(score.failed, isTrue);
    });

    test('best of multiple accepted answers wins', () {
      final score = VoiceCompareService.compareAny(
        ['Una frase completamente diferente de la otra'],
        'Una frase completamente diferente de la otra',
        // second would fail badly
      );
      expect(score.score, 100);
    });

    test('retry band still works with compareAny', () {
      final score = VoiceCompareService.compareAny([
        'Me gustaría un café con leche',
      ], 'me gustaria un cafe con leche por favor');
      expect(score.score, greaterThanOrEqualTo(50));
      expect(score.score, lessThan(100));
    });
  });
}

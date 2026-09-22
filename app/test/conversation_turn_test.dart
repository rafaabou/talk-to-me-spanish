import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/services/conversation_turn_engine.dart';
import 'package:talk_to_me_spanish/services/voice_compare_service.dart';

DialogueLine _line(
  String speaker,
  String pt, [
  String en = '',
  String ar = '',
]) {
  return DialogueLine(speaker, TriText(pt, en, ar));
}

Exercise _writing(
  String promptPt,
  String answer, [
  List<String> accepted = const [],
]) {
  return Exercise(
    'writing',
    TriText(promptPt, '', ''),
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
          _line('Ana', 'Bom dia!'),
          _line('Pedro', 'Bom dia, tudo bem?'),
          _line('Ana', 'Tudo bem, obrigado.'),
          _line('Pedro', 'Ótimo!'),
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
        lines: [_line('Ana', 'Oi!'), _line('Pedro', 'Oi!')],
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
          _line('Ana', 'Você quer café?'),
          _line('Pedro', 'Sim, por favor.'),
          _line('Ana', 'Tudo bem.'),
          _line('Pedro', 'Obrigado.'),
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
        lines: [_line('Ana', 'Oi, tudo bem?'), _line('Pedro', 'Tudo bem!')],
        exercises: const [],
        targetLang: 'es',
      );
      expect(turns[1].accepted, contains('Tudo bem!'));
    });

    test('merges exercise answers into free-answer turn', () {
      final turns = ConversationTurnEngine.build(
        lines: [_line('Ana', 'Como se diz goodbye?'), _line('Pedro', 'Adeus.')],
        exercises: [
          _writing('Escreva otra forma de decir goodbye', 'tchau', ['tchau']),
          _writing('Escreva something unrelated', 'zzz'),
        ],
        targetLang: 'es',
      );
      // Question "Como se diz goodbye" shares content word with prompt.
      expect(turns[1].freeAnswer, isTrue);
      expect(turns[1].accepted, contains('Adeus.'));
      expect(turns[1].accepted, contains('tchau'));
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
        lines: [_line('Ana', 'Bom dia!'), _line('Pedro', 'Bom dia, senhor.')],
        exercises: const [],
        targetLang: 'es',
      );
      final s = ConversationTurnEngine.scoreLearner(
        turns[1],
        'Bom dia, senhor.',
      );
      expect(s.score, 100);
      expect(s.passed, isTrue);
    });

    test('short containment answer passes free response', () {
      final score = VoiceCompareService.compareAny([
        'Claro! Eu te emprestaria com prazer.',
      ], 'Claro');
      expect(score.score, greaterThanOrEqualTo(90));
      expect(score.passed, isTrue);
    });

    test('wrong answer fails below retry band', () {
      final score = VoiceCompareService.compareAny([
        'Sim, eu gostaria de viajar.',
      ], 'gato preto na janela');
      expect(score.score, lessThan(50));
      expect(score.failed, isTrue);
    });

    test('best of multiple accepted answers wins', () {
      final score = VoiceCompareService.compareAny(
        ['Uma frase completamente diferente da outra'],
        'Uma frase completamente diferente da outra',
        // second would fail badly
      );
      expect(score.score, 100);
    });

    test('retry band still works with compareAny', () {
      final score = VoiceCompareService.compareAny([
        'Eu gostaria de um café com leite',
      ], 'eu gostaria de um cafe com leite por favor');
      expect(score.score, greaterThanOrEqualTo(50));
      expect(score.score, lessThan(100));
    });
  });
}

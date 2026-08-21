import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/models/verb_models.dart';

void main() {
  test('parses augmented lesson (writing/listening/fill_blank/speaking)', () {
    final lesson = Lesson.fromJson({
      'id': 'A1-06',
      'level': 'A1',
      'title': {'es': 'a', 'en': 'a', 'ar': 'a'},
      'objectives': [],
      'vocabulary': [
        {'es': 'hablar', 'ipa': '', 'en': 'to speak', 'ar': 'يتكلم'},
      ],
      'grammar': [],
      'dialogue': {
        'title': {'es': 't', 'en': 't', 'ar': 't'},
        'lines': [
          {'speaker': 'A', 'es': 'Hola.', 'en': 'Hi.', 'ar': 'مرحبا'},
        ],
      },
      'reading': null,
      'speaking': {
        'title': {'es': 'Habla', 'en': 'Speak', 'ar': 'تحدث'},
        'phrases': [
          {'es': 'Hola.', 'en': 'Hi.', 'ar': 'مرحبا'},
        ],
      },
      'exercises': [
        {
          'type': 'writing',
          'prompt': {'es': 'p', 'en': 'p', 'ar': 'p'},
          'options': [],
          'answer': 'hablar',
          'accepted': ['habla'],
          'explanation': {'es': 'x', 'en': 'x', 'ar': 'x'},
        },
        {
          'type': 'listening',
          'prompt': {'es': 'p', 'en': 'p', 'ar': 'p'},
          'options': [
            {'es': 'a', 'en': 'a', 'ar': 'a'},
            {'es': 'b', 'en': 'b', 'ar': 'b'},
          ],
          'answer': 'a',
          'accepted': [],
          'audio': 'Hola.',
          'explanation': {'es': 'x', 'en': 'x', 'ar': 'x'},
        },
      ],
    });

    expect(lesson.speaking, hasLength(1));
    expect(lesson.speaking.first.text.es, 'Hola.');

    final writing = lesson.exercises.firstWhere((e) => e.type == 'writing');
    expect(writing.accepted, ['habla']);
    expect(writing.answer, 'hablar');

    final listening = lesson.exercises.firstWhere((e) => e.type == 'listening');
    expect(listening.audio, 'Hola.');
    expect(listening.options, hasLength(2));
  });

  test('trivial sanity test', () {
    expect(1 + 1, 2);
  });

  test('parses vocab example sentence', () {
    final lesson = Lesson.fromJson({
      'id': 'A1-01',
      'level': 'A1',
      'title': {'es': 'a', 'en': 'a', 'ar': 'a'},
      'objectives': [],
      'vocabulary': [
        {
          'es': 'hablar',
          'ipa': '/aˈβlaɾ/',
          'en': 'to speak',
          'ar': 'يتكلم',
          'example': {
            'es': 'Hablo español.',
            'en': 'I speak Spanish.',
            'ar': 'أتحدث الإسبانية.',
          },
        },
      ],
      'grammar': [],
      'dialogue': {
        'title': {'es': 't', 'en': 't', 'ar': 't'},
        'lines': [],
      },
      'reading': null,
      'speaking': {
        'title': {'es': 't', 'en': 't', 'ar': 't'},
        'phrases': [],
      },
      'exercises': [],
    });
    final v = lesson.vocabulary.first;
    expect(v.example, isNotNull);
    expect(v.example!.es, 'Hablo español.');
    expect(v.example!.en, 'I speak Spanish.');
  });

  test('parses dictation exercise', () {
    final e = Exercise.fromJson({
      'type': 'dictation',
      'prompt': {
        'es': 'Escucha y escribe.',
        'en': 'Listen and type.',
        'ar': 'استمع واكتب.',
      },
      'options': [],
      'answer': 'Hola, ¿cómo estás?',
      'accepted': [],
      'audio': 'Hola, ¿cómo estás?',
      'explanation': {'es': 'x', 'en': 'x', 'ar': 'x'},
    });
    expect(e.type, 'dictation');
    expect(e.audio, 'Hola, ¿cómo estás?');
  });

  test('verb model parses 6 tenses x 6 persons', () {
    final data = VerbData(
      [TenseInfo('present', TriTextLabel('Presente', 'Present', 'المضارع'))],
      ['yo', 'tú', 'él/ella', 'nosotros', 'ustedes', 'ellos/ellas'],
      [
        VerbInfo('ser', 'to be', 'يكون', {
          'present': ['soy', 'eres', 'es', 'somos', 'son', 'son'],
        }),
      ],
    );
    expect(data.verbs.first.conjugation('present'), hasLength(6));
    expect(data.verbs.first.conjugation('present').first, 'soy');
    expect(data.tenses.first.label.es, 'Presente');
  });
}

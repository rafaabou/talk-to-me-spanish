import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/course_models.dart';

class IndexVocab {
  final String lesson;
  final int index;
  final TriText text;
  final String ipa;
  final TriText? example;
  IndexVocab(this.lesson, this.index, this.text, {this.ipa = '', this.example});

  String get key => '$lesson::$index';
}

class IndexGrammar {
  final String lesson;
  final TriText title;
  final TriText explanation;
  final List<TriText> examples;
  IndexGrammar(
    this.lesson,
    this.title,
    this.explanation, {
    this.examples = const [],
  });
}

class IndexDialogue {
  final String lesson;
  final TriText text;
  IndexDialogue(this.lesson, this.text);
}

class IndexReading {
  final String lesson;
  final TriText text;
  IndexReading(this.lesson, this.text);
}

class ContentIndex {
  final List<IndexVocab> vocab;
  final List<IndexGrammar> grammar;
  final List<IndexDialogue> dialogue;
  final List<IndexReading> reading;
  ContentIndex(this.vocab, this.grammar, this.dialogue, this.reading);

  factory ContentIndex.fromJson(Map<String, dynamic> json) {
    return ContentIndex(
      (json['vocab'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        TriText? example;
        final ex = m['example'] as Map<String, dynamic>?;
        if (ex != null) {
          example = TriText(ex['es'] ?? '', ex['en'] ?? '', ex['ar'] ?? '');
        }
        return IndexVocab(
          m['lesson'] ?? '',
          m['index'] as int? ?? 0,
          TriText(m['es'] ?? '', m['en'] ?? '', m['ar'] ?? ''),
          ipa: m['ipa'] ?? '',
          example: example,
        );
      }).toList(),
      (json['grammar'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        final title = m['title'] as Map<String, dynamic>? ?? {};
        final expl = m['explanation'] as Map<String, dynamic>? ?? {};
        final examples =
            (m['examples'] as List? ?? []).map((x) {
              final ex = x as Map<String, dynamic>;
              return TriText(ex['es'] ?? '', ex['en'] ?? '', ex['ar'] ?? '');
            }).toList();
        return IndexGrammar(
          m['lesson'] ?? '',
          TriText(title['es'] ?? '', title['en'] ?? '', title['ar'] ?? ''),
          TriText(expl['es'] ?? '', expl['en'] ?? '', expl['ar'] ?? ''),
          examples: examples,
        );
      }).toList(),
      (json['dialogue'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return IndexDialogue(
          m['lesson'] ?? '',
          TriText(m['es'] ?? '', m['en'] ?? '', m['ar'] ?? ''),
        );
      }).toList(),
      (json['reading'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        final t = m['text'] as Map<String, dynamic>? ?? {};
        return IndexReading(
          m['lesson'] ?? '',
          TriText(t['es'] ?? '', t['en'] ?? '', t['ar'] ?? ''),
        );
      }).toList(),
    );
  }
}

class ContentIndexRepository {
  static final ContentIndexRepository instance = ContentIndexRepository._();
  ContentIndexRepository._();

  Future<ContentIndex>? _inflight;

  /// See VerbRepository.loadVerbs: the in-flight future is cached so
  /// concurrent callers share one parse of the index.
  Future<ContentIndex> load() {
    return _inflight ??= _parse();
  }

  Future<ContentIndex> _parse() async {
    final raw = await rootBundle.loadString('assets/course/index.json');
    final data = ContentIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _inflight = Future.value(data);
    return data;
  }
}

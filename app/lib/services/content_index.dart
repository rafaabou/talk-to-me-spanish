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
  final Map<String, TriText> lessonTitles;
  ContentIndex(
    this.vocab,
    this.grammar,
    this.dialogue,
    this.reading,
    this.lessonTitles,
  );

  factory ContentIndex.fromJson(Map<String, dynamic> json) {
    final lessonTitles = <String, TriText>{};
    for (final l in (json['lessons'] as List? ?? [])) {
      final m = l as Map<String, dynamic>;
      lessonTitles[m['id']] = TriText(
        m['title']?['es'] ?? '',
        m['title']?['en'] ?? '',
        m['title']?['ar'] ?? '',
      );
    }
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
      lessonTitles,
    );
  }
}

class ContentIndexRepository {
  static final ContentIndexRepository instance = ContentIndexRepository._();
  ContentIndexRepository._();

  ContentIndex? _cache;

  Future<ContentIndex> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/course/index.json');
    _cache = ContentIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache!;
  }
}

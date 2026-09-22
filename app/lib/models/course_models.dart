class TriText {
  final String es;
  final String en;
  final String ar;
  TriText(this.es, this.en, this.ar);

  factory TriText.fromJson(Map<String, dynamic> json) =>
      TriText(json['es'] ?? '', json['en'] ?? '', json['ar'] ?? '');

  String tr(String lang) {
    switch (lang) {
      case 'en':
        return en.isNotEmpty ? en : es;
      case 'ar':
        return ar.isNotEmpty ? ar : es;
      default:
        return es;
    }
  }
}

class VocabWord {
  final String es;
  final String ipa;
  final String en;
  final String ar;
  final TriText? example;
  VocabWord(this.es, this.ipa, this.en, this.ar, {this.example});

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    final example = json['example'] as Map<String, dynamic>?;
    return VocabWord(
      json['es'] ?? '',
      json['ipa'] ?? '',
      json['en'] ?? '',
      json['ar'] ?? '',
      example: example == null ? null : TriText.fromJson(example),
    );
  }

  String tr(String lang) {
    switch (lang) {
      case 'en':
        return en.isNotEmpty ? en : es;
      case 'ar':
        return ar.isNotEmpty ? ar : es;
      default:
        return es;
    }
  }
}

class GrammarSection {
  final TriText title;
  final TriText explanation;
  final List<TriText> examples;
  GrammarSection(this.title, this.explanation, this.examples);

  factory GrammarSection.fromJson(Map<String, dynamic> json) => GrammarSection(
    TriText.fromJson(json['title']),
    TriText.fromJson(json['explanation']),
    (json['examples'] as List? ?? []).map((e) => TriText.fromJson(e)).toList(),
  );
}

class DialogueLine {
  final String speaker;
  final TriText text;
  DialogueLine(this.speaker, this.text);

  factory DialogueLine.fromJson(Map<String, dynamic> json) =>
      DialogueLine(json['speaker'] ?? '', TriText.fromJson(json));
}

class Exercise {
  final String type;
  final TriText prompt;
  final List<TriText> options;
  final String answer;
  final List<String> accepted;
  final String? audio;
  final TriText explanation;
  Exercise(
    this.type,
    this.prompt,
    this.options,
    this.answer,
    this.accepted,
    this.audio,
    this.explanation,
  );

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    json['type'] ?? 'multiple_choice',
    TriText.fromJson(json['prompt']),
    (json['options'] as List? ?? []).map((e) => TriText.fromJson(e)).toList(),
    json['answer'] ?? '',
    (json['accepted'] as List? ?? []).cast<String>(),
    json['audio'] as String?,
    json['explanation'] is Map<String, dynamic>
        ? TriText.fromJson(json['explanation'] as Map<String, dynamic>)
        : TriText('', '', ''),
  );
}

class SpeakingItem {
  final TriText text;
  SpeakingItem(this.text);

  factory SpeakingItem.fromJson(Map<String, dynamic> json) =>
      SpeakingItem(TriText.fromJson(json));
}

class Lesson {
  final String id;
  final String level;
  final TriText title;
  final List<TriText> objectives;
  final List<VocabWord> vocabulary;
  final List<GrammarSection> grammar;
  final TriText? dialogueTitle;
  final List<DialogueLine> dialogueLines;
  final TriText? readingTitle;
  final TriText? readingText;
  final TriText? speakingTitle;
  final List<SpeakingItem> speaking;
  final List<Exercise> exercises;
  final TriText? culturalTips;

  Lesson({
    required this.id,
    required this.level,
    required this.title,
    required this.objectives,
    required this.vocabulary,
    required this.grammar,
    this.dialogueTitle,
    required this.dialogueLines,
    this.readingTitle,
    this.readingText,
    this.speakingTitle,
    required this.speaking,
    required this.exercises,
    this.culturalTips,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final dialogue = json['dialogue'] as Map<String, dynamic>?;
    final reading = json['reading'] as Map<String, dynamic>?;
    final speaking = json['speaking'] as Map<String, dynamic>?;
    final culturalTips = json['cultural_tips'] as Map<String, dynamic>?;
    return Lesson(
      id: json['id'] ?? '',
      level: json['level'] ?? '',
      title: TriText.fromJson(json['title']),
      objectives:
          (json['objectives'] as List? ?? [])
              .map((e) => TriText.fromJson(e))
              .toList(),
      vocabulary:
          (json['vocabulary'] as List? ?? [])
              .map((e) => VocabWord.fromJson(e))
              .toList(),
      grammar:
          (json['grammar'] as List? ?? [])
              .map((e) => GrammarSection.fromJson(e))
              .toList(),
      dialogueTitle:
          dialogue != null ? TriText.fromJson(dialogue['title']) : null,
      dialogueLines:
          (dialogue?['lines'] as List? ?? [])
              .map((e) => DialogueLine.fromJson(e))
              .toList(),
      readingTitle: reading != null ? TriText.fromJson(reading['title']) : null,
      readingText:
          reading != null
              ? TriText(
                reading['text_es'] ?? '',
                reading['text_en'] ?? '',
                reading['text_ar'] ?? '',
              )
              : null,
      speakingTitle:
          speaking != null ? TriText.fromJson(speaking['title']) : null,
      speaking:
          (speaking?['phrases'] as List? ?? [])
              .map((e) => SpeakingItem.fromJson(e))
              .toList(),
      exercises:
          (json['exercises'] as List? ?? [])
              .map((e) => Exercise.fromJson(e))
              .toList(),
      culturalTips:
          culturalTips != null
              ? TriText(
                culturalTips['es'] ?? '',
                culturalTips['en'] ?? '',
                culturalTips['ar'] ?? '',
              )
              : null,
    );
  }
}

class LevelInfo {
  final String id;
  final TriText name;
  final TriText description;
  final List<Map<String, dynamic>> lessons;

  LevelInfo(this.id, this.name, this.description, this.lessons);

  factory LevelInfo.fromJson(String id, Map<String, dynamic> json) => LevelInfo(
    id,
    TriText(
      json['name_es'] ?? '',
      json['name_en'] ?? '',
      json['name_ar'] ?? '',
    ),
    TriText(
      json['description_es'] ?? '',
      json['description_en'] ?? '',
      json['description_ar'] ?? '',
    ),
    (json['lessons'] as List? ?? []).cast<Map<String, dynamic>>(),
  );
}

import '../models/course_models.dart';

const Map<String, String> _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ý': 'y',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// Case-, accent- and punctuation-insensitive text used to decide whether two
/// exercises are the same piece of work.
String normalizeForDedup(String text) {
  final out = StringBuffer();
  for (final raw in text.toLowerCase().split('')) {
    final mapped = _accents[raw] ?? raw;
    for (final ch in mapped.split('')) {
      final isDigit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
      final isLetter = ch.codeUnitAt(0) >= 0x61 && ch.codeUnitAt(0) <= 0x7a;
      out.write(isLetter || isDigit ? ch : ' ');
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _triKey(TriText t, String contentLang) =>
    '${normalizeForDedup(t.tr(contentLang))}~${normalizeForDedup(t.en)}~'
    '${normalizeForDedup(t.ar)}';

String _sortedOptionsKey(Exercise e, String contentLang) {
  final keys = e.options.map((o) => _triKey(o, contentLang)).toList()..sort();
  return keys.join(';');
}

/// Exercise types where the learner picks from a fixed set of options, so the
/// option list is part of the work even when the prompt differs.
const Set<String> choiceDrillTypes = {
  'multiple_choice',
  'listening_mcq',
  'fill_blank',
  'match_pairs',
};

/// Identity of the work itself: same type, same instruction, same answer and
/// the same options.
String exerciseWorkKey(Exercise e, String contentLang) =>
    '${e.type}|${_triKey(e.prompt, contentLang)}|'
    '${normalizeForDedup(e.answer)}|${_sortedOptionsKey(e, contentLang)}';

/// Identity of a multiple-choice question: same options and same correct
/// answer means the learner does identical work even if the prompt is worded
/// differently.
String exerciseChoiceKey(Exercise e, String contentLang) {
  if (!choiceDrillTypes.contains(e.type)) return '';
  final options = _sortedOptionsKey(e, contentLang);
  if (options.isEmpty) return '';
  return '${e.type}|$options|${normalizeForDedup(e.answer)}';
}

/// Removes exercises that repeat work the learner already did in the same
/// lesson, keeping the first occurrence and its original index so that
/// `${lessonId}::${index}` progress keys stay valid.
List<MapEntry<int, Exercise>> dedupeExercises(
  List<Exercise> exercises,
  String contentLang,
) {
  final seenWork = <String>{};
  final seenChoice = <String>{};
  final out = <MapEntry<int, Exercise>>[];
  for (final entry in exercises.asMap().entries) {
    final e = entry.value;
    if (!seenWork.add(exerciseWorkKey(e, contentLang))) continue;
    final choice = exerciseChoiceKey(e, contentLang);
    if (choice.isNotEmpty && !seenChoice.add(choice)) continue;
    out.add(MapEntry(entry.key, e));
  }
  return out;
}

/// Number of exercises actually shown for a lesson.
int dedupedExerciseCount(List<Exercise> exercises, String contentLang) =>
    dedupeExercises(exercises, contentLang).length;

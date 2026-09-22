import '../models/course_models.dart';
import 'voice_compare_service.dart';

/// Role of a turn in a roleplay conversation.
enum TurnRole { partner, learner }

/// One chat turn: either the partner speaking (auto-play) or the learner's
/// free/scripted reply scored by the mic.
class ConversationTurn {
  final String speaker;
  final TriText text;
  final TurnRole role;

  /// True when the *previous* partner line was a question — the learner
  /// answers freely (scored against [accepted], not only the scripted line).
  final bool freeAnswer;

  /// All acceptable learner replies for this turn (scripted line first,
  /// plus exercise answers when applicable).
  final List<String> accepted;

  const ConversationTurn({
    required this.speaker,
    required this.text,
    required this.role,
    required this.freeAnswer,
    required this.accepted,
  });
}

/// Builds alternating partner/learner turns from a lesson dialogue and
/// enriches question replies with exercise answers where they fit.
class ConversationTurnEngine {
  /// [targetLang] is `'pt'` or `'es'` — used via [TriText.tr] to read the
  /// primary language field on either app's model.
  static List<ConversationTurn> build({
    required List<DialogueLine> lines,
    required List<Exercise> exercises,
    required String targetLang,
    int learnerParity = 1,
  }) {
    if (lines.isEmpty) return const [];
    final turns = <ConversationTurn>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final primary = line.text.tr(targetLang);
      final isLearner = (i % 2) == learnerParity;
      final prevQuestion =
          i > 0 && _isQuestion(lines[i - 1].text.tr(targetLang));
      final freeAnswer = isLearner && prevQuestion;

      final accepted = <String>[primary];
      if (freeAnswer) {
        accepted.addAll(
          _exerciseAnswersFor(
            lines[i - 1].text.tr(targetLang),
            exercises,
            targetLang,
          ),
        );
      }
      turns.add(
        ConversationTurn(
          speaker: line.speaker,
          text: line.text,
          role: isLearner ? TurnRole.learner : TurnRole.partner,
          freeAnswer: freeAnswer,
          accepted: _dedupe(accepted),
        ),
      );
    }
    return turns;
  }

  static bool _isQuestion(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    return t.endsWith('?') || t.endsWith('؟');
  }

  /// Pairs a partner question with exercise answers whose prompt shares
  /// enough content words with the question (or whose answer echoes a
  /// dialogue reply already in the lesson).
  static List<String> _exerciseAnswersFor(
    String question,
    List<Exercise> exercises,
    String targetLang,
  ) {
    final qTokens = _tokens(question);
    if (qTokens.isEmpty) return const [];
    final out = <String>[];
    for (final ex in exercises) {
      if (ex.type == 'match_pairs' ||
          ex.type == 'multiple_choice' ||
          ex.type == 'listening_mcq') {
        // MC options / pair drills / listening MCQs are not free spoken answers.
        continue;
      }
      if (ex.answer.trim().isEmpty) continue;
      final pTokens = _tokens(ex.prompt.tr(targetLang));
      if (pTokens.isEmpty) continue;
      final overlap = qTokens.intersection(pTokens).length;
      if (overlap >= 2 || (overlap >= 1 && qTokens.length <= 3)) {
        out.add(ex.answer);
        out.addAll(ex.accepted);
      }
    }
    return out;
  }

  static Set<String> _tokens(String s) {
    return VoiceCompareService.normalize(
      s,
    ).split(' ').where((t) => t.length > 2).toSet();
  }

  static List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      final key = VoiceCompareService.normalize(item);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(item.trim());
    }
    return out;
  }

  /// Best score for a learner turn against all accepted answers.
  static VoiceScore scoreLearner(ConversationTurn turn, String heard) {
    return VoiceCompareService.compareAny(turn.accepted, heard);
  }
}

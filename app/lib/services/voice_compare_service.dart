import 'dart:math' as math;

class VoiceScore {
  final int score;
  final String heard;
  final String expected;
  const VoiceScore({
    required this.score,
    required this.heard,
    required this.expected,
  });

  bool get passed => score >= VoiceCompareService.passThreshold;
  bool get retry => score >= VoiceCompareService.retryThreshold && !passed;
  bool get failed => score < VoiceCompareService.retryThreshold;
}

class VoiceCompareService {
  static const int passThreshold = 90;
  static const int retryThreshold = 50;

  static const Map<String, String> _fold = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ñ': 'n',
    'ç': 'c',
    'ß': 'ss',
    'œ': 'oe',
    'æ': 'ae',
    'ā': 'a',
    'ē': 'e',
    'ī': 'i',
    'ō': 'o',
    'ū': 'u',
  };

  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_fold[ch] ?? ch);
    }
    s = b.toString();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (j) => j);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= b.length; j++) {
        final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      prev.setAll(0, curr);
    }
    return prev[b.length];
  }

  static double _tokenDice(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final counts = <String, int>{};
    for (final t in a) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    var inter = 0;
    for (final t in b) {
      final c = counts[t] ?? 0;
      if (c > 0) {
        inter++;
        counts[t] = c - 1;
      }
    }
    return 2 * inter / (a.length + b.length);
  }

  static VoiceScore compare(String expected, String heard) {
    final expRaw = expected.trim();
    final heardRaw = heard.trim();
    final e = normalize(expected);
    final h = normalize(heard);
    if (e.isEmpty) {
      return VoiceScore(score: 100, heard: heardRaw, expected: expRaw);
    }
    if (h.isEmpty) {
      return VoiceScore(score: 0, heard: heardRaw, expected: expRaw);
    }
    final maxLen = math.max(e.length, h.length);
    final charSim = 1 - _levenshtein(e, h) / maxLen;
    final dice = _tokenDice(e.split(' '), h.split(' '));
    final score = ((0.6 * charSim + 0.4 * dice) * 100).round().clamp(0, 100);
    return VoiceScore(score: score, heard: heardRaw, expected: expRaw);
  }

  /// Scores [heard] against every accepted answer and returns the best hit.
  /// Also applies a containment bonus so a short correct answer ("¡Claro!")
  /// still passes against a longer scripted reply.
  static VoiceScore compareAny(List<String> expecteds, String heard) {
    final list = expecteds.where((e) => e.trim().isNotEmpty).toList();
    if (list.isEmpty) {
      return VoiceScore(score: 0, heard: heard.trim(), expected: '');
    }
    VoiceScore best = compare(list.first, heard);
    for (final exp in list) {
      final s = compare(exp, heard);
      if (s.score > best.score) best = s;
    }
    if (heard.trim().isEmpty) return best;
    for (final exp in list) {
      final c = _containmentScore(exp, heard);
      if (c > best.score) {
        best = VoiceScore(score: c, heard: heard.trim(), expected: exp.trim());
      }
    }
    return best;
  }

  /// If every heard token appears in the expected answer (or vice versa),
  /// the learner said the right thing with different scope — score ≥ 92.
  static int _containmentScore(String expected, String heard) {
    final e = normalize(expected).split(' ').where((t) => t.isNotEmpty).toSet();
    final h = normalize(heard).split(' ').where((t) => t.isNotEmpty).toSet();
    if (e.isEmpty || h.isEmpty) return 0;
    if (h.containsAll(e) || e.containsAll(h)) {
      final ratio = math.min(e.length, h.length) / math.max(e.length, h.length);
      return (92 + 8 * ratio).round().clamp(0, 100);
    }
    final inter = e.intersection(h).length;
    final minSize = math.min(e.length, h.length);
    if (inter >= 2 && minSize > 0 && inter / minSize >= 0.6) {
      return (88 * (inter / minSize)).round().clamp(0, 100);
    }
    return 0;
  }
}

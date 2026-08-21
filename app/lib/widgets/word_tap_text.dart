import 'package:flutter/material.dart';
import '../services/course_repository.dart';
import 'audio_button.dart';
import '../services/ui_text.dart';

class WordLookup {
  final String es;
  final String en;
  final String ar;
  final String? ipa;
  final String lessonId;
  WordLookup(this.es, this.en, this.ar, this.ipa, this.lessonId);
}

class WordTapText extends StatefulWidget {
  final String es;
  final String en;
  final String ar;
  final bool audio;
  final bool compact;
  const WordTapText({
    super.key,
    required this.es,
    required this.en,
    required this.ar,
    this.audio = false,
    this.compact = false,
  });

  @override
  State<WordTapText> createState() => _WordTapTextState();
}

class _WordTapTextState extends State<WordTapText> {
  final Map<String, List<WordLookup>> _cache = {};
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadLookup();
    }
  }

  Future<void> _loadLookup() async {
    final levels = await CourseRepository.instance.loadLevels();
    final map = <String, List<WordLookup>>{};
    for (final level in levels.values) {
      for (final lessonMeta in level.lessons) {
        final id = lessonMeta['id'] as String;
        final lesson = await CourseRepository.instance.tryLoadLesson(id);
        if (lesson == null) continue;
        for (final v in lesson.vocabulary) {
          for (final w in [v.es, v.en, v.ar]) {
            final key = w.toLowerCase();
            map
                .putIfAbsent(key, () => [])
                .add(
                  WordLookup(
                    v.es,
                    v.en,
                    v.ar,
                    v.ipa.isEmpty ? null : v.ipa,
                    lesson.id,
                  ),
                );
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _cache.addAll(map));
  }

  void _lookup(String word) {
    final clean =
        word
            .replaceAll(RegExp('[^\\p{L}\\p{N}\u0027\u002d\u2019\u2018]'), '')
            .toLowerCase();
    if (clean.isEmpty) return;
    final results = _cache[clean] ?? [];
    if (results.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          clean,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      AudioButton(
                        text: results.first.es,
                        lang: 'es',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final r in results) ...[
                    Text(r.en, style: Theme.of(context).textTheme.bodyLarge),
                    if (r.ar.isNotEmpty)
                      Text(
                        r.ar,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final primary = widget.es;
    final secondary = uiText(lang, ar: widget.ar, other: widget.en);

    final textStyle =
        widget.compact
            ? Theme.of(context).textTheme.bodyMedium
            : Theme.of(context).textTheme.bodyLarge;

    final words = primary.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _lookup(w),
            child: Text(
              w,
              style: textStyle?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        ),
      );
      if (i < words.length - 1) spans.add(const TextSpan(text: ' '));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text.rich(TextSpan(children: spans))),
            if (widget.audio)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: AudioButton(text: widget.es, lang: 'es', compact: true),
              ),
          ],
        ),
        if (!widget.compact && secondary.isNotEmpty && secondary != primary)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              secondary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

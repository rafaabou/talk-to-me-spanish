import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import 'audio_button.dart';

/// Languages to show underneath the course text, in display order.
///
/// Arabic is always included: the app is built for Arabic speakers, so it is
/// not something to hide behind a switch. [showEnglish] only decides whether
/// the English line appears, and the interface language is added when it is
/// neither the course language nor already listed.
List<String> visibleTranslationLangs({
  required String contentLang,
  required String uiLang,
  required bool showEnglish,
}) {
  final langs = <String>[];
  if (showEnglish || uiLang == 'en') langs.add('en');
  if (uiLang != contentLang && uiLang != 'ar' && !langs.contains(uiLang)) {
    langs.add(uiLang);
  }
  if (!langs.contains('ar')) langs.add('ar');
  return langs;
}

class TriBlock extends StatelessWidget {
  /// Language of the course content, which is what the audio keys are built
  /// from. This is not the interface language.
  static const String contentLang = 'es';

  final TriText text;
  final bool audio;
  final bool compact;
  final String? contentLangOverride;

  const TriBlock(
    this.text, {
    super.key,
    this.audio = false,
    this.compact = false,
    this.contentLangOverride,
  });

  String get _contentLang => contentLangOverride ?? contentLang;

  @override
  Widget build(BuildContext context) {
    final showEnglish = context.select<AppState, bool>(
      (s) => s.showEnglishTranslation,
    );
    final uiLang = context.select<AppState, String>((s) => s.lang);
    final scheme = Theme.of(context).colorScheme;
    final content = _contentLang;
    final primary = text.tr(content);

    // The sentence being studied is the content language; the translations
    // underneath are the interface language plus Arabic, which is always kept.
    final extraLangs = visibleTranslationLangs(
      contentLang: content,
      uiLang: uiLang,
      showEnglish: showEnglish,
    );

    final primaryStyle = (compact
            ? Theme.of(context).textTheme.bodyLarge
            : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(fontWeight: FontWeight.w700);
    final secondaryStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 15,
      height: uiLang == 'ar' ? 1.5 : 1.4,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (audio) ...[
          AudioButton(text: primary, lang: content, compact: true),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(primary, style: primaryStyle),
              for (final lang in extraLangs)
                if (_visible(lang, primary))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text.tr(lang),
                      style: secondaryStyle,
                      textDirection: lang == 'ar' ? TextDirection.rtl : null,
                      textAlign: lang == 'ar' ? TextAlign.right : null,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  /// A language is skipped when the model has no text for it, because
  /// [TriText.tr] silently falls back to the content language.
  bool _visible(String lang, String primary) {
    final value = text.tr(lang).trim();
    return value.isNotEmpty && value != primary.trim();
  }
}

import 'package:flutter/material.dart';
import '../models/course_models.dart';
import 'audio_button.dart';

class TriBlock extends StatelessWidget {
  final TriText text;
  final bool audio;
  final bool compact;

  const TriBlock(
    this.text, {
    super.key,
    this.audio = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (audio) ...[
          AudioButton(text: text.es, lang: 'es', compact: true),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.es,
                style:
                    compact
                        ? style.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )
                        : style.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
              ),
              if (text.en.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(text.en, style: style.bodyMedium),
              ],
              if (text.ar.isNotEmpty) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    text.ar,
                    style: style.bodyMedium,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

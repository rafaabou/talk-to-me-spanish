import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/ui_text.dart';

/// Quick text-size control used from the lesson app bar and the pinch handler.
class TextSizeSheet extends StatelessWidget {
  const TextSizeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const TextSizeSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText(
                lang,
                ar: 'حجم النص',
                pt: 'Tamanho do texto',
                es: 'Tamaño del texto',
                other: 'Text size',
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${(state.zoom * 100).round()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: state.zoom.clamp(0.8, 2.5),
              min: 0.8,
              max: 2.5,
              divisions: 17,
              label: '${(state.zoom * 100).round()}%',
              onChanged: state.setZoom,
            ),
            const SizedBox(height: 8),
            Text(
              'El pequeño ratón está aprendiendo español.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              uiText(
                lang,
                ar: 'نص تجريبي — يظهر بنفس حجم كل النصوص.',
                pt: 'Texto de exemplo — aparece no mesmo tamanho de todo o app.',
                es:
                    'Texto de ejemplo — se ve al mismo tamaño que el resto del app.',
                other:
                    'Sample text — shown at the same size as the rest of the app.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.setZoom(state.zoom - 0.1),
                    icon: const Icon(Icons.text_decrease),
                    label: Text(
                      uiText(
                        lang,
                        ar: 'أصغر',
                        pt: 'Menor',
                        es: 'Menor',
                        other: 'Smaller',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => state.setZoom(state.zoom + 0.1),
                    icon: const Icon(Icons.text_increase),
                    label: Text(
                      uiText(
                        lang,
                        ar: 'أكبر',
                        pt: 'Maior',
                        es: 'Mayor',
                        other: 'Larger',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

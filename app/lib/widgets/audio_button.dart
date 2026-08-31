import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/ui_text.dart';

class AudioButton extends StatelessWidget {
  final String text;
  final String lang;
  final bool compact;

  const AudioButton({
    super.key,
    required this.text,
    required this.lang,
    this.compact = false,
  });

  Future<void> _play(BuildContext context) async {
    final ok = await AudioService.instance.playText(text, lang);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                lang,
                ar: 'الصوت غير متاح',
                es: 'Audio no disponible',
                other: 'Audio not available',
              ),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.volume_up),
      iconSize: compact ? 18 : 22,
      color: Theme.of(context).colorScheme.primary,
      tooltip: uiText(lang, ar: 'استمع', es: 'Escuchar', other: 'Listen'),
      onPressed: () => _play(context),
    );
  }
}

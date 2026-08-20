import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class CreditFooter extends StatelessWidget {
  const CreditFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final theme = Theme.of(context);
    final String credit;
    switch (lang) {
      case 'es':
        credit = '© 2026 Proyecto: Talk To Me  · 100% offline · español.';
      case 'ar':
        credit =
            '© 2026 مشروع: تحدث إليّ، · يعمل بالكامل دون اتصال بالإنترنت · الإسبانية.';
      default:
        credit = '© 2026 Project: Talk To Me  · 100% offline · Spanish';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(),
          const SizedBox(height: 8),
          Text(
            credit,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Mohamed Rafaa TOUNEKTI · DevOps & DevSecOps Engineer',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'linkedin.com/in/mohamed-rafaa-tounekti · rafaabou@gmail.com · github.com/rafaabou',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/progress_service.dart';
import '../services/progress_file_helper.dart' as file_helper;
import '../services/ui_text.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../widgets/text_size_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final theme = Theme.of(context);

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(
              lang,
              ar: 'الإعدادات',
              pt: 'Configurações',
              es: 'Ajustes',
              other: 'Settings',
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _Header(
              text: uiText(
                lang,
                ar: 'القراءة',
                pt: 'Leitura',
                es: 'Lectura',
                other: 'Reading',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(
                uiText(
                  lang,
                  ar: 'حجم النص',
                  pt: 'Tamanho do texto',
                  es: 'Tamaño del texto',
                  other: 'Text size',
                ),
              ),
              subtitle: Text('${(state.zoom * 100).round()}%'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => TextSizeSheet.show(context),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.translate),
              value: state.showEnglishTranslation,
              title: Text(
                uiText(
                  lang,
                  ar: 'إظهار الترجمة الإنجليزية',
                  es: 'Mostrar la traducción al inglés',
                  other: 'Show English translation',
                ),
              ),
              subtitle: Text(
                uiText(
                  lang,
                  ar: 'العربية تظهر دائماً. أوقفه لإخفاء الإنجليزية فقط.',
                  es:
                      'El árabe siempre se muestra. Desactívelo para ocultar solo el inglés.',
                  other:
                      'Arabic is always shown. Turn off to hide English only.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              onChanged: state.setShowEnglishTranslation,
            ),
            const Divider(),
            _Header(
              text: uiText(
                lang,
                ar: 'اللغة والمظهر',
                pt: 'Idioma e aparência',
                es: 'Idioma y apariencia',
                other: 'Language & appearance',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(
                uiText(
                  lang,
                  ar: 'لغة الواجهة',
                  pt: 'Idioma da interface',
                  es: 'Idioma de la interfaz',
                  other: 'Interface language',
                ),
              ),
              trailing: DropdownButton<String>(
                value: state.lang,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                ],
                onChanged: (v) {
                  if (v != null) state.setLang(v);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(
                uiText(
                  lang,
                  ar: 'المظهر',
                  pt: 'Tema',
                  es: 'Tema',
                  other: 'Theme',
                ),
              ),
              trailing: DropdownButton<ThemeMode>(
                value: state.themeMode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(
                      uiText(
                        lang,
                        ar: 'النظام',
                        pt: 'Sistema',
                        es: 'Sistema',
                        other: 'System',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(
                      uiText(
                        lang,
                        ar: 'فاتح',
                        pt: 'Claro',
                        es: 'Claro',
                        other: 'Light',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(
                      uiText(
                        lang,
                        ar: 'داكن',
                        pt: 'Escuro',
                        es: 'Oscuro',
                        other: 'Dark',
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) state.setThemeMode(v);
                },
              ),
            ),
            const Divider(),
            _Header(
              text: uiText(
                lang,
                ar: 'الصوت',
                pt: 'Áudio',
                es: 'Audio',
                other: 'Audio',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text(
                uiText(
                  lang,
                  ar: 'سرعة التشغيل',
                  pt: 'Velocidade',
                  es: 'Velocidad',
                  other: 'Playback speed',
                ),
              ),
              trailing: DropdownButton<double>(
                value: state.speed,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('0.5×')),
                  DropdownMenuItem(value: 0.75, child: Text('0.75×')),
                  DropdownMenuItem(value: 1.0, child: Text('1×')),
                ],
                onChanged: (v) {
                  if (v != null) state.setSpeed(v);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(
                uiText(
                  lang,
                  ar: 'عدد التكرار',
                  pt: 'Repetições',
                  es: 'Repeticiones',
                  other: 'Repeat count',
                ),
              ),
              trailing: DropdownButton<int>(
                value: state.repeat,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1×')),
                  DropdownMenuItem(value: 3, child: Text('3×')),
                  DropdownMenuItem(value: 7, child: Text('7×')),
                  DropdownMenuItem(value: 10, child: Text('10×')),
                ],
                onChanged: (v) {
                  if (v != null) state.setRepeat(v);
                },
              ),
            ),
            const Divider(),
            _Header(
              text: uiText(
                lang,
                ar: 'النسخ الاحتياطي',
                pt: 'Backup',
                es: 'Copia de seguridad',
                other: 'Backup',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(
                uiText(
                  lang,
                  ar: 'حفظ التقدم',
                  pt: 'Salvar progresso',
                  es: 'Guardar progreso',
                  other: 'Export progress',
                ),
              ),
              onTap: () async {
                final path = await ProgressService.instance.exportToFile();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        uiText(
                          lang,
                          ar: 'تم الحفظ: $path',
                          pt: 'Progresso salvo em: $path',
                          es: 'Progreso guardado en: $path',
                          other: 'Progress saved to: $path',
                        ),
                      ),
                    ),
                  );
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: Text(
                uiText(
                  lang,
                  ar: 'استيراد التقدم',
                  pt: 'Importar progresso',
                  es: 'Importar progreso',
                  other: 'Import progress',
                ),
              ),
              onTap: () async {
                final jsonString = await file_helper.pickAndReadFile();
                if (jsonString == null) return;
                await ProgressService.instance.importData(jsonString);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        uiText(
                          lang,
                          ar: 'تم الاستيراد',
                          pt: 'Progresso importado',
                          es: 'Progreso importado',
                          other: 'Progress imported',
                        ),
                      ),
                    ),
                  );
              },
            ),
            const CreditFooter(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

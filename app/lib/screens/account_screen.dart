import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/progress_service.dart';
import '../services/ui_text.dart';
import '../services/app_state.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import 'package:provider/provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String? _lastBackup;
  bool _exporting = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(lang, ar: 'الحساب', es: 'Cuenta', other: 'Account'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(lang),
            const SizedBox(height: 16),
            _buildBackupSection(lang),
            const SizedBox(height: 16),
            _buildDataSection(lang),
            const SizedBox(height: 16),
            _buildAboutSection(lang),
            const CreditFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang == 'ar'
                  ? 'متعلم'
                  : lang == 'es'
                  ? 'Aprendiz'
                  : 'Learner',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              uiText(
                lang,
                ar: 'محفوظ محلياً على هذا الجهاز',
                es: 'Guardado localmente en este dispositivo',
                other: 'Saved locally on this device',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  uiText(
                    lang,
                    ar: 'النسخ الاحتياطي',
                    es: 'Respaldo',
                    other: 'Backup',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.upload_file,
              title: uiText(
                lang,
                ar: 'تصدير البيانات',
                es: 'Exportar Datos',
                other: 'Export Data',
              ),
              subtitle: uiText(
                lang,
                ar: 'حفظ التقدم كملف',
                es: 'Guardar progreso como archivo',
                other: 'Save progress as file',
              ),
              loading: _exporting,
              onTap: _exportData,
            ),
            _buildActionTile(
              icon: Icons.download,
              title: uiText(
                lang,
                ar: 'استيراد البيانات',
                es: 'Importar Datos',
                other: 'Import Data',
              ),
              subtitle: uiText(
                lang,
                ar: 'استعادة التقدم من ملف',
                es: 'Restaurar progreso de archivo',
                other: 'Restore progress from file',
              ),
              loading: _importing,
              onTap: _importData,
            ),
            _buildActionTile(
              icon: Icons.share,
              title: uiText(
                lang,
                ar: 'مشاركة التقدم',
                es: 'Compartir Progreso',
                other: 'Share Progress',
              ),
              subtitle: uiText(
                lang,
                ar: 'إرسال ملف التقدم',
                es: 'Enviar archivo de progreso',
                other: 'Send progress file',
              ),
              onTap: _shareProgress,
            ),
            if (_lastBackup != null) ...[
              const SizedBox(height: 8),
              Text(
                uiText(
                  lang,
                  ar: 'آخر نسخ: $_lastBackup',
                  es: 'Último respaldo: $_lastBackup',
                  other: 'Last backup: $_lastBackup',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  uiText(lang, ar: 'البيانات', es: 'Datos', other: 'Data'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.delete_sweep,
              title: uiText(
                lang,
                ar: 'مسح كل التقدم',
                es: 'Borrar Todo el Progreso',
                other: 'Clear All Progress',
              ),
              subtitle: uiText(
                lang,
                ar: 'حذف جميع البيانات',
                es: 'Eliminar todos los datos',
                other: 'Delete all data',
              ),
              isDestructive: true,
              onTap: _clearAllData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  uiText(lang, ar: 'حول', es: 'Acerca de', other: 'About'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('App', 'Talk To Me'),
            _buildInfoRow(
              uiText(lang, ar: 'الإصدار', es: 'Versión', other: 'Version'),
              '1.5.0',
            ),
            _buildInfoRow(
              uiText(lang, ar: 'المؤلف', es: 'Autor', other: 'Author'),
              'Mohamed Rafaa Tounekti',
            ),
            _buildInfoRow(
              uiText(lang, ar: 'الخصوصية', es: 'Privacidad', other: 'Privacy'),
              uiText(
                lang,
                ar: 'بياناتك تبقى على جهازك فقط',
                es: 'Tus datos permanecen solo en tu dispositivo',
                other: 'Your data stays on your device only',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool loading = false,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing:
          loading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.chevron_right),
      onTap: loading ? null : onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final path = await ProgressService.instance.exportToFile();
      if (mounted) {
        setState(() {
          _exporting = false;
          _lastBackup = DateTime.now().toString().substring(0, 16);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context.read<AppState>().lang,
                ar: 'تم التصدير: $path',
                es: 'Exportado: $path',
                other: 'Exported: $path',
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData() async {
    setState(() => _importing = true);
    try {
      final result = await ProgressService.instance.importFromFile('');
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context.read<AppState>().lang,
                ar: result ? 'تم الاستيراد بنجاح' : 'فشل الاستيراد',
                es: result ? 'Importado con éxito' : 'Error en la importación',
                other: result ? 'Import successful' : 'Import failed',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _shareProgress() async {
    try {
      final data = await ProgressService.instance.exportData();
      await SharePlus.instance.share(
        ShareParams(text: data, subject: 'Talk To Me Progress Backup'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              uiText(
                context.read<AppState>().lang,
                ar: 'تأكيد المسح',
                es: 'Confirmar Borrado',
                other: 'Confirm Clear',
              ),
            ),
            content: Text(
              uiText(
                context.read<AppState>().lang,
                ar: 'هل تريد حذف جميع التقدم؟ لا يمكن التراجع.',
                es:
                    '¿Deseas eliminar todo el progreso? Esta acción no se puede deshacer.',
                other: 'Delete all progress? This cannot be undone.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  uiText(
                    context.read<AppState>().lang,
                    ar: 'إلغاء',
                    es: 'Cancelar',
                    other: 'Cancel',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('OK', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ProgressService.instance.resetAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context.read<AppState>().lang,
                ar: 'تم مسح كل التقدم',
                es: 'Todo el progreso fue borrado',
                other: 'All progress cleared',
              ),
            ),
          ),
        );
      }
    }
  }
}

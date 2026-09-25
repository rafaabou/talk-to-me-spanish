import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // C2-01 has the largest vocabulary and exercise set in the course. Before the
  // page builders became MultiPage, one long section overflowed a single A4
  // page and the export produced a broken or truncated document.
  test('exports the longest lesson in the course without overflowing', () async {
    SharedPreferences.setMockInitialValues({'ui_lang': 'en'});
    final appState = AppState();

    for (final lessonId in const ['A1-01', 'B1-06', 'C2-01']) {
      for (final lang in const ['en', 'pt', 'ar']) {
        await appState.setLang(lang);
        final bytes = await PdfExportService.instance.buildLessonPdf(
          lessonId: lessonId,
          lang: appState.lang,
        );
        final body = bytes;
        expect(
          body.length,
          greaterThan(2000),
          reason: '$lessonId in $lang produced a suspiciously small PDF',
        );
        // %PDF- header: the document was written, not truncated.
        expect(String.fromCharCodes(body.sublist(0, 5)), '%PDF-');
        // /Type /Page occurrences: more than one page means MultiPage paginated.
        final text = String.fromCharCodes(body);
        expect(
          RegExp(r'/Type\s*/Page[^s]').allMatches(text).length,
          greaterThan(1),
          reason: '$lessonId in $lang should span more than one page',
        );
      }
    }
  });
}

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:talk_to_me_spanish/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The exported handout used Helvetica, which has no IPA glyphs, so
  // transcriptions like /a ˈlɛ.tɾa/ lost characters. The service now embeds a
  // Noto Sans subset; this proves the font is bundled and actually embedded.
  group('PDF export font', () {
    test('the IPA subset fonts are bundled in the asset manifest', () async {
      for (final asset in const [
        'assets/fonts/NotoSansPdf-Regular.ttf',
        'assets/fonts/NotoSansPdf-Bold.ttf',
      ]) {
        final data = await rootBundle.load(asset);
        expect(
          data.lengthInBytes,
          greaterThan(10000),
          reason: '$asset should be a real font file',
        );
      }
    });

    test('a document using the theme embeds the font and keeps IPA', () async {
      final theme = await PdfExportService.loadThemeForTest();
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build:
              (context) => pw.Text(
                'a letra /a ˈlɛ.tɾa/ — ʃ ʒ ɲ ɔ ɛ',
                style: const pw.TextStyle(fontSize: 14),
              ),
        ),
      );
      final bytes = await doc.save();

      // An embedded TrueType subset shows up as a FontFile2 stream.
      expect(
        String.fromCharCodes(bytes),
        contains('FontFile2'),
        reason: 'the PDF must embed the font, not reference Helvetica',
      );
    });
  });
}

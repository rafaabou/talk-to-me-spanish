import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/ui_text.dart';
import 'pdf_file_helper.dart' as file_helper;

class PdfExportService {
  static final PdfExportService instance = PdfExportService._();
  PdfExportService._();

  /// The `pdf` package defaults to Helvetica, which has no IPA glyphs, so
  /// lesson exports silently dropped characters like ˈ ɾ ʃ. These subsets of
  /// Noto Sans (built by app/tools/build_pdf_font_subset.py) cover Latin and
  /// the IPA block. Arabic is left out on purpose: the package performs no
  /// complex-script shaping, so Arabic would be disconnected either way.
  static pw.Font? _font;
  static pw.Font? _fontBold;

  static Future<pw.ThemeData> _loadTheme() async {
    _font ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansPdf-Regular.ttf'),
    );
    _fontBold ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansPdf-Bold.ttf'),
    );
    return pw.ThemeData.withFont(base: _font, bold: _fontBold);
  }

  /// Exposed so tests can verify the export font is bundled and embedded.
  @visibleForTesting
  static Future<pw.ThemeData> loadThemeForTest() => _loadTheme();

  /// Builds the document without touching the file system, so it can be
  /// verified in tests. Writing and sharing is [exportLessonToPdf]'s job.
  Future<Uint8List> buildLessonPdf({
    required String lessonId,
    required String lang,
  }) async {
    final lesson = await CourseRepository.instance.tryLoadLesson(lessonId);
    if (lesson == null) throw Exception('Lesson not found: $lessonId');

    final pdf = pw.Document(theme: await _loadTheme());
    final t = _Translations(lang);

    // Cover page
    pdf.addPage(_buildCoverPage(lesson, t, lang));

    // Objectives
    if (lesson.objectives.isNotEmpty) {
      pdf.addPage(_buildObjectivesPage(lesson, t, lang));
    }

    // Vocabulary
    if (lesson.vocabulary.isNotEmpty) {
      pdf.addPage(_buildVocabularyPage(lesson, t, lang));
    }

    // Grammar
    if (lesson.grammar.isNotEmpty) {
      pdf.addPage(_buildGrammarPage(lesson, t, lang));
    }

    // Dialogue
    if (lesson.dialogueLines.isNotEmpty) {
      pdf.addPage(_buildDialoguePage(lesson, t, lang));
    }

    // Reading
    if (lesson.readingText != null) {
      pdf.addPage(_buildReadingPage(lesson, t, lang));
    }

    // Exercises
    if (lesson.exercises.isNotEmpty) {
      pdf.addPage(_buildExercisesPage(lesson, t, lang));
    }

    return pdf.save();
  }

  Future<String> exportLessonToPdf({
    required String lessonId,
    required AppState appState,
  }) async {
    final bytes = await buildLessonPdf(lessonId: lessonId, lang: appState.lang);
    final fileName = 'ES_${lessonId}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await file_helper.saveAndSharePdf(bytes, fileName);

    return result ?? 'PDF generated';
  }

  pw.Page _buildCoverPage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Talk To Me Spanish By Mohamed Rafaa Tounekti',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '${lesson.level} · ${lesson.id}',
                  style: pw.TextStyle(fontSize: 24, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  lesson.title.tr(lang),
                  style: pw.TextStyle(fontSize: 20),
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  t.lessonHandout,
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
    );
  }

  pw.MultiPage _buildObjectivesPage(
    Lesson lesson,
    _Translations t,
    String lang,
  ) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.objectives,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...lesson.objectives.map(
              (o) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(fontSize: 14)),
                    pw.Expanded(
                      child: pw.Text(
                        o.tr(lang),
                        style: pw.TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
    );
  }

  pw.MultiPage _buildVocabularyPage(
    Lesson lesson,
    _Translations t,
    String lang,
  ) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.vocabulary,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...lesson.vocabulary.map(
              (v) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          v.es,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        if (v.ipa.isNotEmpty)
                          pw.Text(
                            v.ipa,
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.grey600,
                            ),
                          ),
                      ],
                    ),
                    pw.Text(v.tr(lang), style: pw.TextStyle(fontSize: 14)),
                    if (v.ar.isNotEmpty && v.ar != v.tr(lang))
                      pw.Text(
                        v.ar,
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 12),
                      ),
                    if (v.example != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        v.example!.es,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      if (v.example!.en.isNotEmpty)
                        pw.Text(
                          v.example!.en,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      if (v.example!.ar.isNotEmpty)
                        pw.Text(
                          v.example!.ar,
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
    );
  }

  pw.MultiPage _buildGrammarPage(Lesson lesson, _Translations t, String lang) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.grammar,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...lesson.grammar.map(
              (g) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    g.title.tr(lang),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    g.explanation.tr(lang),
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  if (g.examples.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    ...g.examples.map(
                      (ex) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              ex.es,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                            if (ex.en.isNotEmpty)
                              pw.Text(
                                ex.en,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            if (ex.ar.isNotEmpty)
                              pw.Text(
                                ex.ar,
                                textDirection: pw.TextDirection.rtl,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 16),
                ],
              ),
            ),
          ],
    );
  }

  pw.MultiPage _buildDialoguePage(Lesson lesson, _Translations t, String lang) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.dialogue,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...lesson.dialogueLines.map(
              (l) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${l.speaker}:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(l.text.es, style: pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      l.text.en,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      l.text.ar,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),
          ],
    );
  }

  pw.MultiPage _buildReadingPage(Lesson lesson, _Translations t, String lang) {
    final reading = lesson.readingText!;
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.reading,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(reading.es, style: pw.TextStyle(fontSize: 14)),
            if (reading.en.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                reading.en,
                style: pw.TextStyle(fontSize: 13, color: PdfColors.grey600),
              ),
            ],
            if (reading.ar.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                reading.ar,
                style: pw.TextStyle(fontSize: 13, color: PdfColors.grey600),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ],
    );
  }

  pw.MultiPage _buildExercisesPage(
    Lesson lesson,
    _Translations t,
    String lang,
  ) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Text(
              t.exercises,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...lesson.exercises.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${i + 1}. ${e.prompt.es}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (e.type == 'multiple_choice' ||
                        e.type == 'fill_blank' ||
                        e.type == 'listening')
                      ...e.options.map(
                        (o) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            '  ${o.tr(lang)}',
                            style: pw.TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    if (e.type == 'writing' ||
                        e.type == 'translation' ||
                        e.type == 'dictation')
                      pw.Text(
                        '${t.yourAnswer}: _______________',
                        style: pw.TextStyle(fontSize: 13),
                      ),
                    if (e.type == 'speaking')
                      pw.Text(
                        '${t.speakAndRepeat}: ${e.prompt.es}',
                        style: pw.TextStyle(fontSize: 13),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${t.answer}: ${e.answer}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (e.explanation.es.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        e.explanation.tr(lang),
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
    );
  }
}

class _Translations {
  final String lang;
  _Translations(this.lang);

  String get lessonHandout => uiText(
    lang,
    ar: 'ملخص الدرس',
    es: 'Resumen de la lección',
    other: 'Lesson Handout',
  );
  String get objectives =>
      uiText(lang, ar: 'الأهداف', es: 'Objetivos', other: 'Objectives');
  String get vocabulary =>
      uiText(lang, ar: 'المفردات', es: 'Vocabulario', other: 'Vocabulary');
  String get grammar =>
      uiText(lang, ar: 'القواعد', es: 'Gramática', other: 'Grammar');
  String get dialogue =>
      uiText(lang, ar: 'الحوار', es: 'Diálogo', other: 'Dialogue');
  String get reading =>
      uiText(lang, ar: 'القراءة', es: 'Lectura', other: 'Reading');
  String get exercises =>
      uiText(lang, ar: 'التمارين', es: 'Ejercicios', other: 'Exercises');
  String get yourAnswer =>
      uiText(lang, ar: 'إجابتك', es: 'Tu respuesta', other: 'Your answer');
  String get answer =>
      uiText(lang, ar: 'الإجابة', es: 'Respuesta', other: 'Answer');
  String get speakAndRepeat => uiText(
    lang,
    ar: 'تحدث وكرر',
    es: 'Habla y repite',
    other: 'Speak and repeat',
  );
}

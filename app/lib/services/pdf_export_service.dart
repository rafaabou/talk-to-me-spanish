import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import 'package:share_plus/share_plus.dart';

class PdfExportService {
  static final PdfExportService instance = PdfExportService._();
  PdfExportService._();

  Future<String> exportLessonToPdf({
    required String lessonId,
    required AppState appState,
  }) async {
    final lesson = await CourseRepository.instance.tryLoadLesson(lessonId);
    if (lesson == null) throw Exception('Lesson not found: $lessonId');
    final lang = appState.lang;

    final pdf = pw.Document();
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

    // Save to file
    final outputDir = await getApplicationDocumentsDirectory();
    final fileName =
        'PTBR_${lessonId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  Future<void> sharePdf(String filePath) async {
    await Share.shareXFiles([
      XFile(filePath),
    ], text: 'Talk To Me Spanish By Mohamed Rafaa Tounekti - Lesson Handout');
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

  pw.Page _buildObjectivesPage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.objectives,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
          ),
    );
  }

  pw.Page _buildVocabularyPage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.vocabulary,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                      pw.Text(
                        '${v.tr(lang)}${lang == 'en' && v.ar.isNotEmpty ? ' · ${v.ar}' : ''}',
                        style: pw.TextStyle(fontSize: 14),
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
                        pw.Text(
                          lang == 'ar' ? v.example!.ar : v.example!.en,
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
          ),
    );
  }

  pw.Page _buildGrammarPage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.grammar,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                              pw.Text(
                                lang == 'ar' ? ex.ar : ex.en,
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
          ),
    );
  }

  pw.Page _buildDialoguePage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.dialogue,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
          ),
    );
  }

  pw.Page _buildReadingPage(Lesson lesson, _Translations t, String lang) {
    final reading = lesson.readingText!;
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.reading,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
          ),
    );
  }

  pw.Page _buildExercisesPage(Lesson lesson, _Translations t, String lang) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t.exercises,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
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
          ),
    );
  }
}

class _Translations {
  final String lang;
  _Translations(this.lang);

  String get lessonHandout =>
      lang == 'ar'
          ? 'ملخص الدرس'
          : lang == 'es'
          ? 'Resumen de la lección'
          : 'Lesson Handout';
  String get objectives =>
      lang == 'ar'
          ? 'الأهداف'
          : lang == 'es'
          ? 'Objetivos'
          : 'Objectives';
  String get vocabulary =>
      lang == 'ar'
          ? 'المفردات'
          : lang == 'es'
          ? 'Vocabulario'
          : 'Vocabulary';
  String get grammar =>
      lang == 'ar'
          ? 'القواعد'
          : lang == 'es'
          ? 'Gramática'
          : 'Grammar';
  String get dialogue =>
      lang == 'ar'
          ? 'الحوار'
          : lang == 'es'
          ? 'Diálogo'
          : 'Dialogue';
  String get reading =>
      lang == 'ar'
          ? 'القراءة'
          : lang == 'es'
          ? 'Lectura'
          : 'Reading';
  String get exercises =>
      lang == 'ar'
          ? 'التمارين'
          : lang == 'es'
          ? 'Ejercicios'
          : 'Exercises';
  String get yourAnswer =>
      lang == 'ar'
          ? 'إجابتك'
          : lang == 'es'
          ? 'Tu respuesta'
          : 'Your answer';
  String get answer =>
      lang == 'ar'
          ? 'الإجابة'
          : lang == 'es'
          ? 'Respuesta'
          : 'Answer';
  String get speakAndRepeat =>
      lang == 'ar'
          ? 'تحدث وكرر'
          : lang == 'es'
          ? 'Habla y repite'
          : 'Speak and repeat';
}

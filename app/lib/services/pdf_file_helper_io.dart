import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> saveAndSharePdf(List<int> pdfBytes, String fileName) async {
  final outputDir = await getApplicationDocumentsDirectory();
  final file = File('${outputDir.path}/$fileName.pdf');
  await file.writeAsBytes(pdfBytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text:
          'Talk To Me Spanish By Mohamed Rafaa Tounekti - Lesson Handout',
    ),
  );
  return file.path;
}

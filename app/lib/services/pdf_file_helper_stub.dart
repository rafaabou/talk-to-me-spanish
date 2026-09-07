// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> saveAndSharePdf(List<int> pdfBytes, String fileName) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$fileName.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded to browser';
}

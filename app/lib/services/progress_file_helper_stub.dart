import 'dart:html' as html;
import 'dart:convert';

Future<String?> exportToFile(String data) async {
  final bytes = utf8.encode(data);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'eszero_progress.json')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded to browser';
}

Future<String?> readFromFile(String path) async {
  return null;
}

Future<String?> findImportFile() async {
  return null;
}

Future<String?> pickAndReadFile() async {
  final input = html.FileUploadInputElement()..accept = '.json';
  input.click();
  await input.onChange.first;
  if (input.files?.isEmpty ?? true) return null;
  final file = input.files!.first;
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  return reader.result as String?;
}

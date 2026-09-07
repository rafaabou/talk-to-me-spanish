import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> exportToFile(String data) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/eszero_progress.json');
  await file.writeAsString(data);
  return file.path;
}

Future<String?> readFromFile(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (e) {
    return null;
  }
}

Future<String?> findImportFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/eszero_progress.json');
    if (await file.exists()) return file.path;
  } catch (e) {
    // ignore
  }
  return null;
}

Future<String?> pickAndReadFile() async {
  return null;
}

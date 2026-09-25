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

/// There is no system file picker in this build, so "import" restores the
/// last backup this app exported into its documents directory. The UI says so.
Future<String?> pickAndReadFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/eszero_progress.json');
  if (!await file.exists()) return null;
  return readFromFile(file.path);
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';

const String recordingPrefix = 'talktome_user_';
const String recordingSuffix = '.m4a';

Future<String?> newRecordingPath() async {
  try {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$recordingPrefix'
        '${DateTime.now().millisecondsSinceEpoch}$recordingSuffix';
  } catch (_) {
    return null;
  }
}

Future<void> deleteRecording(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    await File(path).delete();
  } catch (_) {}
}

Future<void> cleanupOldRecordings({String? keepPath}) async {
  try {
    final dir = await getTemporaryDirectory();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final p = entity.path;
      if (!p.contains(recordingPrefix) || !p.endsWith(recordingSuffix)) {
        continue;
      }
      if (keepPath != null && p == keepPath) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

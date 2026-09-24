// The web recorder keeps the clip in memory and hands back a blob: URL, so
// there is no filesystem path to allocate, delete, or sweep.
Future<String?> newRecordingPath() async => null;

Future<void> deleteRecording(String? path) async {}

Future<void> cleanupOldRecordings({String? keepPath}) async {}

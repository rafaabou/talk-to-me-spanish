import 'dart:typed_data';

Future<bool> playAssetBytes(
  Uint8List bytes,
  String mimeType,
  double speed,
  int repeat,
) async {
  return false;
}

Future<bool> playAssetUrl(String assetUrl, double speed, int repeat) async {
  return false;
}

Future<void> stopWebAudio() async {}

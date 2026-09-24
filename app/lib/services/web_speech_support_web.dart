import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Firefox ships no SpeechRecognition implementation at all, which makes the
// speech_to_text plugin fail to initialize. Detect that up front so the UI can
// offer record-and-self-check instead of a dead microphone button.
bool get browserSupportsSpeechRecognition =>
    globalContext.has('SpeechRecognition') ||
    globalContext.has('webkitSpeechRecognition');

bool get browserIsSecureContext =>
    (globalContext['isSecureContext'] as JSBoolean?)?.toDart ?? false;

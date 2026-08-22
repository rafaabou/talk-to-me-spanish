import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/services/ui_text.dart';

void main() {
  group('uiText', () {
    test('should_return_arabic_for_lang_ar', () {
      expect(uiText('ar', ar: 'أ', pt: 'p', other: 'e'), 'أ');
    });

    test('should_return_pt_for_lang_pt', () {
      expect(uiText('pt', ar: 'أ', pt: 'p', other: 'e'), 'p');
    });

    test('should_return_es_for_lang_es_when_provided', () {
      expect(uiText('es', es: 's', other: 'e'), 's');
    });

    test('should_fall_back_to_other_for_es_when_missing', () {
      expect(uiText('es', ar: 'أ', pt: 'p', other: 'e'), 'e');
    });

    test('should_return_named_en_when_lang_is_en', () {
      expect(uiText('en', en: 'hello', other: 'x'), 'hello');
    });

    test('should_fall_back_to_other_for_en_when_missing', () {
      expect(uiText('en', ar: 'أ', pt: 'p', other: 'other'), 'other');
    });

    test('should_return_other_for_empty_primary_string', () {
      expect(uiText('ar', ar: '', other: 'fallback'), 'fallback');
    });

    test('should_return_named_en_when_lang_is_en', () {
      expect(uiText('en', en: 'hello', other: 'x'), 'hello');
    });
  });
}

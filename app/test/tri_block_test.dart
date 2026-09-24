import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/widgets/tri_block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(TriText text, AppState state) =>
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TriBlock(text, contentLangOverride: 'es'),
            ),
          ),
        ),
      );

  Future<AppState> makeState({String lang = 'en', bool all = false}) async {
    SharedPreferences.setMockInitialValues({
      'ui_lang': lang,
      'ui_all_languages': all,
    });
    final state = AppState();
    await state.setLang(lang);
    await state.setShowAllLanguages(all);
    return state;
  }

  group('TriBlock language visibility', () {
    final tri = TriText('Buenos días', 'Good morning', 'صباح الخير');

    testWidgets('shows the lesson language and the interface language', (
      tester,
    ) async {
      final state = await makeState(lang: 'en');
      await tester.pumpWidget(wrap(tri, state));

      expect(find.text('Buenos días'), findsOneWidget);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('صباح الخير'), findsNothing);
    });

    testWidgets('arabic interface keeps the arabic line', (tester) async {
      final state = await makeState(lang: 'ar');
      await tester.pumpWidget(wrap(tri, state));

      expect(find.text('Buenos días'), findsOneWidget);
      expect(find.text('صباح الخير'), findsOneWidget);
      expect(find.text('Good morning'), findsNothing);
    });

    testWidgets('show-all-languages reveals every line', (tester) async {
      final state = await makeState(lang: 'en', all: true);
      await tester.pumpWidget(wrap(tri, state));

      expect(find.text('Buenos días'), findsOneWidget);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('صباح الخير'), findsOneWidget);
    });

    testWidgets('never repeats the lesson line as its own translation', (
      tester,
    ) async {
      // The Spanish app has no Portuguese field, so tr() falls back to the
      // course language; that fallback must not be rendered twice.
      final noEnglish = TriText('Buenos días', '', '');
      final state = await makeState(lang: 'en');
      await tester.pumpWidget(wrap(noEnglish, state));
      expect(find.text('Buenos días'), findsOneWidget);
    });

    testWidgets('primary sentence is larger than the translation', (
      tester,
    ) async {
      final state = await makeState(lang: 'en');
      await tester.pumpWidget(wrap(tri, state));

      final primary = tester.widget<Text>(find.text('Buenos días'));
      final secondary = tester.widget<Text>(find.text('Good morning'));
      final primarySize =
          primary.style?.fontSize ??
          Theme.of(
            tester.element(find.text('Buenos días')),
          ).textTheme.titleMedium?.fontSize;
      final secondarySize =
          secondary.style?.fontSize ??
          Theme.of(
            tester.element(find.text('Good morning')),
          ).textTheme.bodyMedium?.fontSize;
      expect(primarySize, greaterThan(secondarySize!));
    });
  });
}

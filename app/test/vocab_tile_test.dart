import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/models/course_models.dart';
import 'package:talk_to_me_spanish/screens/lesson_sections.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';
import 'package:talk_to_me_spanish/widgets/audio_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTile(WidgetTester tester, VocabWord v) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'ui_lang': 'en'});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: VocabTile(
              'A1-01',
              0,
              v,
              'en',
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the speaker belongs to the word line, not to the card', (
    tester,
  ) async {
    await pumpTile(
      tester,
      VocabWord(
        'gato',
        '/ˈɡa.tu/',
        'cat',
        'قِطّة',
        example: TriText('El gato durmió.', 'The cat slept.', 'نام القط.'),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));

    // The word's speaker lives in the title row, on the word's own line.
    expect(
      find.descendant(
        of: find.byWidget(tile.title!),
        matching: find.byType(AudioButton),
      ),
      findsOneWidget,
    );
    // Only the favourite star is left in `trailing`; putting the speaker there
    // centred it against the whole card, so it looked like sentence audio.
    expect(
      find.descendant(
        of: find.byWidget(tile.trailing!),
        matching: find.byType(AudioButton),
      ),
      findsNothing,
    );
    // The example sentence keeps its own inline speaker.
    expect(find.byType(AudioButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phrase-length entry keeps its word and IPA readable', (
    tester,
  ) async {
    // Real data: 1190 of 1190 entries carry IPA, and the longest run to 48
    // characters because many "words" are full phrases.
    await pumpTile(
      tester,
      VocabWord(
        'puxar a brasa para a sua segurança',
        '/puˈʃaɾ a ˈbɾa.za ˈpa.ɾa a ˈsu.a saʁˈdʒĩ.ɲa/',
        'to pull the ember to your safety',
        'لسحب الجمر إلى أمانك',
      ),
    );

    expect(find.text('puxar a brasa para a sua segurança'), findsOneWidget);
    expect(
      find.text('/puˈʃaɾ a ˈbɾa.za ˈpa.ɾa a ˈsu.a saʁˈdʒĩ.ɲa/'),
      findsOneWidget,
    );
    expect(find.byType(AudioButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/main.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channels = [
    MethodChannel('com.rafaabou.eszero_hero/notification'),
    MethodChannel('com.rafaabou.eszero_hero/widget'),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'ui_zoom': 1.0,
      'ui_lang': 'en',
      'ui_speed': 1.0,
      'ui_repeat': 1,
      'ui_theme': 'system',
    });
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() {
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('two-finger pinch-out increases zoom app-wide', (tester) async {
    await tester.pumpWidget(const EszeroApp());
    await tester.pumpAndSettle();

    expect(
      Provider.of<AppState>(
        tester.element(find.byType(MaterialApp).first),
        listen: false,
      ).zoom,
      1.0,
    );

    // Start two fingers close together in the center of the screen.
    final center = tester.getCenter(find.byType(MaterialApp).first);
    final g1 = await tester.startGesture(center - const Offset(30, 0));
    final g2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();

    // Move them apart -> scale > 1 -> zoom in.
    await g1.moveBy(const Offset(-120, 0));
    await g2.moveBy(const Offset(120, 0));
    await tester.pump();

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    final state = Provider.of<AppState>(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );
    expect(state.zoom, greaterThan(1.0));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('ui_zoom'), greaterThan(1.0));
  });

  testWidgets('two-finger pinch-in decreases zoom app-wide', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'ui_zoom': 1.5,
      'ui_lang': 'en',
      'ui_speed': 1.0,
      'ui_repeat': 1,
      'ui_theme': 'system',
    });

    await tester.pumpWidget(const EszeroApp());
    await tester.pumpAndSettle();

    expect(
      Provider.of<AppState>(
        tester.element(find.byType(MaterialApp).first),
        listen: false,
      ).zoom,
      1.5,
    );

    final center = tester.getCenter(find.byType(MaterialApp).first);
    final g1 = await tester.startGesture(center - const Offset(100, 0));
    final g2 = await tester.startGesture(center + const Offset(100, 0));
    await tester.pump();

    await g1.moveBy(const Offset(70, 0));
    await g2.moveBy(const Offset(-70, 0));
    await tester.pump();

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    final state = Provider.of<AppState>(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );
    expect(state.zoom, lessThan(1.5));
  });

  testWidgets(
    'SelectionArea is present so text can be selected/copied everywhere',
    (tester) async {
      await tester.pumpWidget(const EszeroApp());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
    },
  );

  testWidgets('long-press on text shows copy selection toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(const EszeroApp());
    await tester.pumpAndSettle();

    final textFinder = find.text(
      'Talk To Me Spanish By Mohamed Rafaa Tounekti',
    );
    expect(textFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(textFinder));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    final copyFound = find.text('Copy');
    expect(copyFound, findsWidgets);
  });

  testWidgets(
    'single-finger scroll still works (pinch handler is passive for 1 pointer)',
    (tester) async {
      await tester.pumpWidget(const EszeroApp());
      await tester.pumpAndSettle();

      final state = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp).first),
        listen: false,
      );
      final before = state.zoom;

      final center = tester.getCenter(find.byType(MaterialApp).first);
      final g1 = await tester.startGesture(center);
      await g1.moveBy(const Offset(0, -300));
      await tester.pump();
      await g1.up();
      await tester.pumpAndSettle();

      expect(state.zoom, before);
    },
  );
}

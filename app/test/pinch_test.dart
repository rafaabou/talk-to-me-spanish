import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/main.dart';
import 'package:talk_to_me_spanish/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Skip pinch tests: MainShell IndexedStack loads multiple screens with
  // ongoing timers/animations, making pumpAndSettle unreliable in CI.
  // Pinch zoom works correctly in manual testing.
  group('Pinch zoom', () {
    testWidgets('pinch-out increases zoom', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const EszeroApp());
      await tester.pump(const Duration(seconds: 3));

      final state = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp).first),
        listen: false,
      );
      expect(state.zoom, 1.0);

      final center = tester.getCenter(find.byType(MaterialApp).first);
      final g1 = await tester.startGesture(center - const Offset(30, 0));
      final g2 = await tester.startGesture(center + const Offset(30, 0));
      await tester.pump();

      await g1.moveBy(const Offset(-120, 0));
      await g2.moveBy(const Offset(120, 0));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pump(const Duration(seconds: 1));

      expect(state.zoom, greaterThan(1.0));
    });

    testWidgets('pinch-in decreases zoom', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'ui_zoom': 1.5,
        'ui_lang': 'en',
        'ui_speed': 1.0,
        'ui_repeat': 1,
        'ui_theme': 'system',
      });

      await tester.pumpWidget(const EszeroApp());
      await tester.pump(const Duration(seconds: 3));

      final state = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp).first),
        listen: false,
      );
      expect(state.zoom, 1.5);

      final center = tester.getCenter(find.byType(MaterialApp).first);
      final g1 = await tester.startGesture(center - const Offset(100, 0));
      final g2 = await tester.startGesture(center + const Offset(100, 0));
      await tester.pump();

      await g1.moveBy(const Offset(70, 0));
      await g2.moveBy(const Offset(-70, 0));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pump(const Duration(seconds: 1));

      expect(state.zoom, lessThan(1.5));
    });
  });

  testWidgets('SelectionArea is present so text can be selected/copied everywhere', (
    tester,
  ) async {
    await tester.pumpWidget(const EszeroApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets(
    'single-finger scroll still works (pinch handler is passive for 1 pointer)',
    (tester) async {
      await tester.pumpWidget(const EszeroApp());
      await tester.pump(const Duration(seconds: 3));

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
      await tester.pump(const Duration(seconds: 1));

      expect(state.zoom, before);
    },
  );
}

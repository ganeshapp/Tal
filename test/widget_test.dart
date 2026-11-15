import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tal/core/engine_stub.dart';
import 'package:tal/core/store.dart';
import 'package:tal/main.dart';

void main() {
  for (final width in [360.0, 390.0, 1280.0]) {
    testWidgets('Home, practice, journal and settings fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        for (final name in ['Inter', 'Lora']) {
          await (FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
        }
      });
      final store = (await tester.runAsync(AppStore.load))!;
      await tester.pumpWidget(
        TalApp(store: store, engines: PreviewEngines()),
      );
      await tester.pumpAndSettle();
      expect(find.text('New game'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Practice', 'Games', 'Settings', 'Play']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }
}

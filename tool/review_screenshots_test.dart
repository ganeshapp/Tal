import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/screens/puzzles.dart';
import 'package:tal/screens/journal.dart';
import 'package:tal/main.dart';
import 'package:tal/theme.dart';
import '../test/interaction_test.dart' show setup, ControlledEngine, sample;
import 'render_assets_test.dart' show capture;

void main() {
  testWidgets('Capture play setup, review, puzzle solving and dashboard', (
    t,
  ) async {
    final store = await setup(t, const Size(1280, 800));
    await t.runAsync(() async {
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (var i = 0; i < 60; i++) {
      final p = store.puzzles[i];
      store.puzzleProgress.record(
        p,
        success: i % 3 != 0,
        assisted: false,
        mode: 'standard',
        firstExposure: true,
        elapsed: const Duration(seconds: 25),
      );
    }
    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      t.view.physicalSize = size;
      final pages = <String, Widget>{
        'home': TalApp(store: store, engines: ControlledEngine()),
        'review': MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: talTheme(),
          home: AnalysisScreen(
            store: store,
            engines: ControlledEngine(),
            record: sample(),
          ),
        ),
        'puzzles': MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: talTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Puzzles')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PuzzleHub(store: store),
            ),
          ),
        ),
        'puzzle-board': MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: talTheme(),
          home: PuzzleScreen(store: store),
        ),
        'puzzle-dashboard': MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: talTheme(),
          home: PuzzleDashboard(store: store),
        ),
      };
      for (final page in pages.entries) {
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(key: key, child: page.value));
        await t.pumpAndSettle();
        if (page.key == 'review') {
          await t.tap(find.byTooltip('Next key move'));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
        await capture(
          t,
          key,
          'docs/screenshots/${page.key}-${size.width.toInt()}.png',
        );
        await t.pumpWidget(const SizedBox());
        await t.pump();
      }
    }
  });
}

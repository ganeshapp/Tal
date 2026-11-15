import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/openings.dart';
import 'package:tal/screens/training.dart';
import 'package:tal/screens/journal.dart';
import 'package:tal/theme.dart';
import 'interaction_test.dart' show setup, ControlledEngine;

void main() {
  testWidgets(
    'Specific opening search opens a playable line on a narrow phone',
    (t) async {
      final store = await setup(t, const Size(360, 800));
      await t.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: TrainingPage(
            store: store,
            engines: ControlledEngine(),
            initialTab: 1,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Najdorf');
      await t.pumpAndSettle();
      final chosen = openingLibrary.lines.firstWhere(
        (o) => o.name.contains('Najdorf'),
      );
      await t.ensureVisible(find.text(chosen.name));
      await t.tap(find.text(chosen.name));
      await t.pumpAndSettle();
      expect(find.text('Play Black'), findsOneWidget);
      expect(find.text('Play from this opening'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('History filters combine result, color and opening family', (
    t,
  ) async {
    final store = await setup(t, const Size(360, 800));
    for (var i = 0; i < 3; i++) {
      store.games.add(
        GameRecord(
          id: '$i',
          startFen: initialFen,
          date: '2026-11-${13 + i}',
          title: 'Maia',
          rating: i == 1 ? 1900 : 1500,
          humanWhite: i == 0,
          result: i == 2 ? '0-1' : '1-0',
          opening:
              i == 1
                  ? 'Sicilian Defense: Najdorf Variation'
                  : 'French Defense: Knight Variation',
        ),
      );
    }
    await t.pumpWidget(
      MaterialApp(
        theme: talTheme(),
        home: Scaffold(
          body: JournalScreen(store: store, engines: ControlledEngine()),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('All results'));
    await t.pumpAndSettle();
    await t.tap(find.text('Won').last);
    await t.pumpAndSettle();
    expect(find.text('2026-11-14'), findsNothing);
    expect(find.text('2026-11-13'), findsOneWidget);
    await t.tap(find.text('All colors'));
    await t.pumpAndSettle();
    await t.tap(find.text('White').last);
    await t.pumpAndSettle();
    expect(find.text('2026-11-15'), findsNothing);
    await t.tap(find.text('Clear filters'));
    await t.pumpAndSettle();
    await t.tap(find.text('All openings'));
    await t.pumpAndSettle();
    await t.tap(find.text('French Defense').last);
    await t.pumpAndSettle();
    expect(find.text('2026-11-14'), findsNothing);
    expect(find.text('2026-11-15'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

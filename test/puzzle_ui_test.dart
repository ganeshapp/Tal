import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/screens/puzzles.dart';
import 'package:tal/theme.dart';
import 'package:tal/widgets/chess_board.dart';
import 'interaction_test.dart' show setup;

void main() {
  for (final size in [const Size(360, 800), const Size(1280, 800)]) {
    testWidgets('Puzzle controls and dashboard fit ${size.width}', (t) async {
      final store = await setup(t, size);
      for (var i = 0; i < 30; i++) {
        final p = store.puzzles[i];
        store.puzzleProgress.record(
          p,
          success: i % 3 != 0,
          assisted: false,
          mode: 'standard',
          firstExposure: true,
          elapsed: const Duration(seconds: 20),
        );
      }
      await t.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PuzzleHub(store: store),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('+200'));
      await t.pump();
      expect(store.puzzleProgress.offset, 200);
      await t.tap(find.text('Mixed puzzles'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'fork');
      await t.pump();
      await t.tap(find.text('Fork'));
      await t.pumpAndSettle();
      expect(store.puzzleProgress.theme, 'fork');
      await t.tap(find.byTooltip('Puzzle dashboard'));
      await t.pumpAndSettle();
      expect(find.text('Puzzle dashboard'), findsOneWidget);
      await t.tap(find.text('Improve'));
      await t.pumpAndSettle();
      expect(find.textContaining('played ·').first, findsOneWidget);
      await t.tap(find.text('History'));
      await t.pumpAndSettle();
      expect(find.textContaining('Tap an attempt'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
  }
  testWidgets(
    'Hint penalizes only once and completed assisted solve cannot gain rating',
    (t) async {
      final store = await setup(t, const Size(390, 844));
      final p = store.puzzles.firstWhere((p) => (p.rating - 1500).abs() <= 100);
      store.puzzles = [p];
      await t.pumpWidget(
        MaterialApp(theme: talTheme(), home: PuzzleScreen(store: store)),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Hint'));
      await t.pumpAndSettle();
      final rating = store.puzzleProgress.rating.rating;
      expect(rating, lessThan(1500));
      expect(store.puzzleProgress.attempts.length, 1);
      await t.tap(find.text('Hint'));
      await t.pumpAndSettle();
      for (var i = 1; i < p.moves.length; i += 2) {
        t.widget<ChessBoard>(find.byType(ChessBoard)).onMove!(p.moves[i]);
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        await t.pumpAndSettle();
      }
      expect(store.puzzleProgress.rating.rating, rating);
      expect(store.puzzleProgress.attempts.length, 1);
      expect(store.solved, isNot(contains(p.id)));
      await t.tap(find.text('View solution'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Next solution move'));
      await t.pumpAndSettle();
      expect(
        t.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        isNot(p.start().fen),
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final minutes in [3, 5]) {
    testWidgets(
      '$minutes minute Storm starts explicitly and expires on wall time',
      (t) async {
        final store = await setup(t, const Size(390, 844));
        var now = DateTime(2026, 11, 15, 12);
        await t.pumpWidget(
          MaterialApp(
            theme: talTheme(),
            home: PuzzleScreen(
              store: store,
              mode: 'storm',
              minutes: minutes,
              clock: () => now,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(ChessBoard), findsNothing);
        await t.tap(find.text('Start timer'));
        await t.pump();
        expect(find.byType(ChessBoard), findsOneWidget);
        now = now.add(Duration(minutes: minutes));
        await t.pump(const Duration(milliseconds: 120));
        expect(find.text('Storm finished · 0 solved'), findsOneWidget);
        expect(store.puzzleProgress.rating.count, 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
  testWidgets(
    'Exiting during automatic puzzle reply cancels pending transition',
    (t) async {
      final store = await setup(t, const Size(390, 844));
      final p = store.puzzles.firstWhere(
        (p) => (p.rating - 1500).abs() <= 100 && p.moves.length >= 4,
      );
      store.puzzles = [p];
      await t.pumpWidget(
        MaterialApp(theme: talTheme(), home: PuzzleScreen(store: store)),
      );
      await t.pumpAndSettle();
      t.widget<ChessBoard>(find.byType(ChessBoard)).onMove!(p.moves[1]);
      await t.pump();
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );
}

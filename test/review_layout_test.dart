import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/screens/journal.dart';
import 'package:tal/theme.dart';
import 'package:tal/widgets/chess_board.dart';
import 'interaction_test.dart' show setup, ControlledEngine;

GameRecord longGame() {
  // Morphy's Opera Game: enough real, legal moves to exercise scrolling.
  final g = GameRecord(
    id: 'layout',
    date: '2026-11-17',
    title: 'Maia',
    startFen: initialFen,
    result: '1-0',
    moves: [
      'e2e4',
      'e7e5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c8g4',
      'd4e5',
      'g4f3',
      'd1f3',
      'd6e5',
      'f1c4',
      'g8f6',
      'f3b3',
      'd8e7',
      'b1c3',
      'c7c6',
      'c1g5',
      'b7b5',
      'c3b5',
      'c6b5',
      'c4b5',
      'b8d7',
      'e1c1',
      'a8d8',
      'd1d7',
      'd8d7',
      'h1d1',
      'e7e6',
      'b5d7',
      'f6d7',
      'b3b8',
      'd7b8',
      'd1d8',
    ],
  );
  g.reviews.addAll([
    for (var i = 0; i < g.moves.length; i++)
      MoveReview(
        ply: i,
        played: g.moves[i],
        best: g.moves[i],
        label: i == 18 ? 'Great' : 'Good',
        loss: 0,
        beforeCp: 0,
        afterCp: 0,
        depth: 16,
      ),
  ]);
  return g;
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(800, 390),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'Review has a usable move viewport and stays scrollable at $size',
      (t) async {
        final store = await setup(t, size), game = longGame();
        t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(t.view.resetPadding);
        await t.pumpWidget(
          MaterialApp(
            theme: talTheme(),
            home: AnalysisScreen(
              store: store,
              engines: ControlledEngine(),
              record: game,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(game.sans.last, 'Rd8#');
        expect(t.takeException(), isNull);
        final list = find.byKey(const ValueKey('move-list'));
        final rect = t.getRect(list);
        expect(
          rect.height,
          greaterThanOrEqualTo(size.height >= 800 ? 220 : 166),
          reason: 'Leave several complete 44px move rows, not a two-row slit',
        );
        final board = t.getRect(find.byType(ChessBoard));
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('move-ply-27')),
          150,
          scrollable: scrollable,
        );
        await t.pumpAndSettle();
        expect(t.getRect(find.byType(ChessBoard)), board);
        await t.tap(find.byKey(const ValueKey('move-ply-27')));
        await t.pumpAndSettle();
        expect(
          t.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
          game.fenAt(27),
        );
        // Explicit navigation follows the selected row into view.
        await t.tap(find.byTooltip('Start (Home)'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('move-ply-1')).hitTestable(),
          findsOneWidget,
        );
        if (size.width < size.height) {
          await t.tap(find.byTooltip('More room for moves'));
          await t.pumpAndSettle();
          expect(t.getRect(list).height, greaterThan(rect.height + 40));
        }
        await t.tap(find.text('Summary'));
        await t.pumpAndSettle();
        final summary = find.byType(ListView).last;
        await t.scrollUntilVisible(
          find.textContaining('Great'),
          80,
          scrollable: find.descendant(
            of: summary,
            matching: find.byType(Scrollable),
          ),
        );
        await t.pumpAndSettle();
        // The category filter shows matching rows, not a long list of faded moves.
        final row =
            find
                .ancestor(
                  of: find.textContaining('Great').last,
                  matching: find.byType(Row),
                )
                .first;
        await t.tap(find.descendant(of: row, matching: find.text('1')));
        await t.pumpAndSettle();
        expect(find.text('White · Great'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('move-ply-19')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('move-ply-1')), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
    );
  }
}

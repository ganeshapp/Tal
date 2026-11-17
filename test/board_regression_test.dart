import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/screens/game.dart';
import 'package:tal/theme.dart';
import 'package:tal/widgets/chess_board.dart';
import 'interaction_test.dart' show setup, square, sample, ControlledEngine;

bool selected(WidgetTester t, String sq) => t
    .widgetList<Semantics>(find.byType(Semantics))
    .any(
      (w) =>
          w.properties.label?.startsWith('$sq ') == true &&
          w.properties.selected == true,
    );

void main() {
  for (final dragging in [false, true]) {
    testWidgets(
      'Bot reply preserves ${dragging ? 'a held piece' : 'selection'}',
      (t) async {
        final store = await setup(t, const Size(390, 844));
        final engine = ControlledEngine();
        final game =
            sample()
              ..moves.clear()
              ..reviews.clear();
        await t.pumpWidget(
          MaterialApp(
            theme: talTheme(),
            home: GameScreen(store: store, engines: engine, record: game),
          ),
        );
        await t.pumpAndSettle();
        await t.tapAt(square(t, 'e2'));
        await t.pump();
        await t.tapAt(square(t, 'e4'));
        await t.pumpAndSettle();
        TestGesture? gesture;
        if (dragging) {
          gesture = await t.startGesture(square(t, 'g1'));
          await gesture.moveBy(const Offset(5, -5));
        } else {
          await t.tapAt(square(t, 'g1'));
        }
        await t.pump();
        expect(selected(t, 'g1'), true);
        engine.replies.first.complete('e7e5');
        await t.pumpAndSettle();
        expect(selected(t, 'g1'), true);
        if (gesture != null) {
          expect(find.byKey(const ValueKey('dragged-piece')), findsOneWidget);
          await gesture.moveTo(square(t, 'f3'));
          await gesture.up();
        } else {
          await t.tapAt(square(t, 'f3'));
        }
        await t.pumpAndSettle();
        expect(game.moves, ['e2e4', 'e7e5', 'g1f3']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('A captured selection and interrupted drag are cleared safely', (
    t,
  ) async {
    final store = await setup(t, const Size(390, 844));
    final engine = ControlledEngine();
    final game = GameRecord(
      id: 'capture',
      date: '2026-11-17',
      title: 'Maia',
      startFen: '4k3/8/8/3p4/2B5/8/6PP/6K1 b - - 0 1',
    );
    await t.pumpWidget(
      MaterialApp(
        theme: talTheme(),
        home: GameScreen(store: store, engines: engine, record: game),
      ),
    );
    await t.pumpAndSettle();
    final gesture = await t.startGesture(square(t, 'c4'));
    await gesture.moveBy(const Offset(6, 0));
    await t.pump();
    expect(selected(t, 'c4'), true);
    engine.replies.single.complete('d5c4');
    await t.pumpAndSettle();
    expect(selected(t, 'c4'), false);
    expect(find.byKey(const ValueKey('dragged-piece')), findsNothing);
    await gesture.moveTo(square(t, 'e6'));
    await gesture.up();
    await t.pumpAndSettle();
    expect(game.moves, ['d5c4']);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Drag follows the grab point, keeps its size, and lands without a replay animation',
    (t) async {
      await setup(t, const Size(500, 700));
      final pos = ChessPosition();
      String? last;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder:
                  (_, set) => Center(
                    child: SizedBox(
                      width: 400,
                      child: ChessBoard(
                        position: pos,
                        lastMove: last,
                        onMove:
                            (move) => set(() {
                              pos.play(move);
                              last = move;
                            }),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final piece = find.byKey(const ValueKey('board-piece-e2'));
      final rect = t.getRect(piece);
      final grab = rect.center + const Offset(9, 7);
      final gesture = await t.startGesture(grab);
      await gesture.moveBy(const Offset(4, -3));
      await t.pump();
      final overlay = find.byKey(const ValueKey('dragged-piece'));
      expect(t.getRect(overlay).size, rect.size);
      expect(t.getRect(overlay).topLeft, rect.topLeft + const Offset(4, -3));
      final staticPiece = t.widget(piece);
      await gesture.moveBy(const Offset(4, -3));
      await t.pump();
      expect(
        identical(t.widget(piece), staticPiece),
        true,
        reason: 'Pointer frames must not rebuild the static board',
      );
      final target = square(t, 'e4');
      await gesture.moveTo(target);
      await gesture.up();
      await t.pump();
      expect(last, 'e2e4');
      expect(find.byKey(const ValueKey('dragged-piece')), findsNothing);
      final landed = find.byKey(const ValueKey('board-piece-e4'));
      expect(t.getRect(landed).center, target);
      await t.pump(const Duration(milliseconds: 60));
      expect(t.getRect(landed).center, target);
      expect(t.takeException(), isNull);
    },
  );
}

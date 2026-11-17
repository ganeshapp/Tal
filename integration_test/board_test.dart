import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine.dart';
import 'package:tal/core/store.dart';
import 'package:tal/screens/game.dart';
import 'package:tal/theme.dart';
import 'package:tal/widgets/chess_board.dart';

Offset square(WidgetTester t, String name) {
  final r = t.getRect(find.byType(ChessBoard));
  return r.topLeft +
      Offset(
        (name.codeUnitAt(0) - 97 + .5) * r.width / 8,
        (8 - int.parse(name[1]) + .5) * r.height / 8,
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Selection and drag remain responsive while native Maia replies', (
    t,
  ) async {
    final engines = createEngines();
    final store = await AppStore.load();
    store.naturalDelay = true;
    store.evaluation = 'off';
    final game = GameRecord(
      id: 'native-ui-check',
      date: '2026-11-17',
      title: 'Maia',
      rating: 1900,
      startFen: initialFen,
    );
    // Warm inference so this measures board interaction rather than model loading.
    await engines.choose(game);
    await t.pumpWidget(
      MaterialApp(
        theme: talTheme(),
        home: GameScreen(store: store, engines: engines, record: game),
      ),
    );
    await t.pumpAndSettle();
    await t.tapAt(square(t, 'e2'));
    await t.pump();
    await t.tapAt(square(t, 'e4'));
    await t.pump();
    await t.tapAt(square(t, 'g1'));
    await t.pump();
    for (var i = 0; i < 200 && game.moves.length < 2; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(game.moves.length, 2);
    expect(
      t
          .widgetList<Semantics>(find.byType(Semantics))
          .any(
            (w) =>
                w.properties.label == 'g1 N' && w.properties.selected == true,
          ),
      true,
    );
    await t.tapAt(square(t, 'f3'));
    await t.pump();
    expect(game.moves.last, 'g1f3');
    // Do not let a second random engine reply contaminate the gesture trace.
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await engines.dispose();

    final pos = ChessPosition();
    String? last;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder:
                    (_, set) => ChessBoard(
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
    // Drain timings from screen setup before measuring the gesture itself.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> timing) => frames.addAll(timing);
    SchedulerBinding.instance.addTimingsCallback(record);
    final from = square(t, 'e2'), to = square(t, 'e4');
    final gesture = await t.startGesture(from);
    for (var i = 1; i <= 60; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 60)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    SchedulerBinding.instance.removeTimingsCallback(record);
    expect(last, 'e2e4');
    expect(
      (t.getRect(find.byKey(const ValueKey('board-piece-e4'))).center - to)
          .distance,
      lessThan(.01),
    );
    expect(t.takeException(), isNull);
    expect(frames.length, greaterThan(20));
    final builds =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final rasters =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    debugPrint(
      'DRAG_FRAMES count=${frames.length} build_p95_ms=${builds[(builds.length * .95).floor()]} raster_p95_ms=${rasters[(rasters.length * .95).floor()]}',
    );
  });
}

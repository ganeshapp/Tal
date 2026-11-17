import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_types.dart';
import 'package:tal/core/store.dart';
import 'package:tal/screens/game.dart';
import 'package:tal/screens/journal.dart';
import 'package:tal/widgets/chess_board.dart';
import 'package:tal/widgets/chess_controls.dart';
import 'package:tal/theme.dart';

class ControlledEngine implements EngineService {
  final replies = <Completer<String>>[];
  Completer<Evaluation>? pendingAnalysis;
  @override
  bool get nativeSupported => true;
  @override
  Future<String> choose(GameRecord record) {
    final c = Completer<String>();
    replies.add(c);
    return c.future;
  }

  @override
  Future<Evaluation> evaluate(
    GameRecord record, {
    int? ply,
    int depth = 14,
  }) async {
    if (pendingAnalysis != null) return pendingAnalysis!.future;
    final pos = record.position(ply), terminal = terminalEvaluation(pos);
    if (terminal != null) return terminal;
    final moves = pos.legal.take(3).toList();
    return Evaluation(
      moves.map((m) => EngineLine(cp: 30, depth: 16, moves: [m])).toList(),
      moves.first,
    );
  }

  @override
  Future<void> dispose() async {}
}

GameRecord sample() => GameRecord(
  id: 'game',
  startFen: initialFen,
  date: '2026-11-15',
  title: 'Maia',
  rating: 1900,
  moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
  reviews: [
    for (var i = 0; i < 4; i++)
      MoveReview(
        ply: i,
        played: ['e2e4', 'e7e5', 'g1f3', 'b8c6'][i],
        best: ['e2e4', 'e7e5', 'g1f3', 'b8c6'][i],
        label: i == 2 ? 'Mistake' : 'Best',
        loss: i == 2 ? 12 : 0,
        beforeCp: 25,
        afterCp: i == 2 ? -120 : 25,
        depth: 16,
      ),
  ],
);
Future<AppStore> setup(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  return (await t.runAsync(() async {
      for (final name in ['Inter', 'Lora']) {
        await (FontLoader(name)
          ..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
      }
      return AppStore.load();
    }))!
    ..naturalDelay = false;
}

Offset square(WidgetTester t, String name, {bool flipped = false}) {
  final rect = t.getRect(find.byType(ChessBoard));
  final f = name.codeUnitAt(0) - 97, r = int.parse(name[1]) - 1;
  return rect.topLeft +
      Offset(
        ((flipped ? 7 - f : f) + .5) * rect.width / 8,
        ((flipped ? r : 7 - r) + .5) * rect.height / 8,
      );
}

void main() {
  testWidgets(
    'Click moves, immediate drag, illegal drops, flipped board and promotion',
    (t) async {
      await setup(t, const Size(500, 700));
      var pos = ChessPosition();
      String? played;
      var flipped = false;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return Center(
                  child: SizedBox(
                    width: 400,
                    child: ChessBoard(
                      position: pos,
                      flipped: flipped,
                      onMove: (m) {
                        played = m;
                        set(() => pos.play(m));
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tapAt(square(t, 'e2'));
      await t.pump();
      await t.tapAt(square(t, 'e4'));
      await t.pumpAndSettle();
      expect(played, 'e2e4');
      final gesture = await t.startGesture(square(t, 'e7'));
      await gesture.moveTo(square(t, 'e5'));
      await t.pump();
      await gesture.up();
      await t.pumpAndSettle();
      expect(played, 'e7e5');
      played = null;
      final invalid = await t.startGesture(square(t, 'a1'));
      await invalid.moveTo(square(t, 'a8'));
      await invalid.up();
      await t.pumpAndSettle();
      expect(played, isNull);
      update(() => flipped = true);
      await t.pumpAndSettle();
      await t.tapAt(square(t, 'g1', flipped: true));
      await t.pump();
      await t.tapAt(square(t, 'f3', flipped: true));
      await t.pumpAndSettle();
      expect(played, 'g1f3');
      update(() {
        pos = ChessPosition(fen: '4k3/P7/8/8/8/8/8/4K3 w - - 0 1');
        flipped = false;
      });
      await t.pumpAndSettle();
      await t.tapAt(square(t, 'a7'));
      await t.pump();
      await t.tapAt(square(t, 'a8'));
      await t.pumpAndSettle();
      expect(find.text('Promote to'), findsOneWidget);
      await t.tap(find.byTooltip('knight'));
      await t.pumpAndSettle();
      expect(played, 'a7a8n');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Premove executes only after bot reply and takeback clears pending replies',
    (t) async {
      final store = await setup(t, const Size(390, 844)),
          engine = ControlledEngine();
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
      expect(engine.replies.length, 1);
      await t.tapAt(square(t, 'g1'));
      await t.pump();
      await t.tapAt(square(t, 'f3'));
      await t.pumpAndSettle();
      expect(find.text('Premove queued'), findsOneWidget);
      engine.replies.first.complete('e7e5');
      await t.pumpAndSettle();
      expect(game.moves, ['e2e4', 'e7e5', 'g1f3']);
      await t.tap(find.byTooltip('Take back'));
      await t.pumpAndSettle();
      expect(game.moves, ['e2e4', 'e7e5']);
      engine.replies.last.complete('b8c6');
      await t.pumpAndSettle();
      expect(game.moves, ['e2e4', 'e7e5']);
      expect(t.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    testWidgets('Review graph, key moves, autoplay and exploration fit $size', (
      t,
    ) async {
      final store = await setup(t, size),
          engine = ControlledEngine(),
          game = sample();
      store.games = [game];
      await t.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: AnalysisScreen(store: store, engines: engine, record: game),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ChessBoard), findsOneWidget);
      await t.tap(find.text('Summary').first);
      await t.pumpAndSettle();
      final graph = t.getRect(find.byType(EvaluationGraph));
      await t.tapAt(Offset(graph.right - 1, graph.center.dy));
      await t.pumpAndSettle();
      expect(
        t.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        game.fenAt(4),
      );
      await t.tap(find.byTooltip('Next key move'));
      await t.pumpAndSettle();
      expect(find.textContaining('Mistake').first, findsOneWidget);
      final boardRect = t.getRect(find.byType(ChessBoard)),
          feedback = t.getRect(find.textContaining('Nf3  ?'));
      expect(boardRect.bottom, lessThan(size.height));
      expect(feedback.bottom, lessThan(size.height));
      await t.tap(find.byTooltip('Start (Home)'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Autoplay (Space)'));
      await t.pump(const Duration(milliseconds: 1150));
      expect(
        t.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        game.fenAt(1),
      );
      await t.tap(find.byTooltip('Pause (Space)'));
      await t.pumpAndSettle();
      // Explore Sicilian from the position after e4; main game is untouched.
      await t.tapAt(square(t, 'c7'));
      await t.pump();
      await t.tapAt(square(t, 'c5'));
      await t.pumpAndSettle();
      expect(find.text('Game'), findsOneWidget);
      expect(game.moves, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
      await t.tap(find.text('Game'));
      await t.pumpAndSettle();
      expect(
        t.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        game.fenAt(1),
      );
      await t.tap(find.text('Engine').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Depth 16'), findsOneWidget);
      await t.tap(find.text('Summary').first);
      await t.pumpAndSettle();
      expect(find.text('Move quality'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
  testWidgets(
    'Checkmate result and review action are visible beside a full White eval',
    (t) async {
      final store = await setup(t, const Size(390, 844)),
          engine = ControlledEngine();
      final game = GameRecord(
        id: 'mate',
        startFen: '2k1N3/1p2Q3/8/qppB2B1/p6N/2P4P/PP4P1/R3R1K1 w - - 0 35',
        date: '2026-11-15',
        title: 'Maia',
        moves: ['e7b7'],
        result: '1-0',
      );
      await t.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: GameScreen(store: store, engines: engine, record: game),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Checkmate'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(t.widget<EvaluationBar>(find.byType(EvaluationBar)).cp, 100000);
      expect(t.getRect(find.text('Review')).bottom, lessThan(844));
      expect(t.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_types.dart';
import 'package:tal/core/store.dart';
import 'package:tal/screens/game.dart';
import 'package:tal/screens/training.dart';
import 'package:tal/theme.dart';
import 'package:tal/widgets/chess_board.dart';

class FakeEngines implements EngineService {
  Completer<String>? reply;
  @override
  bool get nativeSupported => true;
  @override
  Future<String> choose(GameRecord record) =>
      reply?.future ?? Future.value('e7e5');
  @override
  Future<Evaluation> evaluate(
    GameRecord record, {
    int? ply,
    int depth = 14,
  }) async => const Evaluation([
    EngineLine(cp: 25, depth: 14, moves: ['e2e4']),
  ], 'e2e4');
  @override
  Future<void> dispose() async {}
}

void main() {
  Future<AppStore> setup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    return (await tester.runAsync(() async {
        for (final font in ['Inter', 'Lora']) {
          await (FontLoader(font)
            ..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
        }
        return AppStore.load();
      }))!
      ..naturalDelay = false;
  }

  testWidgets(
    'Moves persist, undo cancels the pending opponent, restored game matches',
    (tester) async {
      final store = await setup(tester);
      final engines = FakeEngines()..reply = Completer<String>();
      final record = GameRecord(
        id: 'game',
        startFen: initialFen,
        date: '2026-11-15',
        title: 'Maia 1500',
      );
      store.active = record;
      await tester.pumpWidget(
        MaterialApp(
          theme: talTheme(),
          home: GameScreen(store: store, engines: engines, record: record),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<ChessBoard>(find.byType(ChessBoard)).onMove!('e2e4');
      await tester.pump();
      expect(record.moves, ['e2e4']);
      await tester.tap(find.byTooltip('Take back'));
      await tester.pump();
      expect(record.moves, isEmpty);
      engines.reply!.complete('e7e5');
      await tester.pumpAndSettle();
      expect(record.moves, isEmpty);
      engines.reply = null;
      tester.widget<ChessBoard>(find.byType(ChessBoard)).onMove!('e2e4');
      await tester.pumpAndSettle();
      expect(record.moves, ['e2e4', 'e7e5']);
      var persisted = false;
      store.save().then((_) => persisted = true);
      // Platform messages complete in the real zone; drain both clocks.
      for (var i = 0; i < 50 && !persisted; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      expect(persisted, isTrue);
      final loaded = (await tester.runAsync(AppStore.load))!;
      expect(loaded.active!.position().fen, record.position().fen);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Puzzle applies setup move, plays replies, records only unaided success',
    (tester) async {
      final store = await setup(tester);
      final puzzle = store.puzzles.firstWhere(
        (p) => (p.rating - 1500).abs() <= 100,
      );
      store.puzzles = [puzzle];
      await tester.pumpWidget(
        MaterialApp(theme: talTheme(), home: PuzzleScreen(store: store)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        puzzle.start().fen,
      );
      for (var i = 1; i < puzzle.moves.length; i += 2) {
        tester.widget<ChessBoard>(find.byType(ChessBoard)).onMove!(
          puzzle.moves[i],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }
      expect(store.solved, contains(puzzle.id));
      expect(find.text('Next puzzle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Leaving a running Storm cancels its timers safely', (
    tester,
  ) async {
    final store = await setup(tester);
    store.puzzles = [
      store.puzzles.firstWhere((p) => (p.rating - 600).abs() <= 100),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: talTheme(),
        home: PuzzleScreen(store: store, mode: 'storm'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start timer'));
    await tester.pump();
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    board.onMove!(store.puzzles.first.moves[1]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

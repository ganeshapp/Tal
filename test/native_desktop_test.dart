import 'dart:io';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Packaged macOS engines play, analyze, and preserve mate results',
    () async {
      final engine = NativeEngines();
      addTearDown(engine.dispose);
      final game = GameRecord(
        id: 'native',
        startFen: initialFen,
        date: '2026-11-15',
        title: 'Maia',
        rating: 2000,
        moves: ['e2e4', 'e7e5', 'g1f3'],
      );
      final move = await engine.choose(game);
      expect(game.position().legal, contains(move));
      final e = await engine.evaluate(game, depth: 16);
      expect(e.lines.length, 3);
      expect(e.depth, greaterThanOrEqualTo(12));
      expect(game.position().legal, contains(e.best));
      final mate = GameRecord(
        id: 'mate',
        startFen: '2k1N3/1p2Q3/8/qppB2B1/p6N/2P4P/PP4P1/R3R1K1 w - - 0 35',
        date: '2026-11-15',
        title: 'Maia',
        moves: ['e7b7'],
      );
      final terminal = await engine.evaluate(mate);
      expect(terminal.cp, 100000);
      expect(terminal.mate, 0);
    },
    skip:
        !Platform.isMacOS ||
        !Platform.environment.containsKey('TAL_ENGINE_DIR'),
  );
}

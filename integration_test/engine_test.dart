import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:integration_test/integration_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Bundled Maia models and Stockfish work without network', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Tal · checking offline engines')),
      ),
    );
    final engines = createEngines();
    expect(engines.nativeSupported, isTrue);
    for (final rating in [600, 1500, 1600, 1700, 1800, 1900, 2000, 2600]) {
      final record = GameRecord(
        id: 'test',
        startFen: initialFen,
        date: '2026-11-15',
        title: 'Maia $rating',
        rating: rating,
        moves: ['e2e4', 'e7e5', 'g1f3'],
      );
      final timer = Stopwatch()..start();
      final move = await engines.choose(record);
      expect(record.position().legal, contains(move));
      debugPrint('MAIA $rating: $move in ${timer.elapsedMilliseconds}ms');
    }
    final record = GameRecord(
      id: 'observer',
      startFen: initialFen,
      date: '2026-11-15',
      title: 'test',
      moves: ['e2e4', 'e7e5'],
    );
    final evaluation = await engines.evaluate(record, depth: 16);
    expect(evaluation.lines.length, 3);
    expect(evaluation.depth, greaterThanOrEqualTo(8));
    expect(record.position().legal, contains(evaluation.best));
    debugPrint(
      'STOCKFISH: ${evaluation.best}, cp ${evaluation.cp}, depth ${evaluation.depth}, MultiPV ${evaluation.lines.length}',
    );
    final mate = GameRecord(
      id: 'mate',
      startFen: '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1',
      date: '2026-11-15',
      title: 'test',
    );
    final result = await engines.evaluate(mate, depth: 16);
    expect(result.mate, 1);
    expect(result.cp, 100000);
    debugPrint('STOCKFISH mate: ${result.best} M${result.mate}');
    mate.moves.add(result.best);
    final terminal = await engines.evaluate(mate);
    expect(terminal.cp, 100000);
    expect(winningChances(terminal.cp), 100);
    expect(terminal.mate, 0);
    // This catches process-wide stdin/stdout interference between native plugins.
    final mixed = await Future.wait([
      engines.choose(record),
      engines.evaluate(record),
    ]);
    expect(record.position().legal, contains(mixed.first));
    expect((mixed.last as Evaluation).lines, isNotEmpty);
    debugPrint('CONCURRENT Maia + Stockfish: passed');
    await engines.dispose();
  });
}

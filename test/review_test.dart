import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_types.dart';
import 'package:tal/core/review.dart';
import 'package:tal/core/analysis_tree.dart';

GameRecord game({String fen = initialFen, List<String>? moves}) => GameRecord(
  id: 'test',
  startFen: fen,
  date: '2026-11-15',
  title: 'Maia',
  moves: moves,
);
Evaluation score(int cp, String best) => Evaluation([
  EngineLine(cp: cp, depth: 16, moves: [best]),
], best);
void main() {
  test('Reported Qxb7# is a win, 100% White, Best, zero loss', () {
    final g = game(
      fen: '2k1N3/1p2Q3/8/qppB2B1/p6N/2P4P/PP4P1/R3R1K1 w - - 0 35',
      moves: ['e7b7'],
    );
    expect(g.sans.single, 'Qxb7#');
    expect(g.position().result, '1-0');
    final terminal = terminalEvaluation(g.position())!;
    expect(terminal.cp, 100000);
    expect(terminal.mate, 0);
    expect(winningChances(terminal.cp), 100);
    final review = reviewMove(
      g,
      0,
      score(100000, 'e7b7'),
      const Evaluation([], ''),
    );
    expect(review.label, 'Best');
    expect(review.loss, 0);
    expect(review.afterCp, 100000);
    expect(review.depth, 16);
    expect(review.best, review.played);
  });
  test('Black mate and all drawn terminal positions have exact results', () {
    final black = game(moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(winningChances(terminalEvaluation(black.position())!.cp), 0);
    expect(
      reviewMove(
        black,
        3,
        score(-100000, 'd8h4'),
        const Evaluation([], ''),
      ).label,
      'Best',
    );
    final stalemate = game(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(stalemate.position().result, '1/2-1/2');
    expect(terminalEvaluation(stalemate.position())!.cp, 0);
    final repeated = game(
      moves: ['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1', 'f6g8'],
    );
    expect(repeated.position().over, true);
    expect(terminalEvaluation(repeated.position())!.cp, 0);
  });
  test(
    'Playing the engine best move cannot become a loss from search drift',
    () {
      final g = game(moves: ['e2e4']);
      final r = reviewMove(g, 0, score(250, 'e2e4'), score(-50, 'e7e5'));
      expect(r.loss, 0);
      expect(r.label, 'Best');
    },
  );
  test(
    'Cached boards and notation invalidate after takeback and replacement',
    () {
      final g = game(moves: ['e2e4', 'e7e5']);
      expect(g.sans, ['e4', 'e5']);
      g.moves.removeLast();
      g.moves.add('c7c5');
      expect(g.sans, ['e4', 'c5']);
      expect(g.fenAt(2), g.position().fen);
      g.moves.clear();
      expect(g.fenAt(0), initialFen);
      expect(g.sans, isEmpty);
    },
  );
  test(
    'Variations branch, retain siblings, navigate and leave main game intact',
    () {
      final g = game(moves: ['e2e4', 'e7e5', 'g1f3']);
      final t = AnalysisTree(g);
      final sicilian = t.extend(t.mainline[1], 'c7c5')!;
      final knight = t.extend(sicilian, 'g1f3')!;
      expect(t.recordAt(knight).moves, ['e2e4', 'c7c5', 'g1f3']);
      expect(knight.parent, sicilian);
      expect(t.mainline[1].children.length, 2);
      expect(t.extend(t.mainline[1], 'c7c5'), same(sicilian));
      expect(t.extend(sicilian, 'a1a8'), isNull);
      expect(g.moves, ['e2e4', 'e7e5', 'g1f3']);
    },
  );
}

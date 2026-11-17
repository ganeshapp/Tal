import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_types.dart';
import 'package:tal/core/review.dart';
import 'package:tal/core/analysis_tree.dart';
import 'package:tal/core/openings.dart';

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
  tearDown(() => openingLibrary.load([]));
  test('Reported h3 and castling do not inherit a sacrifice from Bxf3', () {
    for (final example in [
      (
        'r2qk1nr/pppnbpp1/3pp3/7p/3PP1b1/2P2N2/PP2BPPP/RNBQ1RK1 w kq - 2 7',
        'h2h3',
      ),
      (
        'r2qkbnr/pppn1pp1/3pp3/7p/3PP1b1/2P2N2/PP2BPPP/RNBQK2R w KQkq - 0 6',
        'e1g1',
      ),
    ]) {
      final g = game(fen: example.$1, moves: [example.$2]);
      final r = reviewMove(
        g,
        0,
        score(100, example.$2),
        const Evaluation([
          EngineLine(cp: 95, depth: 16, moves: ['g4f3', 'e2f3']),
        ], 'g4f3'),
      );
      expect(r.label, isNot('Brilliant'), reason: g.sans.single);
    }
  });
  test(
    'An offered piece with an equal recapture is not Brilliant, even with a truncated PV',
    () {
      // Bd5 Bxd5 Rxd5 is a trade, even if the supplied PV ends at ...Bxd5.
      final exchange = game(
        fen: '4k3/8/2b5/8/2B5/8/6PP/3R2K1 w - - 0 1',
        moves: ['c4d5'],
      );
      final r = reviewMove(exchange, 0, score(50, 'c4d5'), score(50, 'c6d5'));
      expect(r.label, 'Best');
    },
  );
  test(
    'A sound quiet piece offer can qualify; weak and shallow offers cannot',
    () {
      final g = game(
        fen: '4k3/8/2p5/8/2B5/8/6PP/3R2K1 w - - 0 1',
        moves: ['c4d5'],
      );
      expect(
        reviewMove(g, 0, score(50, 'c4d5'), score(50, 'c6d5')).label,
        'Brilliant',
      );
      expect(
        reviewMove(g, 0, score(50, 'c4d5'), score(-300, 'c6d5')).label,
        isNot('Brilliant'),
      );
      expect(
        reviewMove(
          g,
          0,
          score(50, 'c4d5'),
          const Evaluation([
            EngineLine(cp: 50, depth: 8, moves: ['c6d5']),
          ], 'c6d5'),
        ).label,
        isNot('Brilliant'),
      );
      // A barely acceptable move outside the engine's candidate lines is not
      // promoted to Brilliant just because the later score drifted upward.
      expect(
        reviewMove(g, 0, score(50, 'c4b5'), score(50, 'c6d5')).label,
        isNot('Brilliant'),
      );
    },
  );
  test('A sound bishop sacrifice accounts for the pawn captured first', () {
    final g = game(
      fen: 'r1bq1rk1/ppp2ppp/2nbpn2/3pP3/3P4/2PB1N2/PP3PPP/RNBQK2R w KQ - 0 6',
      moves: ['d3h7'],
    );
    expect(
      reviewMove(g, 0, score(80, 'd3h7'), score(80, 'g8h7')).label,
      'Brilliant',
    );
  });
  test('Sacrifice accounting is symmetric for Black', () {
    final g = game(
      fen: '3r2k1/6pp/8/2b5/8/2P5/8/4K3 b - - 0 1',
      moves: ['c5d4'],
    );
    expect(
      reviewMove(g, 0, score(-50, 'c5d4'), score(-50, 'c3d4')).label,
      'Brilliant',
    );
  });
  test(
    'Ponziani c3 is Book, with its name and the actual engine score retained',
    () {
      openingLibrary.load(
        jsonDecode(File('assets/data/openings.json').readAsStringSync()),
        book: jsonDecode(
          File('assets/data/opening_book.json').readAsStringSync(),
        ),
      );
      final g = game(moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'c2c3']);
      final r = reviewMove(g, 4, score(55, 'f1b5'), score(-20, 'd7d5'));
      expect(r.label, 'Book');
      expect(r.opening, contains('Ponziani'));
      expect(r.afterCp, -20);
      expect(r.loss, greaterThan(5));
    },
  );
  test(
    'An old cached Brilliant label is invalidated without losing game moves',
    () {
      final g = game(moves: ['e2e4']);
      g.reviews.add(reviewMove(g, 0, score(20, 'e2e4'), score(20, 'e7e5')));
      final saved = g.toJson();
      expect(GameRecord.fromJson(saved).reviews.length, 1);
      saved.remove('reviewVersion');
      final restored = GameRecord.fromJson(saved);
      expect(restored.moves, ['e2e4']);
      expect(restored.reviews, isEmpty);
    },
  );
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

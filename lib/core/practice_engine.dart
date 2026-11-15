import 'dart:math';
import 'package:bishop/bishop.dart' as b;
import 'package:flutter/foundation.dart';
import 'chess.dart';
import 'engine_types.dart';

Future<Evaluation> practiceEvaluation(GameRecord record, {int? ply}) async {
  final result = await compute(_search, {
    'fen': record.position(ply).fen,
    'chess960': record.chess960,
  });
  final lines =
      (result['lines'] as List)
          .map(
            (l) =>
                EngineLine(cp: l['cp'], depth: 2, moves: [l['move'] as String]),
          )
          .toList();
  return Evaluation(lines, lines.isEmpty ? '' : lines.first.moves.first);
}

Map<String, dynamic> _search(Map<String, dynamic> input) {
  final game = b.Game(
    fen: input['fen'],
    variant: input['chess960'] == true ? b.Variant.chess960() : null,
  );
  final white = game.turn == b.Bishop.white;
  final scored = <Map<String, dynamic>>[];
  for (final move in game.generateLegalMoves()) {
    final uci = game.toAlgebraic(move);
    game.makeMove(move);
    var score = _static(game);
    final replies = game.generateLegalMoves();
    if (replies.isNotEmpty) {
      score = white ? 100000 : -100000;
      for (final reply in replies) {
        game.makeMove(reply);
        final value = _static(game);
        game.undo();
        score = white ? min(score, value) : max(score, value);
      }
    }
    game.undo();
    scored.add({'move': uci, 'cp': score});
  }
  scored.sort(
    (a, b) =>
        white
            ? (b['cp'] as int).compareTo(a['cp'])
            : (a['cp'] as int).compareTo(b['cp']),
  );
  return {'lines': scored.take(3).toList()};
}

int _static(b.Game game) {
  if (game.gameOver) {
    if (game.drawn) return 0;
    return game.turn == b.Bishop.white ? -100000 : 100000;
  }
  var score = material(game.fen);
  for (final e in piecesFromFen(game.fen).entries) {
    final p = e.value;
    final white = p == p.toUpperCase();
    final file = e.key.codeUnitAt(0) - 97;
    final rank = int.parse(e.key[1]) - 1;
    final center = (3.5 - (file - 3.5).abs()) + (3.5 - (rank - 3.5).abs());
    final bonus =
        (center * (p.toLowerCase() == 'n' ? 12 : 4)).round() +
        (p.toLowerCase() == 'p' ? (white ? rank : 7 - rank) * 7 : 0);
    score += (white ? 1 : -1) * bonus;
  }
  return score;
}

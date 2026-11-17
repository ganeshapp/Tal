import 'dart:math';
import 'chess.dart';
import 'engine_types.dart';
import 'openings.dart';

MoveReview reviewMove(
  GameRecord game,
  int ply,
  Evaluation before,
  Evaluation searchedAfter,
) {
  final position = game.boardAt(ply);
  final next = game.position(ply + 1);
  final terminal = terminalEvaluation(next);
  final after = terminal ?? searchedAfter;
  final sign = position.whiteTurn ? 1 : -1;
  final beforeWp = winningChances(sign * before.cp);
  final afterWp = winningChances(sign * after.cp);
  final played = game.moves[ply];
  final book =
      !game.chess960 && openingLibrary.containsMove(position.fen, played);
  final mating =
      next.over &&
      next.result != '1/2-1/2' &&
      ((next.result == '1-0') == position.whiteTurn);
  // Search depth changes can move the evaluation even when the best move is played.
  final loss =
      mating || played == before.best ? 0.0 : max(0.0, beforeWp - afterWp);
  final second = before.lines.length > 1 ? before.lines[1] : null;
  final only =
      played == before.best &&
      before.depth >= 16 &&
      second != null &&
      second.depth == before.depth &&
      beforeWp - winningChances(sign * second.cp) >= 20;
  final sacrifice =
      !book &&
      !mating &&
      _soundSacrifice(
        position,
        next,
        played,
        before,
        after,
        loss,
        beforeWp,
        afterWp,
      );
  return MoveReview(
    ply: ply,
    played: played,
    best: mating ? played : before.best,
    label:
        mating
            ? 'Best'
            : book
            ? 'Book'
            : played != before.best && loss < 1 && !sacrifice
            ? 'Good'
            : classifyMove(
              loss: loss,
              onlyMove: only,
              sacrifice: sacrifice,
              missedWin: beforeWp >= 80 && afterWp < 60,
            ),
    loss: loss,
    beforeCp: before.cp,
    afterCp: after.cp,
    beforeMate: before.mate,
    afterMate: after.mate,
    depth: terminal != null ? before.depth : min(before.depth, after.depth),
    opening: book ? openingLibrary.at(next.fen)?.name : null,
  );
}

/// Deliberately narrow: an engine-supported offer of the moved minor/major
/// piece which the best reply can accept for a real material gain. A quiet move
/// followed by a trade elsewhere is not a sacrifice. Neither is an equal trade,
/// even if the engine's PV stops just before the recapture.
bool _soundSacrifice(
  ChessPosition beforePosition,
  ChessPosition afterPosition,
  String played,
  Evaluation before,
  Evaluation after,
  double loss,
  double beforeWp,
  double afterWp,
) {
  if (loss >= 1 ||
      before.depth < 16 ||
      after.depth < 16 ||
      afterWp < 50 ||
      beforeWp >= 90 ||
      after.lines.isEmpty ||
      beforeWp - afterWp >= 2) {
    return false;
  }
  final sign = beforePosition.whiteTurn ? 1 : -1;
  final supported =
      played == before.best ||
      before.lines.any(
        (l) =>
            l.depth == before.depth &&
            l.moves.firstOrNull == played &&
            sign * (before.cp - l.cp) <= 20,
      );
  if (!supported) return false;
  final from = played.substring(0, 2), to = played.substring(2, 4);
  final piece = beforePosition.pieces[from]?.toLowerCase();
  if (!const ['n', 'b', 'r', 'q'].contains(piece)) return false;
  final reply = after.lines.first.moves.firstOrNull;
  if (reply == null ||
      reply.substring(2, 4) != to ||
      !afterPosition.legal.contains(reply)) {
    return false;
  }
  final afterCapture = ChessPosition(
    fen: afterPosition.fen,
    chess960: afterPosition.chess960,
  );
  afterCapture.play(reply);
  // Evaluate the complete exchange on this square, including every legal
  // recapture and the option to stop. This is independent of PV truncation.
  final replyGain =
      sign * (material(afterPosition.fen) - material(afterCapture.fen));
  final recaptureGain = _exchangeGain(afterCapture, to, <String, int>{});
  final initialGain =
      sign * (material(afterPosition.fen) - material(beforePosition.fen));
  return replyGain - recaptureGain - initialGain >= 200;
}

int _exchangeGain(
  ChessPosition position,
  String target,
  Map<String, int> cache,
) {
  final key = position.fen;
  if (cache.containsKey(key)) return cache[key]!;
  final occupant = position.pieces[target];
  if (occupant == null || occupant.toLowerCase() == 'k') return 0;
  var best = 0;
  final sign = position.whiteTurn ? 1 : -1;
  final balance = material(position.fen);
  for (final move in position.legal.where((m) => m.substring(2, 4) == target)) {
    final next = ChessPosition(fen: position.fen, chess960: position.chess960)
      ..play(move);
    final gain = sign * (material(next.fen) - balance);
    best = max(best, gain - _exchangeGain(next, target, cache));
  }
  return cache[key] = best;
}

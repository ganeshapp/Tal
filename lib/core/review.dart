import 'dart:math';
import 'chess.dart';
import 'engine_types.dart';

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
      second != null &&
      second.depth == before.depth &&
      beforeWp - winningChances(sign * second.cp) >= 20;
  var sacrifice = false;
  if (!mating &&
      loss < 2 &&
      afterWp >= 50 &&
      beforeWp < 95 &&
      after.lines.isNotEmpty &&
      after.lines.first.moves.isNotEmpty) {
    final replyPosition = game.boardAt(ply + 1);
    if (replyPosition.play(after.lines.first.moves.first)) {
      sacrifice =
          material(position.fen, white: position.whiteTurn) -
                  material(replyPosition.fen, white: position.whiteTurn) >=
              200 &&
          sign * (material(position.fen) - material(replyPosition.fen)) >= 200;
    }
  }
  return MoveReview(
    ply: ply,
    played: played,
    best: mating ? played : before.best,
    label:
        mating
            ? 'Best'
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
  );
}

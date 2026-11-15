import 'dart:async';
import 'chess.dart';

class EngineLine {
  final int cp, depth;
  final int? mate;
  final List<String> moves;
  const EngineLine({
    required this.cp,
    required this.depth,
    required this.moves,
    this.mate,
  });
}

class Evaluation {
  final List<EngineLine> lines;
  final String best;
  const Evaluation(this.lines, this.best);
  int get cp => lines.isEmpty ? 0 : lines.first.cp;
  int get depth => lines.isEmpty ? 0 : lines.first.depth;
  int? get mate => lines.isEmpty ? null : lines.first.mate;
}

/// Rules, not a search result, decide a terminal position's score.
Evaluation? terminalEvaluation(ChessPosition position) {
  if (!position.over) return null;
  final cp =
      position.result == '1-0'
          ? 100000
          : position.result == '0-1'
          ? -100000
          : 0;
  return Evaluation([
    EngineLine(cp: cp, depth: 0, mate: cp == 0 ? null : 0, moves: const []),
  ], '');
}

abstract class EngineService {
  bool get nativeSupported;
  Future<String> choose(GameRecord record);
  Future<Evaluation> evaluate(GameRecord record, {int? ply, int depth = 14});
  Future<void> dispose();
}

/// A single serialized UCI channel. A stopped search is drained before reuse.
class UciChannel {
  final void Function(String) send;
  final Stream<String> output;
  Future<void> _tail = Future.value();
  UciChannel(this.send, this.output);
  Future<T> serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> ready() async {
    final response = output
        .firstWhere((line) => line.trim() == 'readyok')
        .timeout(const Duration(seconds: 30));
    send('isready');
    await response;
  }

  Future<Evaluation> search({
    required String position,
    required bool whiteTurn,
    required String go,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final done = Completer<void>();
    final lines = <int, EngineLine>{};
    var best = '';
    final subscription = output.listen((chunk) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('bestmove ')) {
          best = line.split(' ')[1];
          if (!done.isCompleted) done.complete();
        }
        final score = RegExp(r'\bscore (cp|mate) (-?\d+)').firstMatch(line);
        final pv = RegExp(r'\bpv (.+)$').firstMatch(line);
        if (score != null && pv != null && !line.contains('bound')) {
          final sign = whiteTurn ? 1 : -1;
          final value = int.parse(score[2]!);
          final mate = score[1] == 'mate' ? value * sign : null;
          final cp =
              mate == null ? value * sign : (mate > 0 ? 100000 : -100000);
          final rank =
              int.tryParse(
                RegExp(r'\bmultipv (\d+)').firstMatch(line)?[1] ?? '1',
              ) ??
              1;
          final depth =
              int.tryParse(
                RegExp(r'\bdepth (\d+)').firstMatch(line)?[1] ?? '0',
              ) ??
              0;
          lines[rank] = EngineLine(
            cp: cp,
            depth: depth,
            mate: mate,
            moves: pv[1]!.trim().split(' '),
          );
        }
      }
    });
    try {
      send(position);
      send(go);
      try {
        await done.future.timeout(timeout);
      } on TimeoutException {
        send('stop');
        await done.future.timeout(const Duration(seconds: 8));
      }
      final ordered = lines.keys.toList()..sort();
      return Evaluation(ordered.map((i) => lines[i]!).toList(), best);
    } finally {
      await subscription.cancel();
    }
  }
}

String positionCommand(GameRecord record, [int? ply]) {
  final moves = record.moves.take(ply ?? record.moves.length).join(' ');
  return 'position fen ${record.startFen}${moves.isEmpty ? '' : ' moves $moves'}';
}

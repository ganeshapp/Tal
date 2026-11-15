import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'maia3.dart';
import 'package:stockfish/stockfish.dart';
import 'chess.dart';
import 'engine_types.dart';

EngineService createEngines() => NativeEngines();

class NativeEngines implements EngineService {
  Stockfish? _sf;
  final Maia3 _maia = Maia3();
  Future<UciChannel>? _observerFuture;
  final List<Process> _processes = [];
  @override
  bool get nativeSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  Future<UciChannel> _desktop(String name) async {
    final directory =
        Platform.environment['TAL_ENGINE_DIR'] ??
        '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/engines';
    final process = await Process.start(
      '$directory/tal-$name',
      [],
      workingDirectory: directory,
    );
    _processes.add(process);
    // Drain diagnostics so an engine cannot block on a full stderr pipe.
    process.stderr.drain<void>();
    return UciChannel(
      (s) => process.stdin.writeln(s),
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream(),
    );
  }

  Future<UciChannel> _observer() =>
      _observerFuture ??=
          (() async {
            final UciChannel channel;
            if (Platform.isMacOS) {
              channel = await _desktop('stockfish');
            } else {
              _sf = await stockfishAsync().timeout(const Duration(seconds: 30));
              channel = UciChannel((s) => _sf!.stdin = s, _sf!.stdout);
            }
            channel.send('uci');
            channel.send('setoption name Threads value 2');
            channel.send('setoption name Hash value 64');
            channel.send('setoption name MultiPV value 3');
            await channel.ready();
            return channel;
          })();
  @override
  Future<String> choose(GameRecord record) async {
    if (!nativeSupported) {
      throw UnsupportedError('Native engines are required to play bots.');
    }
    if (record.chess960 || record.title.startsWith('Stockfish')) {
      final ch = await _observer();
      return ch.serial(() async {
        ch.send('setoption name UCI_Chess960 value ${record.chess960}');
        ch.send('setoption name UCI_LimitStrength value true');
        ch.send(
          'setoption name UCI_Elo value ${record.rating.clamp(1320, 3190)}',
        );
        await ch.ready();
        return (await ch.search(
          position: positionCommand(record),
          whiteTurn: record.position().whiteTurn,
          go: 'go movetime 1200',
        )).best;
      });
    }
    return _maia.choose(record);
  }

  @override
  Future<Evaluation> evaluate(
    GameRecord record, {
    int? ply,
    int depth = 14,
  }) async {
    final pos = record.position(ply);
    final terminal = terminalEvaluation(pos);
    if (terminal != null) return terminal;
    if (!nativeSupported) {
      throw UnsupportedError('Stockfish is unavailable on this platform.');
    }
    final ch = await _observer();
    return ch.serial(() async {
      ch.send('setoption name UCI_Chess960 value ${record.chess960}');
      ch.send('setoption name UCI_LimitStrength value false');
      await ch.ready();
      final result = await ch.search(
        position: positionCommand(record, ply),
        whiteTurn: pos.whiteTurn,
        go: 'go depth $depth movetime ${depth >= 16 ? 2500 : 600}',
      );
      if (result.lines.isEmpty) {
        throw StateError('Stockfish returned no evaluation');
      }
      return result;
    });
  }

  @override
  Future<void> dispose() async {
    for (final process in _processes) {
      process.stdin.writeln('quit');
      process.kill();
    }
    if (_sf?.state.value == StockfishState.ready) _sf!.dispose();
    await _maia.dispose();
  }
}

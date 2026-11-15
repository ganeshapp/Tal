import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'chess.dart';

/// Matches CSSLab/maia3 tokenization, including each historical board's turn.
Float32List maiaTokens(GameRecord game) {
  final last = game.moves.length;
  final fens = [for (var i = max(0, last - 7); i <= last; i++) game.fenAt(i)];
  while (fens.length < 8) {
    fens.insert(0, fens.first);
  }
  final tokens = Float32List(64 * 97);
  const types = 'pnbrqk';
  for (var h = 0; h < 8; h++) {
    final white = fens[h].split(' ')[1] == 'w';
    for (final e in piecesFromFen(fens[h]).entries) {
      final file = e.key.codeUnitAt(0) - 97, rank = int.parse(e.key[1]) - 1;
      final square = (white ? rank : 7 - rank) * 8 + file;
      final own = (e.value == e.value.toUpperCase()) == white;
      final piece = types.indexOf(e.value.toLowerCase()) + (own ? 0 : 6);
      tokens[square * 97 + h * 12 + piece] = 1;
    }
  }
  return tokens;
}

int maiaMoveIndex(String move, bool white) {
  int square(String s) {
    final rank = int.parse(s[1]) - 1;
    return (white ? rank : 7 - rank) * 8 + s.codeUnitAt(0) - 97;
  }

  final from = square(move.substring(0, 2)), to = square(move.substring(2, 4));
  if (move.length > 4) {
    return 4096 + (from % 8) * 32 + (to % 8) * 4 + 'qrbn'.indexOf(move[4]);
  }
  return from * 64 + to;
}

class Maia3 {
  Isolate? _isolate;
  SendPort? _send;
  ReceivePort? _receive;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _initializing;
  final Map<int, Completer<List<double>>> _pending = {};
  final Random _random = Random();
  int _next = 0;
  bool _disposed = false;
  final _closed = Completer<void>();
  Future<void> _init() =>
      _initializing ??=
          (() async {
            final bytes = await rootBundle.load(
              'assets/weights/maia3-23m.onnx',
            );
            final ready = Completer<void>();
            _receive = ReceivePort();
            _subscription = _receive!.listen((message) {
              if (message == 'closed') {
                if (!_closed.isCompleted) _closed.complete();
                return;
              }
              if (message is SendPort) {
                _send = message;
                ready.complete();
                return;
              }
              if (message is Map) {
                if (message['id'] == -1) {
                  if (!ready.isCompleted) {
                    ready.completeError(StateError(message['error'] as String));
                  }
                  return;
                }
                final result = _pending.remove(message['id']);
                if (result == null) return;
                if (message['error'] != null) {
                  result.completeError(StateError(message['error'] as String));
                } else {
                  result.complete(List<double>.from(message['policy'] as List));
                }
              }
            });
            _isolate = await Isolate.spawn(_worker, [
              _receive!.sendPort,
              TransferableTypedData.fromList([bytes.buffer.asUint8List()]),
            ], debugName: 'Maia3 inference');
            await ready.future.timeout(const Duration(seconds: 45));
          })();
  Future<List<double>> policy(GameRecord game) async {
    if (_disposed) throw StateError('Maia closed');
    await _init();
    if (_disposed) throw StateError('Maia closed');
    final id = _next++, done = Completer<List<double>>();
    _pending[id] = done;
    _send!.send({'id': id, 'tokens': maiaTokens(game), 'rating': game.rating});
    try {
      return await done.future.timeout(const Duration(seconds: 30));
    } finally {
      _pending.remove(id);
    }
  }

  Future<String> choose(GameRecord game) async {
    final pos = game.position(), legal = pos.legal;
    if (legal.isEmpty) throw StateError('No legal moves');
    final logits = await policy(game);
    final scores =
        legal.map((m) => logits[maiaMoveIndex(m, pos.whiteTurn)]).toList();
    final maximum = scores.reduce(max);
    // Temperature 1: sample the model's predicted human move distribution.
    final weights = scores.map((x) => exp(x - maximum)).toList();
    var pick = _random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < legal.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return legal[i];
    }
    return legal.last;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _initializing;
    } catch (_) {}
    _send?.send(null);
    for (final pending in _pending.values) {
      pending.completeError(StateError('Maia closed'));
    }
    _pending.clear();
    if (_send != null) {
      try {
        await _closed.future.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    await _subscription?.cancel();
    _receive?.close();
    _isolate?.kill();
  }
}

void _worker(List<dynamic> init) async {
  final output = init[0] as SendPort, port = ReceivePort();
  OrtSession? session;
  bool initialized = false;
  try {
    OrtEnv.instance.init();
    initialized = true;
    final options =
        OrtSessionOptions()
          ..setIntraOpNumThreads(2)
          ..setInterOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(
            GraphOptimizationLevel.ortEnableAll,
          );
    session = OrtSession.fromBuffer(
      (init[1] as TransferableTypedData).materialize().asUint8List(),
      options,
    );
    options.release();
    output.send(port.sendPort);
    await for (final message in port) {
      if (message == null) break;
      final inputs = <String, OrtValueTensor>{};
      final run = OrtRunOptions();
      List<OrtValue?>? values;
      try {
        final elo = Float32List.fromList([
          (message['rating'] as int).toDouble(),
        ]);
        inputs['tokens'] = OrtValueTensor.createTensorWithDataList(
          message['tokens'] as Float32List,
          [1, 64, 97],
        );
        inputs['self_elo'] = OrtValueTensor.createTensorWithDataList(elo, [1]);
        inputs['opponent_elo'] = OrtValueTensor.createTensorWithDataList(elo, [
          1,
        ]);
        values = session.run(run, inputs);
        output.send({
          'id': message['id'],
          'policy': List<double>.from(
            (values.first!.value as List).first as List,
          ),
        });
      } catch (e) {
        output.send({'id': message['id'], 'error': e.toString()});
      } finally {
        for (final value in inputs.values) {
          value.release();
        }
        for (final value in values ?? <OrtValue?>[]) {
          value?.release();
        }
        run.release();
      }
    }
  } catch (e) {
    output.send({'id': -1, 'error': e.toString()});
  } finally {
    session?.release();
    if (initialized) OrtEnv.instance.release();
    port.close();
    output.send('closed');
  }
}

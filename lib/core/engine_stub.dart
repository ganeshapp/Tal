import 'chess.dart';
import 'engine_types.dart';

EngineService createEngines() => PreviewEngines();

class PreviewEngines implements EngineService {
  @override
  bool get nativeSupported => false;
  @override
  Future<String> choose(GameRecord record) async =>
      throw UnsupportedError('Use the desktop or Android app for Maia bots.');
  @override
  Future<Evaluation> evaluate(
    GameRecord record, {
    int? ply,
    int depth = 14,
  }) async =>
      terminalEvaluation(record.position(ply)) ??
      (throw UnsupportedError(
        'Use the desktop or Android app for Stockfish analysis.',
      ));
  @override
  Future<void> dispose() async {}
}

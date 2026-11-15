import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_types.dart';

void main() {
  test(
    'UCI normalizes black perspective, ranks MultiPV and handles mate',
    () async {
      final stream = StreamController<String>.broadcast();
      final ch = UciChannel((line) {
        if (line.startsWith('go')) {
          scheduleMicrotask(() {
            stream.add('info depth 16 multipv 2 score cp 120 pv e7e5 g1f3');
            stream.add('info depth 17 multipv 1 score mate 3 pv d8h4');
            stream.add('bestmove d8h4');
          });
        }
      }, stream.stream);
      final result = await ch.search(
        position: 'position startpos',
        whiteTurn: false,
        go: 'go depth 16',
      );
      expect(result.best, 'd8h4');
      expect(result.lines.first.mate, -3);
      expect(result.cp, -100000);
      expect(result.lines[1].cp, -120);
      expect(result.depth, 17);
      await stream.close();
    },
  );
  test(
    'UCI jobs serialize and a failed request does not poison the queue',
    () async {
      final ch = UciChannel((_) {}, const Stream.empty());
      final order = <int>[];
      final a = ch.serial(() async {
        order.add(1);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add(2);
      });
      final b = ch.serial(() async {
        order.add(3);
        throw StateError('test');
      });
      final c = ch.serial(() async {
        order.add(4);
      });
      await a;
      await expectLater(b, throwsStateError);
      await c;
      expect(order, [1, 2, 3, 4]);
    },
  );
  test('UCI sends history for Maia input planes and repetition', () {
    final r = GameRecord(
      id: '1',
      startFen: initialFen,
      date: '2026-11-15',
      title: 'Maia',
      moves: ['e2e4', 'e7e5'],
    );
    expect(positionCommand(r), endsWith(' moves e2e4 e7e5'));
    expect(positionCommand(r, 1), endsWith(' moves e2e4'));
  });
}

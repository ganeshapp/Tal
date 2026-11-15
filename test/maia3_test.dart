import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/maia3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Native Maia 3 matches official Python logits at every selected Elo',
    () async {
      final fixtures =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/data/maia3_validation.json',
                ),
              )
              as List;
      final maia = Maia3();
      try {
        for (final f in fixtures) {
          final game = GameRecord(
            id: 'parity',
            startFen: f['startFen'],
            date: '2026-11-15',
            title: 'Maia',
            rating: f['rating'],
            moves: List<String>.from(f['moves']),
          );
          final logits = await maia.policy(game),
              white = game.position().whiteTurn;
          final expected = Map<String, dynamic>.from(f['logits']);
          for (final e in expected.entries) {
            expect(
              logits[maiaMoveIndex(e.key, white)],
              closeTo((e.value as num).toDouble(), .0003),
              reason: '${game.rating}: ${e.key}',
            );
          }
          final best = expected.keys.reduce(
            (a, b) =>
                logits[maiaMoveIndex(a, white)] >
                        logits[maiaMoveIndex(b, white)]
                    ? a
                    : b,
          );
          expect(best, f['top']);
        }
      } finally {
        await maia.dispose();
      }
    },
    skip: !Platform.environment.containsKey('TAL_ORT_LIBRARY'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

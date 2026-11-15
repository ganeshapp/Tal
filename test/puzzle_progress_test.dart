import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/puzzles.dart';
import 'package:tal/core/chess.dart';

Puzzle p(String id, int rating, {List<String> themes = const ['fork']}) =>
    Puzzle(
      id: id,
      fen: initialFen,
      moves: ['e2e4', 'e7e5'],
      themes: themes,
      rating: rating,
    );
void main() {
  test('Glicko-2 matches Glickman published worked example', () {
    final rating = const PuzzleRating(
      rating: 1500,
      deviation: 200,
      volatility: .06,
    ).update([
      (rating: 1400.0, deviation: 30.0, score: 1.0),
      (rating: 1550.0, deviation: 100.0, score: 0.0),
      (rating: 1700.0, deviation: 300.0, score: 0.0),
    ]);
    expect(rating.rating, closeTo(1464.06, .01));
    expect(rating.deviation, closeTo(151.52, .01));
    expect(rating.volatility, closeTo(.059996, .000001));
  });
  test(
    'First attempts adjust local and theme ratings; assistance loses once',
    () {
      final progress = PuzzleProgress();
      final win = progress.record(
        p('a', 1500),
        success: true,
        assisted: false,
        mode: 'standard',
        firstExposure: true,
        elapsed: const Duration(seconds: 12),
      );
      expect(win.delta, greaterThan(0));
      expect(progress.themes['fork']!.rating, progress.rating.rating);
      final before = progress.rating.rating;
      final loss = progress.record(
        p('b', 1600),
        success: false,
        assisted: true,
        mode: 'standard',
        firstExposure: true,
        elapsed: const Duration(seconds: 4),
      );
      expect(loss.delta, lessThan(0));
      expect(progress.rating.rating, lessThan(before));
      final failedRating = progress.rating.rating;
      final retry = progress.record(
        p('b', 1600),
        success: true,
        assisted: false,
        mode: 'standard',
        firstExposure: true,
        elapsed: const Duration(seconds: 4),
      );
      expect(retry.rated, isFalse);
      expect(progress.rating.rating, failedRating);
      expect(progress.rating.count, 2);
    },
  );
  test(
    'Timed runs and exposed repeats cannot inflate ratings; persistence round trips',
    () {
      final progress = PuzzleProgress();
      progress.record(
        p('a', 800),
        success: true,
        assisted: false,
        mode: 'storm',
        firstExposure: true,
        elapsed: Duration.zero,
      );
      progress.record(
        p('a', 800),
        success: true,
        assisted: false,
        mode: 'standard',
        firstExposure: false,
        elapsed: Duration.zero,
      );
      expect(progress.rating.rating, 1500);
      expect(progress.rating.count, 0);
      progress.stormBests[5] = 12;
      progress.offset = 200;
      final loaded = PuzzleProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())),
      );
      expect(loaded.exposed, {'a'});
      expect(loaded.attempts.length, 2);
      expect(loaded.stormBests[3], 0);
      expect(loaded.stormBests[5], 12);
      expect(loaded.offset, 200);
    },
  );
  test(
    'Adaptive selection honors rating, offset, theme, and unseen status',
    () {
      final puzzles = [
        p('easy', 800),
        p('level', 1600),
        p('hard', 1800),
        p('wrongTheme', 1800, themes: ['pin']),
      ];
      expect(
        selectPuzzle(
          puzzles,
          target: puzzleTarget(1600, 0),
          random: Random(1),
        )!.id,
        'level',
      );
      expect(
        selectPuzzle(
          puzzles,
          target: puzzleTarget(1600, 200),
          theme: 'fork',
          random: Random(1),
        )!.id,
        'hard',
      );
      expect(selectPuzzle(puzzles, target: 1600, exclude: {'level'}), isNull);
      expect(selectPuzzle(puzzles, target: 1800, theme: 'mateIn3'), isNull);
      expect(puzzleTarget(3300, 200), 3199);
    },
  );
  test(
    'Storm and Streak progress by solved count, not thousands of easy puzzles',
    () {
      expect(speedPuzzleTarget(0), 600);
      expect(speedPuzzleTarget(8), 1200);
      expect(speedPuzzleTarget(20), 2100);
      expect(speedPuzzleTarget(60), 3100);
    },
  );
}

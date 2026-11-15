import 'dart:math';
import 'chess.dart';

class Puzzle {
  final String id, fen;
  final List<String> moves, themes;
  final int rating, deviation;
  Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.themes,
    required this.rating,
    this.deviation = 75,
  });
  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
    id: j['id'],
    fen: j['fen'],
    moves: List<String>.from(j['moves']),
    themes: List<String>.from(j['themes']),
    rating: j['rating'],
    deviation: j['deviation'] ?? 75,
  );
  ChessPosition start() => ChessPosition(fen: fen)..play(moves.first);
}

/// Glickman, Glicko-2 (2022 revision), tau=.5. Puzzle ratings are fixed
/// opponents. One first attempt is one rating period; ratings are local.
class PuzzleRating {
  final double rating, deviation, volatility;
  final int count;
  const PuzzleRating({
    this.rating = 1500,
    this.deviation = 350,
    this.volatility = .06,
    this.count = 0,
  });
  bool get provisional => count < 20 || deviation > 110;
  String get label => '${rating.round()}${provisional ? '?' : ''}';
  PuzzleRating update(
    List<({double rating, double deviation, double score})> results,
  ) {
    const scale = 173.7178, tau = .5;
    final mu = (rating - 1500) / scale, phi = deviation / scale;
    if (results.isEmpty) {
      return PuzzleRating(
        rating: rating,
        deviation: min(350, scale * sqrt(phi * phi + volatility * volatility)),
        volatility: volatility,
        count: count,
      );
    }
    double information = 0, improvement = 0;
    for (final r in results) {
      final p = r.deviation / scale;
      final g = 1 / sqrt(1 + 3 * p * p / (pi * pi));
      final expected = 1 / (1 + exp(-g * (mu - (r.rating - 1500) / scale)));
      information += g * g * expected * (1 - expected);
      improvement += g * (r.score - expected);
    }
    final v = 1 / information, delta = v * improvement;
    final a = log(volatility * volatility);
    double f(double x) {
      final ex = exp(x), denominator = phi * phi + v + ex;
      return ex *
              (delta * delta - phi * phi - v - ex) /
              (2 * denominator * denominator) -
          (x - a) / (tau * tau);
    }

    var low = a;
    double high;
    if (delta * delta > phi * phi + v) {
      high = log(delta * delta - phi * phi - v);
    } else {
      var k = 1;
      while (f(a - k * tau) < 0) {
        k++;
      }
      high = a - k * tau;
    }
    var fl = f(low), fh = f(high);
    for (var i = 0; (high - low).abs() > .000001 && i < 100; i++) {
      final c = low + (low - high) * fl / (fh - fl), fc = f(c);
      if (fc * fh <= 0) {
        low = high;
        fl = fh;
      } else {
        fl /= 2;
      }
      high = c;
      fh = fc;
    }
    final sigma = exp(low / 2);
    final prePhi = sqrt(phi * phi + sigma * sigma);
    final nextPhi = 1 / sqrt(1 / (prePhi * prePhi) + 1 / v);
    return PuzzleRating(
      rating: scale * (mu + nextPhi * nextPhi * improvement) + 1500,
      deviation: scale * nextPhi,
      volatility: sigma,
      count: count + results.length,
    );
  }

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'deviation': deviation,
    'volatility': volatility,
    'count': count,
  };
  factory PuzzleRating.fromJson(Map<String, dynamic> j) => PuzzleRating(
    rating: (j['rating'] as num).toDouble(),
    deviation: (j['deviation'] as num).toDouble(),
    volatility: (j['volatility'] as num).toDouble(),
    count: j['count'],
  );
}

class PuzzleAttempt {
  final String id, mode;
  final List<String> themes;
  final DateTime date;
  final int puzzleRating, milliseconds;
  final bool success, assisted, rated;
  final double before, after;
  const PuzzleAttempt({
    required this.id,
    required this.mode,
    required this.themes,
    required this.date,
    required this.puzzleRating,
    required this.milliseconds,
    required this.success,
    required this.assisted,
    required this.rated,
    required this.before,
    required this.after,
  });
  int get delta => after.round() - before.round();
  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'themes': themes,
    'date': date.toIso8601String(),
    'puzzleRating': puzzleRating,
    'milliseconds': milliseconds,
    'success': success,
    'assisted': assisted,
    'rated': rated,
    'before': before,
    'after': after,
  };
  factory PuzzleAttempt.fromJson(Map<String, dynamic> j) => PuzzleAttempt(
    id: j['id'],
    mode: j['mode'],
    themes: List<String>.from(j['themes']),
    date: DateTime.parse(j['date']),
    puzzleRating: j['puzzleRating'],
    milliseconds: j['milliseconds'],
    success: j['success'],
    assisted: j['assisted'],
    rated: j['rated'],
    before: (j['before'] as num).toDouble(),
    after: (j['after'] as num).toDouble(),
  );
}

class PuzzleProgress {
  PuzzleRating rating = const PuzzleRating();
  final Map<String, PuzzleRating> themes = {};
  final Set<String> exposed = {};
  final List<PuzzleAttempt> attempts = [];
  final Map<int, int> stormBests = {3: 0, 5: 0};
  int offset = 0, streakBest = 0;
  String theme = 'mix';
  PuzzleAttempt record(
    Puzzle puzzle, {
    required bool success,
    required bool assisted,
    required String mode,
    required bool firstExposure,
    required Duration elapsed,
    DateTime? now,
  }) {
    final before = rating.rating;
    // Rating eligibility is captured before showing the board. A session may
    // submit only once, and persisted history additionally prevents duplicates.
    final rated =
        mode == 'standard' &&
        firstExposure &&
        !attempts.any((a) => a.id == puzzle.id);
    exposed.add(puzzle.id);
    if (rated) {
      final result = (
        rating: puzzle.rating.toDouble(),
        deviation: puzzle.deviation.toDouble(),
        score: success && !assisted ? 1.0 : 0.0,
      );
      rating = rating.update([result]);
      for (final t in puzzle.themes.toSet()) {
        themes[t] = (themes[t] ?? const PuzzleRating()).update([result]);
      }
    }
    final attempt = PuzzleAttempt(
      id: puzzle.id,
      mode: mode,
      themes: puzzle.themes,
      date: now ?? DateTime.now(),
      puzzleRating: puzzle.rating,
      milliseconds: elapsed.inMilliseconds,
      success: success && !assisted,
      assisted: assisted,
      rated: rated,
      before: before,
      after: rating.rating,
    );
    attempts.add(attempt);
    return attempt;
  }

  Map<String, dynamic> toJson() => {
    'rating': rating.toJson(),
    'themes': themes.map((k, v) => MapEntry(k, v.toJson())),
    'exposed': exposed.toList(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'offset': offset,
    'theme': theme,
    'stormBests': stormBests.map((k, v) => MapEntry('$k', v)),
    'streakBest': streakBest,
  };
  factory PuzzleProgress.fromJson(Map<String, dynamic> j) {
    final p =
        PuzzleProgress()
          ..rating = PuzzleRating.fromJson(j['rating'])
          ..offset = j['offset']
          ..theme = j['theme']
          ..streakBest = j['streakBest'];
    p.themes.addAll(
      (j['themes'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, PuzzleRating.fromJson(v)),
      ),
    );
    p.exposed.addAll(List<String>.from(j['exposed']));
    p.attempts.addAll(
      (j['attempts'] as List).map((a) => PuzzleAttempt.fromJson(a)),
    );
    p.stormBests.addAll(
      (j['stormBests'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as int),
      ),
    );
    return p;
  }
  PuzzleProgress();
}

int puzzleTarget(double rating, int offset) =>
    (rating.round() + offset).clamp(400, 3199);
int speedPuzzleTarget(int score) => min(3100, 600 + score * 75);

Puzzle? selectPuzzle(
  List<Puzzle> puzzles, {
  required int target,
  String theme = 'mix',
  Set<String> exclude = const {},
  int window = 100,
  Random? random,
}) {
  final choices =
      puzzles
          .where(
            (p) =>
                !exclude.contains(p.id) &&
                (theme == 'mix' || p.themes.contains(theme)) &&
                (p.rating - target).abs() <= window,
          )
          .toList();
  if (choices.isEmpty) return null;
  return choices[(random ?? Random()).nextInt(choices.length)];
}

const puzzleThemeNames = <String, String>{
  'mix': 'Mixed puzzles',
  'fork': 'Fork',
  'pin': 'Pin',
  'skewer': 'Skewer',
  'discoveredAttack': 'Discovered attack',
  'discoveredCheck': 'Discovered check',
  'sacrifice': 'Sacrifice',
  'queenSacrifice': 'Queen sacrifice',
  'multiMove': 'Multi-move combination',
  'mate': 'Checkmate',
  'mateIn1': 'Mate in 1',
  'mateIn2': 'Mate in 2',
  'mateIn3': 'Mate in 3',
  'mateIn4': 'Mate in 4',
  'mateIn5': 'Mate in 5+',
  'advancedPawn': 'Advanced pawn',
  'endgame': 'Endgame',
  'middlegame': 'Middlegame',
  'opening': 'Opening',
  'kingsideAttack': 'Kingside attack',
  'queensideAttack': 'Queenside attack',
  'defensiveMove': 'Defensive move',
  'hangingPiece': 'Hanging piece',
  'rookEndgame': 'Rook endgame',
  'pawnEndgame': 'Pawn endgame',
  'bishopEndgame': 'Bishop endgame',
  'knightEndgame': 'Knight endgame',
  'queenEndgame': 'Queen endgame',
  'attraction': 'Attraction',
  'deflection': 'Deflection',
  'interference': 'Interference',
  'intermezzo': 'Intermediate move',
  'clearance': 'Clearance',
  'zugzwang': 'Zugzwang',
  'promotion': 'Promotion',
  'underPromotion': 'Underpromotion',
  'quietMove': 'Quiet move',
  'exposedKing': 'Exposed king',
  'backRankMate': 'Back rank mate',
  'smotheredMate': 'Smothered mate',
  'doubleCheck': 'Double check',
  'capturingDefender': 'Remove the defender',
};
String puzzleThemeName(String key) =>
    puzzleThemeNames[key] ??
    key
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
        .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());

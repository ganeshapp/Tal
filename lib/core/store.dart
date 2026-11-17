import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chess.dart';
import 'puzzles.dart';
import 'openings.dart';
export 'puzzles.dart';

class Mistake {
  final String id, fen, best, played;
  final bool chess960;
  DateTime due;
  int stage;
  Mistake({
    required this.id,
    required this.fen,
    required this.best,
    required this.played,
    required this.due,
    this.stage = 0,
    this.chess960 = false,
  });
  void answer(bool correct, DateTime now) {
    if (correct) {
      stage = (stage + 1).clamp(1, 6);
    } else {
      stage = 0;
    }
    const days = [1, 3, 7, 14, 30, 60, 90];
    due = now.add(Duration(days: days[stage]));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fen': fen,
    'best': best,
    'played': played,
    'due': due.toIso8601String(),
    'stage': stage,
    'chess960': chess960,
  };
  factory Mistake.fromJson(Map<String, dynamic> j) => Mistake(
    id: j['id'],
    fen: j['fen'],
    best: j['best'],
    played: j['played'],
    due: DateTime.parse(j['due']),
    stage: j['stage'],
    chess960: j['chess960'] ?? false,
  );
}

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  List<GameRecord> games = [];
  List<Mistake> mistakes = [];
  Set<String> solved = {};
  List<Puzzle> puzzles = [];
  PuzzleProgress puzzleProgress = PuzzleProgress();
  GameRecord? active;
  String evaluation = 'off';
  bool naturalDelay = true, coordinates = true, haptics = true, premoves = true;
  int rating = 1500;
  String? storageError;
  Future<void> _pending = Future.value();
  AppStore(this.prefs);
  static Future<AppStore> load() async {
    final store = AppStore(await SharedPreferences.getInstance());
    final raw = store.prefs.getString('tal.v2');
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        store.games =
            (j['games'] as List)
                .map((g) => GameRecord.fromJson(Map<String, dynamic>.from(g)))
                .toList();
        store.mistakes =
            (j['reviewVersion'] == reviewVersion ? j['mistakes'] as List : [])
                .map((g) => Mistake.fromJson(Map<String, dynamic>.from(g)))
                .toList();
        store.solved = Set<String>.from(j['solved']);
        store.active =
            j['active'] == null
                ? null
                : GameRecord.fromJson(Map<String, dynamic>.from(j['active']));
        store.active?.position();
        store.evaluation = j['evaluation'] ?? 'off';
        store.naturalDelay = j['naturalDelay'] ?? true;
        store.coordinates = j['coordinates'] ?? true;
        store.haptics = j['haptics'] ?? true;
        store.premoves = j['premoves'] ?? true;
        store.rating = j['rating'] ?? 1500;
        if (j['puzzleProgress'] != null) {
          store.puzzleProgress = PuzzleProgress.fromJson(j['puzzleProgress']);
        }
      } catch (_) {
        store.storageError =
            'Saved data could not be read. The original has been kept in a recovery copy.';
        await store.prefs.setString('tal.recovery', raw);
      }
    }
    final data =
        jsonDecode(await rootBundle.loadString('assets/data/puzzles.json'))
            as List;
    store.puzzles =
        data.map((p) => Puzzle.fromJson(Map<String, dynamic>.from(p))).toList();
    openingLibrary.load(
      jsonDecode(await rootBundle.loadString('assets/data/openings.json'))
          as List,
      book:
          jsonDecode(
                await rootBundle.loadString('assets/data/opening_book.json'),
              )
              as Map<String, dynamic>,
    );
    return store;
  }

  List<Mistake> get due =>
      mistakes.where((m) => !m.due.isAfter(DateTime.now())).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
  Future<void> save() {
    final snapshot = jsonEncode({
      'version': 2,
      'reviewVersion': reviewVersion,
      'puzzleProgress': puzzleProgress.toJson(),
      'games': games.map((g) => g.toJson()).toList(),
      'mistakes': mistakes.map((m) => m.toJson()).toList(),
      'solved': solved.toList(),
      'active': active?.toJson(),
      'evaluation': evaluation,
      'naturalDelay': naturalDelay,
      'coordinates': coordinates,
      'haptics': haptics,
      'premoves': premoves,
      'rating': rating,
    });
    _pending = _pending.then((_) async {
      try {
        if (!await prefs.setString('tal.v2', snapshot)) {
          throw StateError('write failed');
        }
        storageError = null;
      } catch (_) {
        storageError =
            'Could not save your progress. Keep the app open and free some device storage.';
        notifyListeners();
      }
    });
    notifyListeners();
    return _pending;
  }

  void archive(GameRecord record) {
    if (record.opening.isEmpty) {
      record.opening = openingLibrary.identify(record);
    }
    games.removeWhere((g) => g.id == record.id);
    games.insert(0, record);
    if (active?.id == record.id) active = null;
    save();
  }

  void addMistake(GameRecord game, MoveReview review) {
    final pos = game.position(review.ply);
    if (pos.whiteTurn != game.humanWhite ||
        review.label == 'Book' ||
        review.loss <= 20 ||
        review.best.isEmpty) {
      return;
    }
    final id = '${game.id}:${review.ply}';
    if (mistakes.any((m) => m.id == id)) return;
    mistakes.add(
      Mistake(
        id: id,
        fen: pos.fen,
        best: review.best,
        played: review.played,
        chess960: game.chess960,
        due: DateTime.now().add(const Duration(days: 1)),
      ),
    );
  }
}

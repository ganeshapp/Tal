import 'dart:math';
import 'package:bishop/bishop.dart' as b;

const initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class ChessPosition {
  final b.Game game;
  final bool chess960;
  ChessPosition({String? fen, this.chess960 = false, int? seed})
    : game = b.Game(
        fen: fen,
        variant: chess960 ? b.Variant.chess960() : null,
        startPosSeed: seed,
      );
  String get fen => game.fen;
  bool get whiteTurn => game.turn == b.Bishop.white;
  bool get over => game.gameOver;
  bool get inCheck => game.inCheck;
  String? get outcome => game.result?.readable;
  String get result => game.result?.scoreString ?? '*';
  List<String> get legal => game.algebraicMoves();
  List<String> get premoves =>
      game.generatePremoves().map((m) => game.toAlgebraic(m)).toList();
  Map<String, String> get pieces => piecesFromFen(fen);
  String san(String uci) => game.toSan(game.getMove(uci)!);
  bool play(String uci) => game.makeMoveString(uci);
}

Map<String, String> piecesFromFen(String fen) {
  final pieces = <String, String>{};
  final ranks = fen.split(' ').first.split('/');
  for (var rank = 0; rank < 8; rank++) {
    var file = 0;
    for (final ch in ranks[rank].split('')) {
      final empty = int.tryParse(ch);
      if (empty != null) {
        file += empty;
      } else {
        pieces['${String.fromCharCode(97 + file)}${8 - rank}'] = ch;
        file++;
      }
    }
  }
  return pieces;
}

int material(String fen, {bool? white}) {
  const values = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};
  var sum = 0;
  for (final p in piecesFromFen(fen).values) {
    final isWhite = p == p.toUpperCase();
    if (white != null) {
      if (white == isWhite) sum += values[p.toLowerCase()]!;
    } else {
      sum += (isWhite ? 1 : -1) * values[p.toLowerCase()]!;
    }
  }
  return sum;
}

double winningChances(int cp) =>
    cp >= 100000
        ? 100
        : cp <= -100000
        ? 0
        : 100 / (1 + exp(-0.00368208 * cp.clamp(-4000, 4000)));

final maiaRatings = List.generate(21, (i) => 600 + i * 100);

class MoveReview {
  final int ply, beforeCp, afterCp, depth;
  final String played, best, label;
  final double loss;
  final int? beforeMate, afterMate;
  const MoveReview({
    required this.ply,
    required this.played,
    required this.best,
    required this.label,
    required this.loss,
    required this.beforeCp,
    required this.afterCp,
    required this.depth,
    this.beforeMate,
    this.afterMate,
  });
  Map<String, dynamic> toJson() => {
    'ply': ply,
    'played': played,
    'best': best,
    'label': label,
    'loss': loss,
    'beforeCp': beforeCp,
    'afterCp': afterCp,
    'depth': depth,
    'beforeMate': beforeMate,
    'afterMate': afterMate,
  };
  factory MoveReview.fromJson(Map<String, dynamic> j) => MoveReview(
    ply: j['ply'],
    played: j['played'],
    best: j['best'],
    label: j['label'],
    loss: (j['loss'] as num).toDouble(),
    beforeCp: j['beforeCp'],
    afterCp: j['afterCp'],
    depth: j['depth'],
    beforeMate: j['beforeMate'],
    afterMate: j['afterMate'],
  );
}

String classifyMove({
  required double loss,
  bool onlyMove = false,
  bool sacrifice = false,
  bool missedWin = false,
}) {
  if (loss > 20) return missedWin ? 'Miss' : 'Blunder';
  if (loss >= 10) return 'Mistake';
  if (loss >= 5) return 'Inaccuracy';
  if (loss < 2 && sacrifice) return 'Brilliant';
  if (loss < 2 && onlyMove) return 'Great';
  if (loss < 1) return 'Best';
  return 'Good';
}

class GameRecord {
  final String id, startFen, date, title;
  final int rating;
  final bool humanWhite, chess960;
  String opening;
  final List<String> moves;
  String result;
  List<MoveReview> reviews;
  GameRecord({
    required this.id,
    required this.startFen,
    required this.date,
    required this.title,
    this.rating = 1500,
    this.humanWhite = true,
    this.chess960 = false,
    this.opening = '',
    List<String>? moves,
    this.result = '*',
    List<MoveReview>? reviews,
  }) : moves = moves ?? [],
       reviews = reviews ?? [];
  ChessPosition position([int? ply]) {
    final pos = ChessPosition(fen: startFen, chess960: chess960);
    for (final move in moves.take(ply ?? moves.length)) {
      if (!pos.play(move)) throw FormatException('Invalid saved move: $move');
    }
    return pos;
  }

  final List<String> _cachedMoves = [], _sans = [], _fens = [], _results = [];
  ChessPosition? _cachePosition;
  void _ensureCache() {
    if (_cachedMoves.length > moves.length ||
        List.generate(
          _cachedMoves.length,
          (i) => i,
        ).any((i) => _cachedMoves[i] != moves[i])) {
      _cachedMoves.clear();
      _sans.clear();
      _fens.clear();
      _results.clear();
      _cachePosition = null;
    }
    if (_cachePosition == null) {
      _cachePosition = ChessPosition(fen: startFen, chess960: chess960);
      _fens.add(startFen);
      _results.add(_cachePosition!.result);
    }
    for (var i = _cachedMoves.length; i < moves.length; i++) {
      _sans.add(_cachePosition!.san(moves[i]));
      if (!_cachePosition!.play(moves[i])) {
        throw FormatException('Invalid move: ${moves[i]}');
      }
      _cachedMoves.add(moves[i]);
      _fens.add(_cachePosition!.fen);
      _results.add(_cachePosition!.result);
    }
  }

  List<String> get sans {
    _ensureCache();
    return List.unmodifiable(_sans);
  }

  String fenAt(int ply) {
    _ensureCache();
    return _fens[ply];
  }

  String resultAt(int ply) {
    _ensureCache();
    return _results[ply];
  }

  ChessPosition boardAt(int ply) =>
      ChessPosition(fen: fenAt(ply), chess960: chess960);
  bool whiteAt(int ply) => fenAt(ply).split(' ')[1] == 'w';
  String get botName =>
      title == 'Maia' || title.startsWith('Maia ') ? 'Maia 3 · $rating' : title;
  String get whiteName => humanWhite ? 'You' : botName;
  String get blackName => humanWhite ? botName : 'You';
  String get outcome =>
      result == '*'
          ? 'Unfinished'
          : result == '1/2-1/2'
          ? 'Draw'
          : (result == '1-0') == humanWhite
          ? 'Won'
          : 'Lost';

  String pgn() {
    final pos = ChessPosition(fen: startFen, chess960: chess960);
    final text = StringBuffer();
    for (var i = 0; i < moves.length; i++) {
      final fields = pos.fen.split(' ');
      if (pos.whiteTurn) {
        text.write('${fields[5]}. ');
      } else if (i == 0) {
        text.write('${fields[5]}... ');
      }
      text.write('${pos.san(moves[i])} ');
      pos.play(moves[i]);
    }
    final white = humanWhite ? 'You' : title;
    final black = humanWhite ? title : 'You';
    return '[Event "Tal"]\n[Site "Offline"]\n[Date "${date.substring(0, 10).replaceAll('-', '.')}"]\n[White "$white"]\n[Black "$black"]\n[Result "$result"]\n${chess960 ? '[Variant "Chess960"]\n' : ''}${startFen != initialFen ? '[SetUp "1"]\n[FEN "$startFen"]\n' : ''}\n$text$result';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startFen': startFen,
    'date': date,
    'title': title,
    'rating': rating,
    'humanWhite': humanWhite,
    'chess960': chess960,
    'opening': opening,
    'moves': moves,
    'result': result,
    'reviews': reviews.map((r) => r.toJson()).toList(),
  };
  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
    id: j['id'],
    startFen: j['startFen'],
    date: j['date'],
    title: j['title'],
    rating: j['rating'],
    humanWhite: j['humanWhite'],
    chess960: j['chess960'],
    opening: j['opening'] ?? '',
    moves: List<String>.from(j['moves']),
    result: j['result'],
    reviews:
        (j['reviews'] as List? ?? [])
            .map((r) => MoveReview.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
  );
}

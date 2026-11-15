import 'catalog.dart';
import 'chess.dart';

/// Local CC0 opening catalogue. Position keys intentionally ignore move clocks
/// and en-passant flags, which do not change the opening's name.
class OpeningLibrary {
  final Map<String, Opening> _positions = {};
  final List<Opening> lines = [];
  void load(List<dynamic> rows) {
    _positions.clear();
    lines.clear();
    for (final row in rows) {
      final opening = Opening(
        row['name'],
        row['eco'],
        '',
        '',
        List<String>.from(row['moves']),
      );
      lines.add(opening);
      _positions[row['fen']] = opening;
    }
  }

  Opening? at(String fen) => _positions[fen.split(' ').take(3).join(' ')];
  String identify(GameRecord game) {
    if (game.chess960) return 'Chess960';
    for (var ply = game.moves.length; ply >= 0; ply--) {
      final named = at(game.fenAt(ply));
      if (named != null) return named.name;
    }
    return '';
  }

  List<Opening> search(String query) {
    if (query.trim().isEmpty) return openings;
    String normalize(String s) => s.toLowerCase().replaceAll('’', "'");
    final terms = normalize(
      query,
    ).split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final matches = <String, Opening>{};
    for (final line in [...openings, ...lines]) {
      final text = normalize('${line.name} ${line.eco}');
      if (terms.every(text.contains)) {
        matches.putIfAbsent(line.name, () => line);
      }
      if (matches.length >= 100) break;
    }
    return matches.values.toList();
  }
}

final openingLibrary = OpeningLibrary();

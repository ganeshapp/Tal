import 'dart:convert';
import 'dart:io';
import 'package:tal/core/chess.dart';

/// Deterministic index of every move in the pinned CC0 opening catalogue.
/// Keeping this in the bundle avoids replaying thousands of lines at startup.
void main() {
  final rows =
      jsonDecode(File('assets/data/openings.json').readAsStringSync()) as List;
  final prefixes = <String, String>{'': initialFen};
  final book = <String, Set<String>>{};
  for (final row in rows) {
    var prefix = '';
    var fen = initialFen;
    for (final move in List<String>.from(row['moves'])) {
      final key = fen.split(' ').take(3).join(' ');
      book.putIfAbsent(key, () => {}).add(move);
      prefix = '$prefix $move';
      fen = prefixes.putIfAbsent(prefix, () {
        final position = ChessPosition(fen: fen);
        if (!position.play(move)) throw StateError('${row['name']}: $move');
        return position.fen;
      });
    }
  }
  final keys = book.keys.toList()..sort();
  File('assets/data/opening_book.json').writeAsStringSync(
    jsonEncode({for (final key in keys) key: book[key]!.toList()..sort()}),
  );
  stdout.writeln(
    '${book.length} positions, ${book.values.fold(0, (n, moves) => n + moves.length)} book moves',
  );
}

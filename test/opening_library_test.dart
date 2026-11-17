import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/openings.dart';

void main() {
  final data =
      jsonDecode(File('assets/data/openings.json').readAsStringSync()) as List;
  final library =
      OpeningLibrary()..load(
        data,
        book: jsonDecode(
          File('assets/data/opening_book.json').readAsStringSync(),
        ),
      );
  GameRecord game(List<String> moves) => GameRecord(
    id: 'opening',
    startFen: initialFen,
    date: '2026-11-15',
    title: 'Maia',
    moves: moves,
  );
  test(
    'Full opening catalogue has legal lines and reproducible position keys',
    () {
      expect(library.lines.length, greaterThan(3800));
      for (final row in data) {
        final pos = ChessPosition();
        for (final move in row['moves']) {
          expect(
            library.containsMove(pos.fen, move),
            isTrue,
            reason: 'Book prefix ${row['name']}: $move',
          );
          expect(pos.play(move), isTrue, reason: '${row['name']}: $move');
        }
        expect(pos.fen.split(' ').take(3).join(' '), row['fen']);
      }
    },
  );
  test(
    'Ordinary French play retains its opening after leaving named theory',
    () {
      final record = game(['e2e4', 'e7e6', 'g1f3', 'd7d5', 'f1c4', 'd5c4']);
      expect(library.identify(record), contains('French'));
      record.moves.removeRange(1, record.moves.length);
      expect(library.identify(record), isNot(contains('French')));
    },
  );
  test('Position matching recognizes move-order transpositions', () {
    final a = game(['e2e4', 'c7c6', 'd2d4', 'd7d5']);
    final b = game(['d2d4', 'd7d5', 'e2e4', 'c7c6']);
    expect(
      a.position().fen.split(' ').take(3),
      b.position().fen.split(' ').take(3),
    );
    expect(library.identify(a), library.identify(b));
    expect(library.identify(a), isNotEmpty);
  });
  test(
    'Opening search finds specific lines and ECO codes beyond suggested lines',
    () {
      expect(library.search('Sicilian Najdorf').length, greaterThan(5));
      expect(library.search('C10'), isNotEmpty);
      expect(library.search('no such opening xyz'), isEmpty);
      expect(library.search('defense').length, lessThanOrEqualTo(100));
    },
  );
}

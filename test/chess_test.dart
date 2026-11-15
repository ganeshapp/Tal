import 'package:bishop/bishop.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tal/core/chess.dart';
import 'package:tal/core/catalog.dart';
import 'package:tal/core/store.dart';

void main() {
  test('Standard rules match known perft positions', () {
    final p = ChessPosition();
    expect(p.game.perft(3), 8902);
  });
  test('Castling, en passant and all four promotions are legal', () {
    final castle = ChessPosition(fen: 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    expect(castle.legal, containsAll(['e1g1', 'e1c1']));
    castle.play('e1g1');
    expect(castle.pieces['g1'], 'K');
    expect(castle.pieces['f1'], 'R');
    final ep = ChessPosition(fen: '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
    expect(ep.play('e5d6'), isTrue);
    expect(ep.pieces.containsKey('d5'), isFalse);
    final promo = ChessPosition(fen: '7k/P7/8/8/8/8/8/4K3 w - - 0 1');
    expect(promo.legal, containsAll(['a7a8q', 'a7a8r', 'a7a8b', 'a7a8n']));
  });
  test('Mate, stalemate and repetition end the game', () {
    final p = ChessPosition();
    for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(p.play(m), isTrue);
    }
    expect(p.result, '0-1');
    expect(p.over, isTrue);
    expect(
      ChessPosition(fen: '7k/5K2/6Q1/8/8/8/8/8 b - - 0 1').result,
      '1/2-1/2',
    );
    final repeated = ChessPosition();
    for (var i = 0; i < 2; i++) {
      for (final m in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        repeated.play(m);
      }
    }
    expect(repeated.over, isTrue);
  });
  test('Chess960 starts preserve bishop colors and king between rooks', () {
    for (var i = 0; i < 960; i++) {
      final pos = ChessPosition(chess960: true, seed: i);
      final back = pos.fen.split(' ').first.split('/').last;
      final bs = [
        for (var j = 0; j < 8; j++)
          if (back[j] == 'B') j,
      ];
      final rs = [
        for (var j = 0; j < 8; j++)
          if (back[j] == 'R') j,
      ];
      expect(bs[0] % 2, isNot(bs[1] % 2));
      expect(back.indexOf('K'), greaterThan(rs.first));
      expect(back.indexOf('K'), lessThan(rs.last));
      final copy = ChessPosition(chess960: true, fen: pos.fen);
      expect(copy.legal.toSet(), pos.legal.toSet());
    }
  });
  test('Chess960 castling handles a king already on its destination', () {
    final p = ChessPosition(
      chess960: true,
      fen: '4k3/8/8/8/8/8/8/6KR w H - 0 1',
    );
    expect(p.legal, contains('g1h1'));
    expect(p.play('g1h1'), isTrue);
    expect(p.pieces['g1'], 'K');
    expect(p.pieces['f1'], 'R');
  });
  test('Every bundled puzzle has a legal setup and complete solution', () {
    final data =
        jsonDecode(File('assets/data/puzzles.json').readAsStringSync()) as List;
    final manifest = jsonDecode(
      File('assets/data/puzzles_manifest.json').readAsStringSync(),
    );
    expect(data.length, manifest['records']);
    expect(data.length, greaterThanOrEqualTo(19000));
    expect(manifest['themes']['queenSacrifice'], greaterThan(100));
    expect(manifest['themes']['mateIn3'], greaterThan(100));
    final ids = <String>{};
    for (final j in data) {
      final puzzle = Puzzle.fromJson(j);
      expect(ids.add(puzzle.id), isTrue);
      final p = ChessPosition(fen: puzzle.fen);
      expect(puzzle.moves.length, greaterThanOrEqualTo(2));
      for (final move in puzzle.moves) {
        expect(p.play(move), isTrue, reason: '${puzzle.id}: $move at ${p.fen}');
      }
    }
  });
  test('All opening lines are legal and drills have playable positions', () {
    for (final line in openings) {
      final p = ChessPosition();
      for (final m in line.moves) {
        expect(p.play(m), isTrue, reason: line.name);
      }
    }
    for (final drill in drills) {
      final p = ChessPosition(fen: drill.fen);
      expect(p.over, isFalse, reason: drill.name);
      expect(p.whiteTurn, drill.white);
    }
  });
  test('Winning-chance loss is symmetric and boundary labels are explicit', () {
    expect(winningChances(0), 50);
    expect(winningChances(300) + winningChances(-300), closeTo(100, 1e-8));
    expect(classifyMove(loss: 4.99), 'Good');
    expect(classifyMove(loss: 5), 'Inaccuracy');
    expect(classifyMove(loss: 10), 'Mistake');
    expect(classifyMove(loss: 20), 'Mistake');
    expect(classifyMove(loss: 20.01), 'Blunder');
    expect(classifyMove(loss: 0, onlyMove: true), 'Great');
    expect(classifyMove(loss: 0, sacrifice: true), 'Brilliant');
  });
  test('SRS uses 1, 3, 7 day intervals and resets failed recall', () {
    final now = DateTime(2026, 11, 15);
    final m = Mistake(
      id: '1',
      fen: initialFen,
      best: 'e2e4',
      played: 'a2a3',
      due: now.add(const Duration(days: 1)),
    );
    expect(m.due.difference(now).inDays, 1);
    m.answer(true, now);
    expect(m.due.difference(now).inDays, 3);
    m.answer(true, now);
    expect(m.due.difference(now).inDays, 7);
    m.answer(false, now);
    expect(m.stage, 0);
    expect(m.due.difference(now).inDays, 1);
  });
  test('Saved session and PGN retain starting FEN and all moves', () {
    final r = GameRecord(
      id: 'a',
      startFen: initialFen,
      date: '2026-11-15T00:00:00',
      title: 'Maia 1500',
      moves: ['e2e4', 'e7e5'],
    );
    final restored = GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.position().fen, r.position().fen);
    expect(restored.pgn(), contains('1. e4 e5 *'));
  });
}

// Native review verification and reproducible UI captures, using real Stockfish
// scores. Run with TAL_ENGINE_DIR set to the built desktop engine directory.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:tal/core/chess.dart';
import 'package:tal/core/engine_native.dart';
import 'package:tal/core/engine_types.dart';
import 'package:tal/core/review.dart';
import 'package:tal/screens/journal.dart';
import 'package:tal/theme.dart';
import '../test/interaction_test.dart' show setup;
import '../test/review_layout_test.dart' show longGame;
import 'render_assets_test.dart' show capture;

class CachedAnalysis implements EngineService {
  final Map<String, Evaluation> cache;
  CachedAnalysis(this.cache);
  @override
  bool get nativeSupported => true;
  @override
  Future<Evaluation> evaluate(
    GameRecord record, {
    int? ply,
    int depth = 14,
  }) async => cache[record.fenAt(ply ?? record.moves.length)]!;
  @override
  Future<String> choose(GameRecord record) =>
      throw UnsupportedError('Review fixture');
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'Actual engine grading and phone review screenshots',
    (t) async {
      final store = await setup(t, const Size(390, 844));
      await t.runAsync(() async {
        await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final native = NativeEngines();
      final records = [
        GameRecord(
          id: 'reported-h3',
          date: '2026-11-17',
          title: 'Maia',
          rating: 1900,
          startFen:
              'r2qk1nr/pppnbpp1/3pp3/7p/3PP1b1/2P2N2/PP2BPPP/RNBQ1RK1 w kq - 2 7',
          moves: ['h2h3'],
        ),
        GameRecord(
          id: 'reported-castling',
          date: '2026-11-17',
          title: 'Maia',
          rating: 1900,
          startFen:
              'r2qkbnr/pppn1pp1/3pp3/7p/3PP1b1/2P2N2/PP2BPPP/RNBQK2R w KQkq - 0 6',
          moves: ['e1g1'],
        ),
        GameRecord(
          id: 'ponziani',
          date: '2026-11-17',
          title: 'Maia',
          rating: 1900,
          startFen: initialFen,
          moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'c2c3'],
        ),
        longGame()..reviews.clear(),
      ];
      final cache = <String, Evaluation>{};
      final results = <Map<String, Object?>>[];
      await t.runAsync(() async {
        try {
          for (final game in records) {
            for (var ply = 0; ply <= game.moves.length; ply++) {
              cache[game.fenAt(ply)] ??= await native.evaluate(
                game,
                ply: ply,
                depth: 16,
              );
              if (ply > 0) {
                game.reviews.add(
                  reviewMove(
                    game,
                    ply - 1,
                    cache[game.fenAt(ply - 1)]!,
                    cache[game.fenAt(ply)]!,
                  ),
                );
              }
            }
            results.add({
              'id': game.id,
              'reviews': game.reviews.map((r) => r.toJson()).toList(),
            });
          }
        } finally {
          await native.dispose();
        }
        final out = File('build/validation/review-results.json');
        out.parent.createSync(recursive: true);
        out.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(results),
        );
      });
      expect(records[0].reviews.single.label, isNot('Brilliant'));
      expect(records[1].reviews.single.label, isNot('Brilliant'));
      expect(records[2].reviews.last.label, 'Book');
      final engine = CachedAnalysis(cache);
      for (final size in [
        const Size(390, 844),
        const Size(360, 640),
        const Size(800, 390),
        const Size(1280, 800),
      ]) {
        t.view.physicalSize = size;
        t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        for (final game in [records[2], records.last]) {
          final key = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: talTheme(),
                home: AnalysisScreen(
                  store: store,
                  engines: engine,
                  record: game,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (var i = 0; i < (game.id == 'ponziani' ? 5 : 18); i++) {
            await t.tap(find.byTooltip('Next (→)'));
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          await capture(
            t,
            key,
            'build/validation/${game.id}-${size.width.toInt()}.png',
            ratio: 2,
          );
          if (size.width == 390 && game.id != 'ponziani') {
            await t.tap(find.text('Summary'));
            await t.pumpAndSettle();
            await capture(t, key, 'build/validation/summary-390.png', ratio: 2);
          }
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        }
      }
      t.view.resetPadding();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

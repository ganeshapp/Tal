import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/analysis_tree.dart';
import '../core/chess.dart';
import '../core/openings.dart';
import '../core/engine.dart';
import '../core/review.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/chess_board.dart';
import '../widgets/chess_controls.dart';
import 'game.dart';

String openingName(GameRecord game) {
  if (game.opening.isNotEmpty) return game.opening;
  final detected = openingLibrary.identify(game);
  return detected.isNotEmpty
      ? detected
      : (game.chess960 ? 'Chess960' : 'Unknown opening');
}

String openingFamily(GameRecord game) => openingName(game).split(':').first;

class JournalScreen extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  const JournalScreen({super.key, required this.store, required this.engines});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String color = 'All colors',
      result = 'All results',
      rating = 'All ratings',
      opening = 'All openings';
  @override
  Widget build(BuildContext context) {
    final games =
        widget.store.games
            .where(
              (g) =>
                  (color == 'All colors' ||
                      g.humanWhite == (color == 'White')) &&
                  (result == 'All results' || g.outcome == result) &&
                  (rating == 'All ratings' || g.rating.toString() == rating) &&
                  (opening == 'All openings' || openingFamily(g) == opening),
            )
            .toList();
    final ratings =
        widget.store.games.map((g) => g.rating).toSet().toList()..sort();
    final names =
        widget.store.games.map(openingFamily).toSet().toList()..sort();
    Widget filter(
      String value,
      List<String> values,
      ValueChanged<String> change,
    ) => SizedBox(
      width:
          value == opening
              ? min(280, MediaQuery.sizeOf(context).width - 32)
              : 130,
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        underline: const SizedBox(),
        isDense: true,
        items:
            values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
        onChanged: (v) => setState(() => change(v!)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Games',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text('${games.length}', style: const TextStyle(color: muted)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              filter(color, ['All colors', 'White', 'Black'], (v) => color = v),
              filter(result, [
                'All results',
                'Won',
                'Lost',
                'Draw',
                'Unfinished',
              ], (v) => result = v),
              filter(rating, [
                'All ratings',
                ...ratings.map((r) => '$r'),
              ], (v) => rating = v),
              filter(opening, ['All openings', ...names], (v) => opening = v),
              if (color != 'All colors' ||
                  result != 'All results' ||
                  rating != 'All ratings' ||
                  opening != 'All openings')
                TextButton(
                  onPressed:
                      () => setState(() {
                        color = 'All colors';
                        result = 'All results';
                        rating = 'All ratings';
                        opening = 'All openings';
                      }),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          Expanded(
            child:
                games.isEmpty
                    ? Center(
                      child: Text(
                        widget.store.games.isEmpty
                            ? 'Finished games and their reviews appear here.'
                            : 'No games match these filters.',
                        style: const TextStyle(color: muted),
                      ),
                    )
                    : ListView.separated(
                      itemCount: games.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final game = games[i];
                        return InkWell(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => AnalysisScreen(
                                        store: widget.store,
                                        engines: widget.engines,
                                        record: game,
                                      ),
                                ),
                              ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Column(
                                    children: [
                                      Text(
                                        game.result == '*' ? '*' : game.result,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        game.outcome,
                                        style: TextStyle(
                                          color:
                                              game.outcome == 'Lost'
                                                  ? rust
                                                  : forest,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '○  ${game.whiteName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '●  ${game.blackName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${openingName(game)} · ${(game.moves.length / 2).ceil()} moves',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      game.date.substring(0, 10),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Icon(
                                      game.reviews.length == game.moves.length
                                          ? Icons.check_circle_outline
                                          : Icons.chevron_right,
                                      size: 20,
                                      color: forest,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class AnalysisScreen extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  final GameRecord record;
  const AnalysisScreen({
    super.key,
    required this.store,
    required this.engines,
    required this.record,
  });
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late AnalysisTree tree;
  bool running = false,
      flipped = false,
      computer = true,
      arrows = true,
      alternatives = false,
      threats = false,
      liveBusy = false;
  bool autoplay = false;
  int tab = 0, liveVersion = 0, analysisVersion = 0;
  String? error, filter;
  bool? filterWhite;
  Timer? playTimer, debounce;
  Evaluation? live, threat;
  final Map<String, Evaluation> cache = {};
  GameRecord get record => widget.record;
  AnalysisNode get node => tree.current;
  int get cursor =>
      node.gamePly ??
      node.path.where((n) => n.gamePly != null).lastOrNull?.gamePly ??
      0;
  MoveReview? get review =>
      node.gamePly == null || node.gamePly == 0
          ? null
          : record.reviews.where((r) => r.ply == node.gamePly! - 1).firstOrNull;
  @override
  void initState() {
    super.initState();
    tree = AnalysisTree(record);
    flipped = !record.humanWhite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLive();
      if (record.reviews.length < record.moves.length &&
          widget.engines.nativeSupported) {
        _analyze();
      }
    });
  }

  @override
  void dispose() {
    analysisVersion++;
    liveVersion++;
    playTimer?.cancel();
    debounce?.cancel();
    widget.store.save();
    super.dispose();
  }

  void _select(AnalysisNode n) {
    setState(() {
      tree.current = n;
      n.parent?.preferredChild = n;
      live = cache[n.fen];
      threat = null;
    });
    _requestLive();
  }

  void _gamePly(int p) {
    _select(tree.mainline[p.clamp(0, record.moves.length)]);
  }

  void _step(int direction) {
    if (direction < 0) {
      if (node.parent != null) _select(node.parent!);
    } else if (node.children.isNotEmpty) {
      _select(node.preferredChild ?? node.children.first);
    } else {
      _stopPlay();
    }
  }

  void _stopPlay() {
    playTimer?.cancel();
    if (mounted) setState(() => autoplay = false);
  }

  void _togglePlay() {
    if (autoplay) {
      _stopPlay();
      return;
    }
    setState(() => autoplay = true);
    playTimer = Timer.periodic(
      const Duration(milliseconds: 1100),
      (_) => _step(1),
    );
  }

  void _move(String move) {
    final next = tree.extend(node, move);
    if (next != null) {
      _stopPlay();
      _select(next);
    }
  }

  void _requestLive() {
    debounce?.cancel();
    final token = ++liveVersion;
    if (!computer || !widget.engines.nativeSupported) {
      setState(() => liveBusy = false);
      return;
    }
    final selected = node;
    setState(() => liveBusy = cache[selected.fen] == null);
    debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final evaluated =
            cache[selected.fen] ??
            await widget.engines.evaluate(tree.recordAt(selected), depth: 16);
        if (!mounted || token != liveVersion) return;
        cache[selected.fen] = evaluated;
        setState(() {
          live = evaluated;
          liveBusy = false;
          error = null;
        });
        if (threats) unawaited(_requestThreat(selected, token));
      } catch (e) {
        if (mounted && token == liveVersion) {
          setState(() {
            error = 'Analysis unavailable: $e';
            liveBusy = false;
          });
        }
      }
    });
  }

  Future<void> _requestThreat(AnalysisNode selected, int token) async {
    final pos = ChessPosition(fen: selected.fen, chess960: record.chess960);
    if (pos.inCheck || pos.over) return;
    final fields = selected.fen.split(' ');
    fields[1] = fields[1] == 'w' ? 'b' : 'w';
    fields[3] = '-';
    final hypothetical = GameRecord(
      id: 'threat',
      startFen: fields.join(' '),
      date: record.date,
      title: record.title,
      chess960: record.chess960,
    );
    try {
      final evaluated = await widget.engines.evaluate(hypothetical, depth: 12);
      if (mounted && token == liveVersion && threats) {
        setState(() => threat = evaluated);
      }
    } catch (_) {
      /* A threat overlay is optional; the position's evaluation remains valid. */
    }
  }

  Future<void> _analyze() async {
    if (running) return;
    final token = ++analysisVersion;
    setState(() {
      running = true;
      error = null;
    });
    try {
      var before = await widget.engines.evaluate(
        record,
        ply: record.reviews.length,
        depth: 16,
      );
      for (var i = record.reviews.length; i < record.moves.length; i++) {
        if (!mounted || token != analysisVersion) return;
        final after =
            terminalEvaluation(record.position(i + 1)) ??
            await widget.engines.evaluate(record, ply: i + 1, depth: 16);
        if (!mounted || token != analysisVersion) return;
        cache[record.fenAt(i)] = before;
        cache[record.fenAt(i + 1)] = after;
        final r = reviewMove(record, i, before, after);
        record.reviews.add(r);
        widget.store.addMistake(record, r);
        if (node.fen == record.fenAt(i + 1)) live = after;
        setState(() {});
        if (i % 8 == 7) unawaited(widget.store.save());
        before = after;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await widget.store.save();
    } catch (e) {
      if (mounted) setState(() => error = 'Game analysis stopped: $e');
    } finally {
      if (mounted && token == analysisVersion) setState(() => running = false);
    }
  }

  void _jumpIssue(int direction) {
    final issues =
        record.reviews.where((r) => r.loss >= 5).map((r) => r.ply + 1).toList();
    if (issues.isEmpty) return;
    final next =
        direction > 0
            ? issues.where((p) => p > cursor).firstOrNull ?? issues.first
            : issues.reversed.where((p) => p < cursor).firstOrNull ??
                issues.last;
    _gamePly(next);
  }

  void _pv(EngineLine line, int index) {
    var parent = node;
    for (final move in line.moves.take(index + 1)) {
      final next = tree.extend(parent, move);
      if (next == null) break;
      parent = next;
    }
    _stopPlay();
    _select(parent);
  }

  void _better() {
    final r = review;
    if (r == null || r.best == r.played || node.parent == null) return;
    final next = tree.extend(node.parent!, r.best);
    if (next != null) _select(next);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
    } else if (key == LogicalKeyboardKey.home) {
      _gamePly(0);
    } else if (key == LogicalKeyboardKey.end) {
      _gamePly(record.moves.length);
    } else if (key == LogicalKeyboardKey.space) {
      _togglePlay();
    } else if (key == LogicalKeyboardKey.keyF) {
      setState(() => flipped = !flipped);
    } else if (key == LogicalKeyboardKey.escape) {
      _gamePly(cursor);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final pos = ChessPosition(fen: node.fen, chess960: record.chess960),
        r = review;
    final terminal =
        node.gamePly != null && record.resultAt(node.gamePly!) == '1/2-1/2'
            ? const Evaluation([EngineLine(cp: 0, depth: 0, moves: [])], '')
            : terminalEvaluation(pos);
    final cp = terminal?.cp ?? live?.cp ?? r?.afterCp,
        mate = terminal?.mate ?? live?.mate ?? r?.afterMate;
    final boardArrows = <BoardArrow>[
      if (arrows && computer && live?.best.isNotEmpty == true)
        BoardArrow(live!.best),
      if (alternatives && computer)
        for (final l in live?.lines.skip(1) ?? <EngineLine>[])
          if (l.moves.isNotEmpty)
            BoardArrow(l.moves.first, const Color(0xFF5684B0)),
      if (threats && threat?.best.isNotEmpty == true)
        BoardArrow(threat!.best, const Color(0xFFBB4642)),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          'Review · ${record.result}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy PGN',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: record.pgn()));
              toast(context, 'PGN copied');
            },
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
          PopupMenuButton<String>(
            tooltip: 'Analysis options',
            onSelected: (v) {
              if (v == 'play') {
                _playPosition();
              } else if (v == 'flip') {
                setState(() => flipped = !flipped);
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: 'flip', child: Text('Flip board')),
                  const PopupMenuItem(
                    value: 'play',
                    child: Text('Play from this position'),
                  ),
                ],
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _key,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 850;
                final side = max(
                  100.0,
                  min(
                    wide ? c.maxWidth * .60 - 34 : c.maxWidth - 34,
                    c.maxHeight - (wide ? 180 : 310),
                  ),
                );
                final board = SizedBox(
                  width: side + 34,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerStrip(
                        name: flipped ? record.whiteName : record.blackName,
                        white: flipped,
                      ),
                      Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            _step(event.scrollDelta.dy > 0 ? 1 : -1);
                          }
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: side,
                              height: side,
                              child: ChessBoard(
                                position: pos,
                                onMove: _move,
                                flipped: flipped,
                                coordinates: widget.store.coordinates,
                                lastMove: node.move,
                                arrows: boardArrows,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 26,
                              height: side,
                              child: EvaluationBar(
                                cp: computer ? cp : null,
                                mate: mate,
                                flipped: flipped,
                                loading: liveBusy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PlayerStrip(
                        name: flipped ? record.blackName : record.whiteName,
                        white: !flipped,
                      ),
                      _navigation(),
                      _feedback(),
                    ],
                  ),
                );
                final panel = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          openingName(record),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    SizedBox(
                      height: wide ? 96 : 58,
                      child: EvaluationGraph(
                        points: _points(),
                        cursor: cursor,
                        onSelect: _gamePly,
                      ),
                    ),
                    _analysisStatus(),
                    SizedBox(
                      height: 38,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() => tab = i),
                                style: TextButton.styleFrom(
                                  backgroundColor: tab == i ? sage : null,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  ['Moves', 'Engine', 'Summary'][i],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (node.gamePly == null) _variation(),
                    Expanded(
                      child:
                          tab == 0
                              ? _moves()
                              : tab == 1
                              ? _engine()
                              : _summary(),
                    ),
                    if (wide && tab != 1)
                      SizedBox(height: 164, child: _engine()),
                  ],
                );
                return wide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        board,
                        const SizedBox(width: 20),
                        Expanded(child: panel),
                      ],
                    )
                    : Column(children: [board, Expanded(child: panel)]);
              },
            ),
          ),
        ),
      ),
    );
  }

  List<double?> _points() {
    final points = List<double?>.filled(record.moves.length + 1, null);
    for (final r in record.reviews) {
      points[r.ply] = winningChances(r.beforeCp);
      points[r.ply + 1] = winningChances(r.afterCp);
    }
    final result = record.resultAt(record.moves.length);
    if (result != '*') {
      points.last =
          result == '1-0'
              ? 100
              : result == '0-1'
              ? 0
              : 50;
    }
    return points;
  }

  Widget _navigation() => SizedBox(
    height: 36,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Start (Home)',
          onPressed: () => _gamePly(0),
          icon: const Icon(Icons.first_page, size: 20),
        ),
        IconButton(
          tooltip: 'Previous (←)',
          onPressed: node.parent == null ? null : () => _step(-1),
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        IconButton(
          tooltip: autoplay ? 'Pause (Space)' : 'Autoplay (Space)',
          onPressed: _togglePlay,
          icon: Icon(autoplay ? Icons.pause : Icons.play_arrow, size: 20),
        ),
        IconButton(
          tooltip: 'Next (→)',
          onPressed: node.children.isEmpty ? null : () => _step(1),
          icon: const Icon(Icons.chevron_right, size: 20),
        ),
        IconButton(
          tooltip: 'End (End)',
          onPressed: () => _gamePly(record.moves.length),
          icon: const Icon(Icons.last_page, size: 20),
        ),
        IconButton(
          tooltip: 'Flip (F)',
          onPressed: () => setState(() => flipped = !flipped),
          icon: const Icon(Icons.flip_camera_android_outlined, size: 18),
        ),
      ],
    ),
  );
  Widget _feedback() {
    final r = review;
    String text =
        node.parent == null
            ? 'Starting position'
            : node.gamePly == null
            ? '${node.san} · variation'
            : r == null
            ? '${node.san} · analysis pending'
            : '${node.san}  ${reviewSymbols[r.label]}  ${r.label}';
    if (node.san.endsWith('#')) text = '${node.san} · Checkmate';
    return Container(
      height: 62,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: sage,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: r == null ? ink : reviewColor(r.label),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (r != null && r.loss >= 1)
                  Text(
                    '${r.loss.toStringAsFixed(1)}% winning chances lost',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          if (r != null && r.best.isNotEmpty && r.best != r.played)
            TextButton(
              onPressed: _better,
              child: Text(
                'Try ${record.boardAt(r.ply).san(r.best)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (node.gamePly == null)
            TextButton(
              onPressed: () => _gamePly(cursor),
              child: const Text('Game', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _analysisStatus() {
    final count = record.reviews.where((r) => r.loss >= 5).length;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          if (running) ...[
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                value: record.reviews.length / max(1, record.moves.length),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${record.reviews.length}/${record.moves.length}',
              style: const TextStyle(fontSize: 10),
            ),
          ] else if (record.reviews.length < record.moves.length)
            TextButton(
              onPressed: widget.engines.nativeSupported ? _analyze : null,
              child: const Text('Analyze', style: TextStyle(fontSize: 11)),
            )
          else
            const Text(
              'Analyzed',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          const Spacer(),
          TextButton(
            onPressed: count > 0 ? () => _jumpIssue(1) : null,
            child: Text(
              '$count ${count == 1 ? 'key move' : 'key moves'}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          IconButton(
            tooltip: 'Previous key move',
            onPressed: count > 0 ? () => _jumpIssue(-1) : null,
            icon: const Icon(Icons.skip_previous, size: 17),
          ),
          IconButton(
            tooltip: 'Next key move',
            onPressed: count > 0 ? () => _jumpIssue(1) : null,
            icon: const Icon(Icons.skip_next, size: 17),
          ),
        ],
      ),
    );
  }

  Widget _moves() => Column(
    children: [
      if (node.children.any((n) => n.gamePly == null))
        SizedBox(
          height: 32,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Variations: ',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                for (final child in node.children.where(
                  (n) => n.gamePly == null,
                ))
                  TextButton(
                    onPressed: () => _select(child),
                    child: Text(
                      child.san,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (filter != null)
        SizedBox(
          height: 30,
          child: Row(
            children: [
              Text(
                '${filterWhite == true
                    ? 'White'
                    : filterWhite == false
                    ? 'Black'
                    : 'All'} · $filter',
                style: const TextStyle(fontSize: 11),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                    () => setState(() {
                      filter = null;
                      filterWhite = null;
                    }),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      Expanded(
        child: MoveTable(
          record: record,
          cursor: node.gamePly ?? -1,
          onSelect: _gamePly,
          filter: filter,
          filterWhite: filterWhite,
        ),
      ),
    ],
  );
  Widget _summary() => ListView(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Move quality',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 70, child: Text('White')),
            SizedBox(width: 70, child: Text('Black')),
          ],
        ),
      ),
      for (final label in reviewLabels)
        Row(
          children: [
            Expanded(
              child: Text(
                '${reviewSymbols[label]}  $label',
                style: TextStyle(fontSize: 12, color: reviewColor(label)),
              ),
            ),
            for (final white in [true, false])
              SizedBox(
                width: 70,
                child: TextButton(
                  onPressed: () {
                    final matches =
                        record.reviews
                            .where(
                              (r) =>
                                  r.label == label &&
                                  record.whiteAt(r.ply) == white,
                            )
                            .toList();
                    setState(() {
                      filter = label;
                      filterWhite = white;
                      tab = 0;
                    });
                    if (matches.isNotEmpty) _gamePly(matches.first.ply + 1);
                  },
                  child: Text(
                    '${record.reviews.where((r) => r.label == label && record.whiteAt(r.ply) == white).length}',
                  ),
                ),
              ),
          ],
        ),
      if (error != null)
        Text(error!, style: const TextStyle(color: rust, fontSize: 11)),
    ],
  );
  Widget _variation() => SizedBox(
    height: 34,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text('Line: ', style: TextStyle(fontSize: 11, color: muted)),
          for (final n in node.path.where((n) => n.gamePly == null))
            TextButton(
              onPressed: () => _select(n),
              child: Text(n.san, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    ),
  );
  Widget _engine() => Column(
    children: [
      SizedBox(
        height: 34,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() => computer = !computer);
                  _requestLive();
                },
                child: Text(
                  computer ? 'Stockfish ●' : 'Stockfish off',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: 'Best move arrow',
                isSelected: arrows,
                onPressed: () => setState(() => arrows = !arrows),
                icon: const Icon(Icons.north_east, size: 17),
              ),
              IconButton(
                tooltip: 'Alternative move arrows',
                isSelected: alternatives,
                onPressed: () => setState(() => alternatives = !alternatives),
                icon: const Icon(Icons.call_split, size: 17),
              ),
              IconButton(
                tooltip: 'Opponent threat (if you pass)',
                isSelected: threats,
                onPressed: () {
                  setState(() {
                    threats = !threats;
                    threat = null;
                  });
                  if (threats) _requestThreat(node, liveVersion);
                },
                icon: const Icon(Icons.warning_amber, size: 17),
              ),
              Text(
                liveBusy
                    ? '…'
                    : live == null
                    ? ''
                    : 'Depth ${live!.depth}',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child:
            !computer
                ? const Center(
                  child: Text(
                    'Computer analysis off',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                )
                : ListView(
                  children: [
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: rust, fontSize: 11),
                      ),
                    if (live == null && liveBusy)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Analyzing position…',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    for (final l in live?.lines ?? <EngineLine>[])
                      if (l.moves.isNotEmpty) _line(l),
                    if (live?.lines.isNotEmpty == true && live!.best.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Game over',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
      ),
    ],
  );
  Widget _line(EngineLine l) {
    final position = ChessPosition(fen: node.fen, chess960: record.chess960),
        items = <Widget>[];
    for (var i = 0; i < l.moves.length && i < 16; i++) {
      if (!position.legal.contains(l.moves[i])) break;
      final san = position.san(l.moves[i]),
          fields = position.fen.split(' '),
          index = i;
      final prefix =
          position.whiteTurn
              ? '${fields[5]}.'
              : i == 0
              ? '${fields[5]}…'
              : '';
      items.add(
        InkWell(
          onTap: () => _pv(l, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('$prefix$san', style: const TextStyle(fontSize: 12)),
          ),
        ),
      );
      position.play(l.moves[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 43,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              evaluationText(l.cp, l.mate),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ),
        Expanded(child: Wrap(children: items)),
      ],
    );
  }

  Future<void> _playPosition() async {
    if (!widget.engines.nativeSupported) return;
    final game = GameRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startFen: record.startFen,
      date: DateTime.now().toIso8601String(),
      title:
          record.chess960
              ? 'Stockfish ${record.rating}'
              : 'Maia ${record.rating}',
      rating: record.rating,
      humanWhite: ChessPosition(fen: node.fen).whiteTurn,
      chess960: record.chess960,
      moves: node.path.map((n) => n.move!).toList(),
      opening: openingName(record),
    );
    if (widget.store.active != null) widget.store.archive(widget.store.active!);
    widget.store.active = game;
    await widget.store.save();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GameScreen(
                store: widget.store,
                engines: widget.engines,
                record: game,
              ),
        ),
      );
    }
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/chess.dart';
import '../core/openings.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/chess_board.dart';
import '../widgets/chess_controls.dart';
import 'journal.dart';

class GameScreen extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  final GameRecord record;
  final String? lesson;
  const GameScreen({
    super.key,
    required this.store,
    required this.engines,
    required this.record,
    this.lesson,
  });
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late ChessPosition pos;
  bool thinking = false, flipped = false, observing = false, paused = false;
  int generation = 0;
  String? error, hint, coachMessage, premove;
  int? viewingPly;
  Evaluation? evaluation;
  bool blunder = false;
  GameRecord get record => widget.record;
  bool get finished => record.result != '*' || pos.over;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pos = record.position();
    flipped = !record.humanWhite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!finished) _bot();
      if (widget.store.evaluation == 'always') _observe();
    });
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    paused = state != AppLifecycleState.resumed;
    if (paused) {
      generation++;
      thinking = false;
      widget.store.save();
    } else if (mounted) {
      setState(() {});
      _bot();
    }
  }

  Future<void> _humanMove(String move) async {
    if (finished || thinking || pos.whiteTurn != record.humanWhite) return;
    final before = GameRecord.fromJson(record.toJson());
    _apply(move);
    final token = generation;
    if (widget.store.evaluation != 'off') {
      unawaited(_observe(before: before, token: token));
    }
    if (!finished) unawaited(_bot());
  }

  void _apply(String move) {
    if (!pos.play(move)) return;
    record.moves.add(move);
    if (!record.chess960) {
      record.opening = openingLibrary.at(pos.fen)?.name ?? record.opening;
    }
    record.reviews = [];
    viewingPly = null;
    hint = null;
    error = null;
    if (widget.store.haptics) HapticFeedback.selectionClick();
    if (pos.over) {
      record.result = pos.result;
      evaluation = terminalEvaluation(pos);
      premove = null;
      generation++;
      widget.store.archive(record);
    } else {
      widget.store.active = record;
      widget.store.save();
    }
    setState(() {});
  }

  Future<void> _bot() async {
    if (finished || pos.whiteTurn == record.humanWhite || thinking || paused) {
      return;
    }
    final token = generation;
    final snapshot = GameRecord.fromJson(record.toJson());
    setState(() {
      thinking = true;
      error = null;
    });
    final watch = Stopwatch()..start();
    try {
      final move = await widget.engines.choose(snapshot);
      final legal = pos.legal;
      final previous = record.moves.isEmpty ? null : record.moves.last;
      final recapture =
          previous != null &&
          move.length >= 4 &&
          previous.substring(2, 4) == move.substring(2, 4);
      final complexity = legal.length;
      final delay =
          widget.store.naturalDelay
              ? (recapture
                  ? 1000
                  : complexity < 12
                  ? 1500
                  : 2000 + Random().nextInt(complexity > 35 ? 13000 : 4000))
              : 0;
      if (watch.elapsedMilliseconds < delay) {
        await Future<void>.delayed(
          Duration(milliseconds: delay - watch.elapsedMilliseconds),
        );
      }
      if (!mounted || generation != token || paused) return;
      if (!pos.legal.contains(move)) {
        throw StateError('The engine returned an invalid move.');
      }
      setState(() => thinking = false);
      _apply(move);
      final queued = premove;
      premove = null;
      if (!finished && queued != null && pos.legal.contains(queued)) {
        await _humanMove(queued);
      }
      if (widget.store.evaluation == 'always') unawaited(_observe());
    } catch (e) {
      if (mounted && generation == token) {
        setState(() {
          thinking = false;
          error =
              'The local opponent could not finish its move. Your game is saved.\n$e';
        });
      }
    }
  }

  Future<void> _observe({GameRecord? before, int? token}) async {
    final version = token ?? generation;
    final snapshot = GameRecord.fromJson(record.toJson());
    final mode = widget.store.evaluation;
    if (finished) {
      setState(() => evaluation = terminalEvaluation(pos));
      return;
    }
    if (mode == 'off') return;
    setState(() => observing = true);
    try {
      Evaluation? prior;
      if (mode == 'blunder' && before != null) {
        prior = await widget.engines.evaluate(before, depth: 12);
      }
      final next = await widget.engines.evaluate(snapshot, depth: 12);
      if (!mounted || generation != version) return;
      if (mode == 'always' && snapshot.moves.length != record.moves.length) {
        return;
      }
      final swing =
          prior == null
              ? 0
              : (prior.cp - next.cp) * (record.humanWhite ? 1 : -1);
      setState(() {
        evaluation = next;
        blunder = swing > 200;
        observing = false;
        coachMessage =
            blunder ? 'Evaluation dropped by more than 2 pawns.' : null;
      });
    } catch (_) {
      if (mounted && generation == version) {
        setState(() {
          observing = false;
          coachMessage =
              'The local evaluation is unavailable. You can keep playing.';
        });
      }
    }
  }

  void _undo() {
    if (record.moves.isEmpty) return;
    premove = null;
    viewingPly = null;
    record.result = '*';
    widget.store.games.removeWhere((g) => g.id == record.id);
    widget.store.active = record;
    generation++;
    thinking = false;
    error = null;
    hint = null;
    coachMessage = null;
    evaluation = null;
    record.moves.removeLast();
    pos = record.position();
    if (pos.whiteTurn != record.humanWhite && record.moves.isNotEmpty) {
      record.moves.removeLast();
      pos = record.position();
    }
    record.reviews = [];
    record.opening = openingLibrary.identify(record);
    widget.store.save();
    setState(() {});
    _bot();
    if (widget.store.evaluation == 'always') _observe();
  }

  Future<void> _hint() async {
    if (thinking || finished) return;
    setState(() => observing = true);
    final token = generation;
    final fen = pos.fen;
    try {
      final e = await widget.engines.evaluate(
        GameRecord.fromJson(record.toJson()),
      );
      if (mounted && token == generation && pos.fen == fen) {
        setState(() {
          hint = e.best.length >= 4 ? e.best : null;
          coachMessage =
              e.best.isEmpty ? null : 'Suggested: ${pos.san(e.best)}';
        });
      }
    } catch (_) {
      if (mounted) toast(context, 'The local coach is unavailable. Try again.');
    } finally {
      if (mounted) setState(() => observing = false);
    }
  }

  void _review() => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => AnalysisScreen(
            store: widget.store,
            engines: widget.engines,
            record: record,
          ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final atLive = viewingPly == null || viewingPly == record.moves.length;
    final shown = atLive ? pos : record.boardAt(viewingPly!);
    final shownPly = atLive ? record.moves.length : viewingPly!;
    final showEval =
        finished ||
        widget.store.evaluation == 'always' ||
        widget.store.evaluation == 'postMove' ||
        widget.store.evaluation == 'blunder' && blunder;
    final terminal = terminalEvaluation(pos);
    final value = terminal ?? evaluation;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          record.opening.isNotEmpty
              ? record.opening
              : record.chess960
              ? 'Chess960'
              : 'Play',
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
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 780;
              final side = max(
                120.0,
                min(
                  wide ? c.maxWidth * .61 - 34 : c.maxWidth - 34,
                  c.maxHeight - (wide ? 162 : 256),
                ),
              );
              Widget status() => SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        !atLive
                            ? 'Move ${(shownPly + 1) ~/ 2} · browsing'
                            : finished
                            ? '${record.result} · ${pos.inCheck && pos.over ? 'Checkmate' : pos.outcome ?? 'Game ended'}'
                            : error != null
                            ? 'Engine error'
                            : premove != null
                            ? 'Premove queued'
                            : thinking
                            ? '${record.botName} is thinking…'
                            : pos.inCheck
                            ? 'Check · your move'
                            : coachMessage ?? 'Your move',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              finished ? FontWeight.w700 : FontWeight.w500,
                          color: error != null ? rust : ink,
                        ),
                      ),
                    ),
                    if (!atLive)
                      TextButton(
                        onPressed: () => setState(() => viewingPly = null),
                        child: const Text('Live'),
                      ),
                    if (atLive && finished)
                      FilledButton(
                        onPressed: _review,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Review'),
                      ),
                    if (error != null)
                      TextButton(onPressed: _bot, child: const Text('Retry')),
                    if (premove != null && !finished)
                      IconButton(
                        tooltip: 'Cancel premove',
                        onPressed: () => setState(() => premove = null),
                        icon: const Icon(Icons.close, size: 17),
                      ),
                  ],
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
                      active: !finished && pos.whiteTurn == flipped,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: side,
                          height: side,
                          child: ChessBoard(
                            position: shown,
                            flipped: flipped,
                            coordinates: widget.store.coordinates,
                            interactive:
                                atLive &&
                                !finished &&
                                !thinking &&
                                pos.whiteTurn == record.humanWhite,
                            onMove: _humanMove,
                            premoveWhite:
                                atLive && !finished && widget.store.premoves
                                    ? record.humanWhite
                                    : null,
                            premove: premove,
                            onPremove: (m) => setState(() => premove = m),
                            onCancelPremove:
                                () => setState(() => premove = null),
                            lastMove:
                                shownPly > 0
                                    ? record.moves[shownPly - 1]
                                    : null,
                            arrows:
                                hint != null && atLive
                                    ? [BoardArrow(hint!)]
                                    : [],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 26,
                          height: side,
                          child:
                              showEval && atLive
                                  ? EvaluationBar(
                                    cp: value?.cp,
                                    mate: value?.mate,
                                    flipped: flipped,
                                    loading: observing,
                                  )
                                  : const SizedBox(),
                        ),
                      ],
                    ),
                    PlayerStrip(
                      name: flipped ? record.blackName : record.whiteName,
                      white: !flipped,
                      active: !finished && pos.whiteTurn != flipped,
                    ),
                    SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Take back',
                            onPressed: record.moves.isNotEmpty ? _undo : null,
                            icon: const Icon(Icons.undo, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Hint',
                            onPressed: !finished && !thinking ? _hint : null,
                            icon: const Icon(Icons.lightbulb_outline, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Flip board',
                            onPressed: () => setState(() => flipped = !flipped),
                            icon: const Icon(
                              Icons.flip_camera_android_outlined,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Evaluation',
                            onPressed: _evalOptions,
                            icon: const Icon(Icons.tune, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Resign',
                            onPressed: !finished ? _resign : null,
                            icon: const Icon(Icons.flag_outlined, size: 20),
                          ),
                        ],
                      ),
                    ),
                    status(),
                  ],
                ),
              );
              final moves = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.lesson != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        widget.lesson!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (record.opening.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        record.opening,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  Expanded(
                    child: MoveTable(
                      record: record,
                      cursor: shownPly,
                      onSelect: (p) => setState(() => viewingPly = p),
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'First position',
                          onPressed: () => setState(() => viewingPly = 0),
                          icon: const Icon(Icons.first_page, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Previous move',
                          onPressed:
                              shownPly > 0
                                  ? () =>
                                      setState(() => viewingPly = shownPly - 1)
                                  : null,
                          icon: const Icon(Icons.chevron_left, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Next move',
                          onPressed:
                              shownPly < record.moves.length
                                  ? () =>
                                      setState(() => viewingPly = shownPly + 1)
                                  : null,
                          icon: const Icon(Icons.chevron_right, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Latest position',
                          onPressed: () => setState(() => viewingPly = null),
                          icon: const Icon(Icons.last_page, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              return wide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      board,
                      const SizedBox(width: 24),
                      Expanded(child: moves),
                    ],
                  )
                  : Column(children: [board, Expanded(child: moves)]);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _evalOptions() async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Evaluation bar'),
            children: [
              for (final e
                  in {
                    'off': 'Off',
                    'always': 'Always visible',
                    'postMove': 'After your move',
                    'blunder': 'Blunder alerts',
                  }.entries)
                RadioListTile<String>(
                  value: e.key,
                  groupValue: widget.store.evaluation,
                  title: Text(e.value),
                  onChanged: (v) {
                    widget.store.evaluation = v!;
                    widget.store.save();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
    );
    if (mounted) {
      setState(() => blunder = false);
      if (widget.store.evaluation == 'always') _observe();
    }
  }

  Future<void> _resign() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Resign this game?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resign'),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    generation++;
    thinking = false;
    premove = null;
    record.result = record.humanWhite ? '0-1' : '1-0';
    widget.store.archive(record);
    setState(() {});
  }
}

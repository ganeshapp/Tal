import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/catalog.dart';
import '../core/openings.dart';
import '../core/chess.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/chess_board.dart';
import 'game.dart';
import 'puzzles.dart';
export 'puzzles.dart' show PuzzleScreen, openPuzzle;

class TrainingPage extends StatelessWidget {
  final AppStore store;
  final EngineService engines;
  final int initialTab;
  const TrainingPage({
    super.key,
    required this.store,
    required this.engines,
    this.initialTab = 0,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Practice', style: TextStyle(fontFamily: 'Lora')),
    ),
    body: TrainingHub(
      store: store,
      engines: engines,
      initialTab: initialTab,
      showTitle: false,
    ),
  );
}

class TrainingHub extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  final int initialTab;
  final bool showTitle;
  const TrainingHub({
    super.key,
    required this.store,
    required this.engines,
    this.initialTab = 0,
    this.showTitle = true,
  });
  @override
  State<TrainingHub> createState() => _TrainingHubState();
}

class _TrainingHubState extends State<TrainingHub> {
  late int tab = widget.initialTab;
  String openingQuery = '';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle)
              const Text(
                'Practice',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            if (widget.showTitle) const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      ['Puzzles', 'Openings', 'Endgames', 'Your mistakes'][i],
                    ),
                    selected: tab == i,
                    onSelected: (_) => setState(() => tab = i),
                  ),
              ],
            ),
            const SizedBox(height: 25),
            if (tab == 0) _puzzles(),
            if (tab == 1) ...[
              const Text(
                'Opening practice',
                style: TextStyle(fontFamily: 'Lora', fontSize: 22),
              ),
              const SizedBox(height: 10),
              const Text(
                'Rehearse a useful line, then continue against Maia and explore the replies it predicts.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search opening or ECO',
                ),
                onChanged:
                    (v) => setState(() => openingQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 12),
              Text(
                '${openings.length} suggested lines · Search ${openingLibrary.lines.length} named openings',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              for (final opening in openingLibrary.search(openingQuery))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _row(
                    Icons.route_outlined,
                    opening.name,
                    '${opening.eco} · ${opening.moves.length} plies',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => OpeningScreen(
                              store: widget.store,
                              engines: widget.engines,
                              opening: opening,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
            if (tab == 2) ...[
              const Text(
                'Endgame positions',
                style: TextStyle(fontFamily: 'Lora', fontSize: 22),
              ),
              const SizedBox(height: 12),
              const Text(
                'Practice these positions against your local opponent. The coach is there when you need a hint.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 20),
              for (final drill in drills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _row(
                    Icons.flag_outlined,
                    drill.name,
                    drill.category,
                    () => _startDrill(drill),
                  ),
                ),
            ],
            if (tab == 3)
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.replay_rounded, size: 34, color: forest),
                    const SizedBox(height: 20),
                    Text(
                      widget.store.mistakes.isEmpty
                          ? 'No mistakes saved yet'
                          : '${widget.store.due.length} positions ready to revisit',
                      style: const TextStyle(fontFamily: 'Lora', fontSize: 25),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'After a game review, your blunders become personal exercises. Revisit them after 1 day, 3 days, and a week. ',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => MistakesScreen(store: widget.store),
                            ),
                          ),
                      child: const Text('Open your review queue'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: forest),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Lora', fontSize: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: muted, size: 19),
          ],
        ),
      ),
    ),
  );
  Widget _puzzles() => PuzzleHub(store: widget.store);
  Future<void> _startDrill(Drill drill) async {
    final record = GameRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startFen: drill.fen,
      date: DateTime.now().toIso8601String(),
      title:
          widget.engines.nativeSupported
              ? 'Maia ${widget.store.rating}'
              : 'Practice bot',
      rating: widget.store.rating,
      humanWhite: drill.white,
    );
    if (widget.store.active != null) widget.store.archive(widget.store.active!);
    widget.store.active = record;
    await widget.store.save();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GameScreen(
                store: widget.store,
                engines: widget.engines,
                record: record,
                lesson: drill.lesson,
              ),
        ),
      );
    }
  }
}

class OpeningScreen extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  final Opening opening;
  const OpeningScreen({
    super.key,
    required this.store,
    required this.engines,
    required this.opening,
  });
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  ChessPosition pos = ChessPosition();
  int step = 0;
  late int rating = widget.store.rating;
  bool humanWhite = true, busy = false, rehearsing = false;
  String? message, hint;
  bool get complete => step >= widget.opening.moves.length;
  Future<void> _start() async {
    pos = ChessPosition();
    step = 0;
    message = null;
    hint = null;
    setState(() => rehearsing = true);
    await _reply();
  }

  Future<void> _reply() async {
    if (complete || pos.whiteTurn == humanWhite) return;
    setState(() => busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    pos.play(widget.opening.moves[step++]);
    setState(() => busy = false);
  }

  Future<void> _move(String move) async {
    if (busy || complete) return;
    if (move != widget.opening.moves[step]) {
      setState(
        () =>
            message =
                'That is not the move in this line. Try again or use a hint.',
      );
      return;
    }
    pos.play(move);
    step++;
    message = null;
    hint = null;
    setState(() {});
    await _reply();
  }

  Future<void> _play() async {
    if (!widget.engines.nativeSupported) return;
    final game = GameRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startFen: initialFen,
      date: DateTime.now().toIso8601String(),
      title: 'Maia $rating',
      rating: rating,
      humanWhite: humanWhite,
      moves: widget.opening.moves.toList(),
      opening: widget.opening.name,
    );
    if (widget.store.active != null) widget.store.archive(widget.store.active!);
    widget.store.active = game;
    widget.store.rating = rating;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 48,
      title: Text(widget.opening.name, style: const TextStyle(fontSize: 17)),
    ),
    body: LayoutBuilder(
      builder:
          (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!rehearsing) ...[
                      Text(
                        '${widget.opening.eco}${widget.opening.lesson.isEmpty ? '' : ' · ${widget.opening.lesson}'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Play White')),
                          ButtonSegment(
                            value: false,
                            label: Text('Play Black'),
                          ),
                        ],
                        selected: {humanWhite},
                        onSelectionChanged:
                            (s) => setState(() => humanWhite = s.first),
                      ),
                      const SizedBox(height: 12),
                      DropdownButton<int>(
                        value: rating,
                        isExpanded: true,
                        items:
                            maiaRatings
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text('Maia 3 · $r'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => rating = v!),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed:
                            widget.engines.nativeSupported ? _play : null,
                        child: const Text('Play from this opening'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _start,
                        child: const Text('Rehearse the line'),
                      ),
                      const SizedBox(height: 18),
                      Wrap(spacing: 8, children: _lineNotation()),
                    ] else ...[
                      Align(
                        child: SizedBox(
                          width: min(
                            c.maxWidth - 32,
                            max(160, c.maxHeight - 220),
                          ),
                          child: ChessBoard(
                            position: pos,
                            flipped: !humanWhite,
                            onMove: _move,
                            interactive: !busy && !complete,
                            lastMove:
                                step > 0
                                    ? widget.opening.moves[step - 1]
                                    : null,
                            arrows: hint == null ? [] : [BoardArrow(hint!)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        complete
                            ? 'Line complete'
                            : busy
                            ? 'Opponent’s move'
                            : '${humanWhite ? 'White' : 'Black'} to move · $step/${widget.opening.moves.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (message != null)
                        Text(
                          message!,
                          style: const TextStyle(color: rust, fontSize: 12),
                        ),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (!complete)
                            TextButton(
                              onPressed:
                                  () => setState(() {
                                    hint = widget.opening.moves[step];
                                    message = pos.san(hint!);
                                  }),
                              child: const Text('Hint'),
                            ),
                          TextButton(
                            onPressed: _start,
                            child: const Text('Restart'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => rehearsing = false),
                            child: const Text('Change side / bot'),
                          ),
                          if (complete)
                            FilledButton(
                              onPressed:
                                  widget.engines.nativeSupported ? _play : null,
                              child: const Text('Continue against Maia'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
    ),
  );
  List<Widget> _lineNotation() {
    final p = ChessPosition();
    return widget.opening.moves.asMap().entries.map((e) {
      final s = p.san(e.value);
      p.play(e.value);
      return Text('${e.key.isEven ? '${e.key ~/ 2 + 1}. ' : ''}$s');
    }).toList();
  }
}

class MistakesScreen extends StatefulWidget {
  final AppStore store;
  const MistakesScreen({super.key, required this.store});
  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  late List<Mistake> queue = widget.store.due;
  int index = 0;
  bool failed = false, answered = false;
  String? message;
  ChessPosition? pos;
  @override
  void initState() {
    super.initState();
    if (queue.isNotEmpty) {
      pos = ChessPosition(fen: queue.first.fen, chess960: queue.first.chess960);
    }
  }

  void _answer(String move) {
    if (answered) return;
    final item = queue[index];
    if (move != item.best) {
      setState(() {
        failed = true;
        message = 'Look once more for the strongest continuation.';
      });
      return;
    }
    pos!.play(move);
    item.answer(!failed, DateTime.now());
    widget.store.save();
    setState(() {
      answered = true;
      message =
          failed
              ? 'Good. You’ll see this position again tomorrow.'
              : 'Remembered. The next review is ${item.due.month}/${item.due.day}.';
    });
  }

  void _next() {
    setState(() {
      index++;
      answered = false;
      failed = false;
      message = null;
      if (index < queue.length) {
        pos = ChessPosition(
          fen: queue[index].fen,
          chess960: queue[index].chess960,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Make mistakes matter',
        style: TextStyle(fontFamily: 'Lora'),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child:
              index >= queue.length
                  ? Surface(
                    child: Column(
                      children: [
                        const Icon(Icons.spa_outlined, size: 44, color: forest),
                        const SizedBox(height: 24),
                        const Text(
                          'Room for something new.',
                          style: TextStyle(fontFamily: 'Lora', fontSize: 27),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.store.mistakes.isEmpty
                              ? 'Analyze a game to save mistakes for practice.'
                              : 'You’re up to date. Your next reviews will be waiting when they’re due.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to the board'),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Eyebrow('Your position ${index + 1} of ${queue.length}'),
                      const SizedBox(height: 18),
                      ChessBoard(
                        position: pos!,
                        flipped:
                            !ChessPosition(
                              fen: queue[index].fen,
                              chess960: queue[index].chess960,
                            ).whiteTurn,
                        onMove: _answer,
                        interactive: !answered,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        message ??
                            'You’ve been here before. What would you play now?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 20),
                      if (answered)
                        FilledButton(
                          onPressed: _next,
                          child: const Text('Keep going'),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            failed = true;
                            setState(
                              () =>
                                  message =
                                      'Look for ${pos!.san(queue[index].best)}. Play it on the board to remember the pattern.',
                            );
                          },
                          child: const Text('Show me the idea'),
                        ),
                    ],
                  ),
        ),
      ),
    ),
  );
}

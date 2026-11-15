import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/chess.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/chess_board.dart';

void openPuzzle(
  BuildContext context,
  AppStore store, {
  String mode = 'standard',
  String? theme,
  int? offset,
  int minutes = 3,
  String? puzzleId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => PuzzleScreen(
            store: store,
            mode: mode,
            theme: theme ?? store.puzzleProgress.theme,
            offset: offset ?? store.puzzleProgress.offset,
            minutes: minutes,
            puzzleId: puzzleId,
          ),
    ),
  );
}

class PuzzleHub extends StatefulWidget {
  final AppStore store;
  const PuzzleHub({super.key, required this.store});
  @override
  State<PuzzleHub> createState() => _PuzzleHubState();
}

class _PuzzleHubState extends State<PuzzleHub> {
  int minutes = 3;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final p = widget.store.puzzleProgress;
      final target = puzzleTarget(p.rating.rating, p.offset);
      final count =
          widget.store.puzzles
              .where(
                (v) =>
                    (p.theme == 'mix' || v.themes.contains(p.theme)) &&
                    (v.rating - target).abs() <= 100 &&
                    !p.exposed.contains(v.id),
              )
              .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puzzle rating  ${p.rating.label}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${p.rating.count} rated attempt${p.rating.count == 1 ? '' : 's'}${p.rating.provisional ? ' · Provisional' : ''}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Puzzle dashboard',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PuzzleDashboard(store: widget.store),
                      ),
                    ),
                icon: const Icon(Icons.insights_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _chooseTheme(context, widget.store),
            icon: const Icon(Icons.filter_list),
            label: Text(puzzleThemeName(p.theme)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Difficulty',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final offset in [-200, -100, 0, 100, 200])
                ChoiceChip(
                  label: Text(
                    offset == 0
                        ? 'Your rating'
                        : '${offset > 0 ? '+' : ''}$offset',
                  ),
                  selected: p.offset == offset,
                  showCheckmark: false,
                  onSelected: (_) {
                    p.offset = offset;
                    widget.store.save();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Target $target · Range ${max(400, target - 100)}–${min(3199, target + 100)} · $count unseen',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                count > 0 ? () => openPuzzle(context, widget.store) : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Solve puzzles'),
          ),
          if (count == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No unseen puzzles in this range. Change the theme or difficulty, or replay from your dashboard.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Puzzle Storm',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              for (final m in [3, 5])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$m min'),
                    selected: minutes == m,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => minutes = m),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Progressively harder · Best: ${p.stormBests[minutes] ?? 0}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                () => openPuzzle(
                  context,
                  widget.store,
                  mode: 'storm',
                  theme: 'mix',
                  minutes: minutes,
                ),
            icon: const Icon(Icons.bolt),
            label: const Text('Start Storm'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Puzzle Streak',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Until the first mistake · Best: ${p.streakBest}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                () => openPuzzle(
                  context,
                  widget.store,
                  mode: 'streak',
                  theme: 'mix',
                ),
            icon: const Icon(Icons.all_inclusive),
            label: const Text('Start Streak'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Storm, Streak and replays do not change your puzzle rating.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      );
    },
  );
}

Future<void> _chooseTheme(BuildContext context, AppStore store) async {
  final counts = <String, int>{};
  for (final p in store.puzzles) {
    for (final t in p.themes) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final keys =
      counts.keys.toList()
        ..sort((a, b) => puzzleThemeName(a).compareTo(puzzleThemeName(b)));
  var query = '';
  final theme = await showDialog<String>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Puzzle themes'),
                content: SizedBox(
                  width: 440,
                  height: 440,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search themes',
                        ),
                        onChanged:
                            (v) => setState(() => query = v.toLowerCase()),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            ListTile(
                              title: const Text('Mixed puzzles'),
                              trailing: Text('${store.puzzles.length}'),
                              onTap: () => Navigator.pop(context, 'mix'),
                            ),
                            for (final t in keys.where(
                              (t) => puzzleThemeName(
                                t,
                              ).toLowerCase().contains(query),
                            ))
                              ListTile(
                                dense: true,
                                title: Text(puzzleThemeName(t)),
                                trailing: Text('${counts[t]}'),
                                onTap: () => Navigator.pop(context, t),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        ),
  );
  if (theme != null) {
    store.puzzleProgress.theme = theme;
    await store.save();
  }
}

class PuzzleScreen extends StatefulWidget {
  final AppStore store;
  final String mode, theme;
  final int offset, minutes;
  final String? puzzleId;
  final DateTime Function()? clock;
  const PuzzleScreen({
    super.key,
    required this.store,
    this.mode = 'standard',
    this.theme = 'mix',
    this.offset = 0,
    this.minutes = 3,
    this.puzzleId,
    this.clock,
  });
  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  DateTime _now() => widget.clock?.call() ?? DateTime.now();
  final used = <String>{};
  Puzzle? puzzle;
  ChessPosition? pos;
  PuzzleAttempt? attempt;
  final Stopwatch elapsed = Stopwatch();
  int step = 1, score = 0, seconds = 0, version = 0, solutionPly = 0;
  bool busy = false,
      solved = false,
      ended = false,
      revealed = false,
      firstExposure = false,
      started = false;
  String? hint, message, lastMove;
  DateTime? deadline;
  Timer? timer, transition;
  Completer<bool>? pendingTransition;
  Future<bool> _pause(int milliseconds) {
    _cancelTransition();
    final done = Completer<bool>();
    pendingTransition = done;
    transition = Timer(Duration(milliseconds: milliseconds), () {
      if (!done.isCompleted) done.complete(true);
    });
    return done.future;
  }

  void _cancelTransition() {
    transition?.cancel();
    if (pendingTransition != null && !pendingTransition!.isCompleted) {
      pendingTransition!.complete(false);
    }
  }

  bool get timed => widget.mode == 'storm';
  bool get speed => timed || widget.mode == 'streak';
  PuzzleProgress get progress => widget.store.puzzleProgress;
  @override
  void initState() {
    super.initState();
    seconds = widget.minutes * 60;
    if (!timed) {
      started = true;
      _load();
    }
  }

  void _load() {
    version++;
    final target =
        speed
            ? speedPuzzleTarget(score)
            : puzzleTarget(progress.rating.rating, widget.offset);
    final explicit = widget.puzzleId;
    puzzle =
        explicit != null && used.isEmpty
            ? widget.store.puzzles.where((p) => p.id == explicit).firstOrNull
            : selectPuzzle(
              widget.store.puzzles,
              target: target,
              theme: speed ? 'mix' : widget.theme,
              exclude: {
                ...used,
                if (!speed && widget.mode != 'replay') ...progress.exposed,
              },
            );
    if (puzzle == null) {
      if (speed) {
        _end();
      }
      return;
    }
    used.add(puzzle!.id);
    firstExposure = !progress.exposed.contains(puzzle!.id);
    progress.exposed.add(puzzle!.id);
    widget.store.save();
    pos = puzzle!.start();
    step = 1;
    solved = false;
    revealed = false;
    busy = false;
    attempt = null;
    message = null;
    hint = null;
    lastMove = puzzle!.moves.first;
    solutionPly = 1;
    elapsed
      ..reset()
      ..start();
  }

  void _startStorm() {
    deadline = _now().add(Duration(minutes: widget.minutes));
    started = true;
    _load();
    setState(() {});
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || ended) return;
      final remaining = max(
        0,
        (deadline!.difference(_now()).inMilliseconds / 1000).ceil(),
      );
      if (remaining == 0) {
        _end();
      } else if (seconds != remaining) {
        setState(() => seconds = remaining);
      }
    });
  }

  bool _expired() {
    if (timed && deadline != null && !_now().isBefore(deadline!)) {
      _end();
      return true;
    }
    return false;
  }

  void _record(bool success, {bool assisted = false}) {
    if (attempt != null || puzzle == null) return;
    attempt = progress.record(
      puzzle!,
      success: success,
      assisted: assisted,
      mode: widget.mode,
      firstExposure: firstExposure,
      elapsed: elapsed.elapsed,
    );
    if (attempt!.success) widget.store.solved.add(puzzle!.id);
    widget.store.save();
  }

  Future<void> _move(String move) async {
    if (busy || solved || ended || revealed || puzzle == null || _expired()) {
      return;
    }
    if (!pos!.legal.contains(move)) return;
    final candidate = ChessPosition(fen: pos!.fen)..play(move);
    final mate = candidate.result == (pos!.whiteTurn ? '1-0' : '0-1');
    if (move != puzzle!.moves[step] && !mate) {
      _record(false);
      message = 'Incorrect. Try again or view the solution.';
      if (widget.mode == 'streak') {
        _end();
        return;
      }
      if (timed) {
        deadline = deadline!.subtract(const Duration(seconds: 5));
        message = 'Incorrect · −5 seconds';
        if (_expired()) return;
        busy = true;
        setState(() {});
        final token = version;
        await _pause(450);
        if (!mounted || token != version || ended) return;
        setState(_load);
        return;
      }
      setState(() {});
      return;
    }
    pos!.play(move);
    lastMove = move;
    hint = null;
    step++;
    if (mate || step >= puzzle!.moves.length) {
      _solved();
      return;
    }
    busy = true;
    setState(() {});
    final token = version;
    await _pause(220);
    if (!mounted || token != version || ended || _expired()) return;
    pos!.play(puzzle!.moves[step]);
    lastMove = puzzle!.moves[step++];
    busy = false;
    if (step >= puzzle!.moves.length) {
      _solved();
    } else {
      setState(() {});
    }
  }

  void _solved() {
    _record(true);
    solved = true;
    busy = false;
    message = attempt!.success ? 'Solved' : 'Solved after retry';
    if (attempt!.success) score++;
    setState(() {});
    if (speed) {
      final token = version;
      _pause(450).then((_) {
        if (mounted && token == version && !ended && !_expired()) {
          setState(_load);
        }
      });
    }
  }

  void _end() {
    if (ended) return;
    version++;
    timer?.cancel();
    _cancelTransition();
    elapsed.stop();
    ended = true;
    busy = false;
    if (timed) {
      seconds = max(
        0,
        deadline == null
            ? seconds
            : (deadline!.difference(_now()).inMilliseconds / 1000).ceil(),
      );
      progress.stormBests[widget.minutes] = max(
        progress.stormBests[widget.minutes] ?? 0,
        score,
      );
    } else {
      progress.streakBest = max(progress.streakBest, score);
    }
    widget.store.save();
    if (mounted) setState(() {});
  }

  void _hint() {
    _record(false, assisted: true);
    setState(() {
      hint = puzzle!.moves[step].substring(0, 2);
      message = 'Move the highlighted piece. This attempt is assisted.';
    });
  }

  void _solution() {
    _record(false, assisted: true);
    version++;
    busy = false;
    revealed = true;
    solutionPly = 1;
    _showSolution(1);
  }

  void _showSolution(int ply) {
    solutionPly = ply.clamp(1, puzzle!.moves.length);
    pos = ChessPosition(fen: puzzle!.fen);
    for (final m in puzzle!.moves.take(solutionPly)) {
      pos!.play(m);
    }
    lastMove = puzzle!.moves[solutionPly - 1];
    hint = null;
    setState(() {});
  }

  @override
  void dispose() {
    version++;
    timer?.cancel();
    _cancelTransition();
    elapsed.stop();
    super.dispose();
  }

  Widget _status() {
    final a = attempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ended)
          Text(
            '${timed ? 'Storm' : 'Streak'} finished · $score solved',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          )
        else if (speed)
          Text(
            '$score solved${timed ? '  ·  ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}' : ''}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          )
        else
          Text(
            message ?? (pos!.whiteTurn ? 'White to move' : 'Black to move'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: a != null && !a.success ? rust : ink,
            ),
          ),
        if (speed && message != null && !ended)
          Text(message!, style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        if (!speed)
          Text(
            a == null
                ? 'Rating ${progress.rating.label} · ${firstExposure && widget.mode == 'standard' ? 'Rated' : 'Unrated replay'}'
                : a.rated
                ? 'Rating ${a.after.round()} (${a.delta >= 0 ? '+' : ''}${a.delta})'
                : 'Unrated attempt',
            style: const TextStyle(fontSize: 13, color: muted),
          ),
        if (a != null || ended)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Puzzle ${puzzle!.rating} · ${puzzle!.themes.where((t) => puzzleThemeNames.containsKey(t)).map(puzzleThemeName).take(4).join(' · ')}',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
        const SizedBox(height: 12),
        if (revealed) ...[
          const Text('Solution', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: _solutionButtons()),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous solution move',
                onPressed:
                    solutionPly > 1
                        ? () => _showSolution(solutionPly - 1)
                        : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next solution move',
                onPressed:
                    solutionPly < puzzle!.moves.length
                        ? () => _showSolution(solutionPly + 1)
                        : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!speed && (solved || revealed || a != null))
              FilledButton(
                onPressed: () => setState(_load),
                child: const Text('Next puzzle'),
              ),
            if (!speed && !solved && !revealed)
              OutlinedButton(
                onPressed: busy ? null : _hint,
                child: const Text('Hint'),
              ),
            if ((!speed || ended) && !revealed)
              OutlinedButton(
                onPressed: busy ? null : _solution,
                child: const Text('View solution'),
              ),
            if (ended)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _solutionButtons() {
    final position = ChessPosition(fen: puzzle!.fen);
    final buttons = <Widget>[];
    for (var i = 0; i < puzzle!.moves.length; i++) {
      final san = position.san(puzzle!.moves[i]);
      position.play(puzzle!.moves[i]);
      if (i == 0) continue;
      final ply = i + 1;
      buttons.add(
        ChoiceChip(
          label: Text(san),
          selected: solutionPly == ply,
          showCheckmark: false,
          onSelected: (_) => _showSolution(ply),
        ),
      );
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        timed
            ? 'Storm · ${widget.minutes} min'
            : widget.mode == 'streak'
            ? 'Puzzle Streak'
            : puzzleThemeName(widget.theme),
      ),
      actions: [
        if (speed && started && !ended)
          TextButton(onPressed: _end, child: const Text('End run')),
      ],
    ),
    body:
        !started
            ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.minutes} minutes',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Puzzles get harder as you solve.\nWrong move: −5 seconds.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _startStorm,
                    child: const Text('Start timer'),
                  ),
                ],
              ),
            )
            : puzzle == null
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ended
                          ? 'Run complete · $score solved'
                          : 'No unseen puzzles in this rating range.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose another theme or difficulty in Practice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to practice'),
                    ),
                  ],
                ),
              ),
            )
            : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 850;
                final size =
                    min(
                      wide ? c.maxWidth - 390 : c.maxWidth - 24,
                      max(140.0, c.maxHeight - (wide ? 24 : 230)),
                    ).toDouble();
                final board = SizedBox(
                  width: size,
                  height: size,
                  child: ChessBoard(
                    position: pos!,
                    flipped: !puzzle!.start().whiteTurn,
                    interactive: !busy && !solved && !ended && !revealed,
                    lastMove: lastMove,
                    hint: hint,
                    coordinates: widget.store.coordinates,
                    onMove: _move,
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      wide
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              board,
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 340,
                                child: SingleChildScrollView(child: _status()),
                              ),
                            ],
                          )
                          : Column(
                            children: [
                              Center(child: board),
                              const SizedBox(height: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: _status(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                );
              },
            ),
  );
}

class PuzzleDashboard extends StatefulWidget {
  final AppStore store;
  const PuzzleDashboard({super.key, required this.store});
  @override
  State<PuzzleDashboard> createState() => _PuzzleDashboardState();
}

class _PuzzleDashboardState extends State<PuzzleDashboard> {
  int days = 30;
  String section = 'Overview';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Puzzle dashboard')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final progress = widget.store.puzzleProgress;
        final since = DateTime.now().subtract(Duration(days: days));
        final attempts =
            progress.attempts
                .where((a) => days == 0 || a.date.isAfter(since))
                .toList();
        final rated = attempts.where((a) => a.rated).toList();
        final solved = rated.where((a) => a.success).length;
        final stats =
            <String, ({int played, int solved, PuzzleRating rating})>{};
        for (final t in progress.themes.keys) {
          final rows = rated.where((a) => a.themes.contains(t)).toList();
          if (rows.isNotEmpty) {
            stats[t] = (
              played: rows.length,
              solved: rows.where((a) => a.success).length,
              rating: progress.themes[t]!,
            );
          }
        }
        final ranked =
            stats.keys.toList()..sort(
              (a, b) =>
                  stats[a]!.rating.rating.compareTo(stats[b]!.rating.rating),
            );
        if (section == 'Strengths') {
          ranked.sort(
            (a, b) =>
                stats[b]!.rating.rating.compareTo(stats[a]!.rating.rating),
          );
        }
        final failed = <String>{
          for (final a in attempts.where((a) => !a.success)) a.id,
        };
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rating ${progress.rating.label}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownButton<int>(
                        value: days,
                        items: [
                          for (final d in [7, 30, 90, 0])
                            DropdownMenuItem(
                              value: d,
                              child: Text(d == 0 ? 'All time' : '$d days'),
                            ),
                        ],
                        onChanged: (d) => setState(() => days = d!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _metric('Rated attempts', '${rated.length}'),
                      _metric(
                        'Solved',
                        rated.isEmpty
                            ? '—'
                            : '${(100 * solved / rated.length).round()}%',
                      ),
                      _metric('To replay', '${failed.length}'),
                      _metric(
                        'Rating change',
                        rated.isEmpty
                            ? '—'
                            : '${(rated.last.after - rated.first.before).round() >= 0 ? '+' : ''}${(rated.last.after - rated.first.before).round()}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in [
                        'Overview',
                        'Improve',
                        'Strengths',
                        'History',
                      ])
                        ChoiceChip(
                          label: Text(s),
                          selected: section == s,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => section = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (attempts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Solve rated puzzles to build your dashboard.',
                      ),
                    ),
                  if (section == 'Overview') ...[
                    if (progress.themes.isNotEmpty)
                      Center(
                        child: SizedBox(
                          width: 450,
                          height: 340,
                          child: CustomPaint(
                            painter: _RadarPainter(progress.themes),
                          ),
                        ),
                      ),
                    const Text(
                      'Theme ratings use all rated attempts. ? indicates a provisional rating.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (failed.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed:
                            () => openPuzzle(
                              context,
                              widget.store,
                              mode: 'replay',
                              puzzleId: failed.first,
                            ),
                        icon: const Icon(Icons.replay),
                        label: const Text('Replay a missed puzzle'),
                      ),
                  ],
                  if (section == 'Improve' || section == 'Strengths') ...[
                    const Text(
                      'Theme rating · Attempts and solve rate for the selected period',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    for (final t in ranked)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(puzzleThemeName(t)),
                        subtitle: Text(
                          '${stats[t]!.played} played · ${(100 * stats[t]!.solved / stats[t]!.played).round()}% solved',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stats[t]!.rating.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap:
                            () => openPuzzle(context, widget.store, theme: t),
                      ),
                  ],
                  if (section == 'History') ...[
                    const Text(
                      'Tap an attempt to replay it without changing your rating.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    for (final a in attempts.reversed.take(200))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          a.success
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: a.success ? forest : rust,
                        ),
                        title: Text(
                          '${a.puzzleRating} · ${a.themes.where(puzzleThemeNames.containsKey).map(puzzleThemeName).take(2).join(' · ')}',
                        ),
                        subtitle: Text(
                          '${a.date.toLocal().toString().substring(0, 16)} · ${a.mode}${a.assisted ? ' · Assisted' : ''}',
                        ),
                        trailing: Text(
                          a.rated
                              ? '${a.delta >= 0 ? '+' : ''}${a.delta}'
                              : 'Unrated',
                        ),
                        onTap:
                            () => openPuzzle(
                              context,
                              widget.store,
                              mode: 'replay',
                              puzzleId: a.id,
                            ),
                      ),
                    if (attempts.length > 200)
                      const Text(
                        'Showing the latest 200 attempts. Narrow the date range to see a smaller period.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

class _RadarPainter extends CustomPainter {
  final Map<String, PuzzleRating> ratings;
  _RadarPainter(this.ratings);
  static const axes = [
    'discoveredAttack',
    'advancedPawn',
    'endgame',
    'fork',
    'mate',
    'pin',
    'sacrifice',
    'kingsideAttack',
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        radius = min(size.width * .31, size.height * .34);
    Offset point(int i, double fraction) =>
        center +
        Offset(
              cos(-pi / 2 + 2 * pi * i / axes.length),
              sin(-pi / 2 + 2 * pi * i / axes.length),
            ) *
            radius *
            fraction;
    final grid =
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < axes.length; i++) {
        final p = point(i, ring / 4);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(center, point(i, 1), grid);
      final r = ratings[axes[i]];
      final label = TextPainter(
        text: TextSpan(
          text: '${puzzleThemeName(axes[i])}\n${r?.label ?? '—'}',
          style: const TextStyle(fontFamily: 'Inter', color: ink, fontSize: 11),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 110);
      final p = point(i, 1.34);
      label.paint(
        canvas,
        Offset(
          (p.dx - label.width / 2).clamp(0, size.width - label.width),
          (p.dy - label.height / 2).clamp(0, size.height - label.height),
        ),
      );
    }
    // Unknown themes have gaps, not fictitious 1500 scores or zero ability.
    final stroke =
        Paint()
          ..color = forest
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    for (var i = 0; i < axes.length; i++) {
      final current = ratings[axes[i]],
          next = ratings[axes[(i + 1) % axes.length]];
      if (current == null) continue;
      final p = point(i, ((current.rating - 400) / 2800).clamp(0, 1));
      if (next != null) {
        canvas.drawLine(
          p,
          point(
            (i + 1) % axes.length,
            ((next.rating - 400) / 2800).clamp(0, 1),
          ),
          stroke,
        );
      }
      canvas.drawCircle(p, 4, Paint()..color = forest);
    }
    final scale = TextPainter(
      text: const TextSpan(
        text: '400 → 3200',
        style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scale.paint(canvas, Offset(4, size.height - 14));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}

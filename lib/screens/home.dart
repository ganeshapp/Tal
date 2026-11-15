import 'dart:math';
import 'package:flutter/material.dart';
import '../core/catalog.dart';
import '../core/chess.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../theme.dart';
import 'game.dart';
import 'training.dart';
import 'journal.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  const HomeScreen({super.key, required this.store, required this.engines});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  static const labels = ['Play', 'Practice', 'Games', 'Settings'];
  static const icons = [
    Icons.grid_view,
    Icons.school_outlined,
    Icons.history,
    Icons.tune,
  ];
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder:
        (context, _) => LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final body = switch (tab) {
              1 => TrainingHub(store: widget.store, engines: widget.engines),
              2 => JournalScreen(store: widget.store, engines: widget.engines),
              3 => SettingsScreen(store: widget.store, engines: widget.engines),
              _ => _play(),
            };
            return Scaffold(
              appBar:
                  wide
                      ? null
                      : AppBar(
                        toolbarHeight: 48,
                        title: const Row(
                          children: [
                            Mark(size: 27),
                            SizedBox(width: 10),
                            Text(
                              'Tal',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
              body: SafeArea(
                child:
                    wide
                        ? Row(
                          children: [
                            NavigationRail(
                              selectedIndex: tab,
                              onDestinationSelected:
                                  (i) => setState(() => tab = i),
                              extended: true,
                              leading: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Row(
                                  children: [
                                    Mark(size: 32),
                                    SizedBox(width: 10),
                                    Text(
                                      'Tal',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              destinations: List.generate(
                                4,
                                (i) => NavigationRailDestination(
                                  icon: Icon(icons[i]),
                                  label: Text(labels[i]),
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: body),
                          ],
                        )
                        : body,
              ),
              bottomNavigationBar:
                  wide
                      ? null
                      : NavigationBar(
                        height: 64,
                        selectedIndex: tab,
                        onDestinationSelected: (i) => setState(() => tab = i),
                        destinations: List.generate(
                          4,
                          (i) => NavigationDestination(
                            icon: Icon(icons[i], size: 21),
                            label: labels[i],
                          ),
                        ),
                      ),
            );
          },
        ),
  );
  Widget _play() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.store.storageError != null)
              Text(
                widget.store.storageError!,
                style: const TextStyle(color: rust),
              ),
            if (widget.store.active != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: Text('Continue vs ${widget.store.active!.botName}'),
                  subtitle: Text(
                    '${widget.store.active!.humanWhite ? 'White' : 'Black'} · ${(widget.store.active!.moves.length / 2).ceil()} moves',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => _open(
                        GameScreen(
                          store: widget.store,
                          engines: widget.engines,
                          record: widget.store.active!,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'New game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GameSetup(store: widget.store, engines: widget.engines),
            const SizedBox(height: 26),
            const Text(
              'Practice',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder:
                  (_, c) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in [
                        (
                          Icons.route,
                          'Openings',
                          'Choose a line and a side',
                          1,
                        ),
                        (
                          Icons.extension_outlined,
                          'Puzzles',
                          '${widget.store.puzzles.length} puzzles · themes & rating',
                          0,
                        ),
                        (
                          Icons.flag_outlined,
                          'Endgames',
                          'Lucena, Philidor & checkmates',
                          2,
                        ),
                        (
                          Icons.replay,
                          'Mistakes',
                          '${widget.store.due.length} due for review',
                          3,
                        ),
                      ])
                        SizedBox(
                          width:
                              c.maxWidth >= 650
                                  ? (c.maxWidth - 12) / 2
                                  : c.maxWidth,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(item.$1, color: forest),
                              title: Text(item.$2),
                              subtitle: Text(
                                item.$3,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap:
                                  () => _open(
                                    TrainingPage(
                                      store: widget.store,
                                      engines: widget.engines,
                                      initialTab: item.$4,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
            if (widget.store.games.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Recent games',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => tab = 2),
                    child: const Text('All games'),
                  ),
                ],
              ),
              for (final game in widget.store.games.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${game.whiteName}  –  ${game.blackName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${openingName(game)} · ${game.date.substring(0, 10)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(game.result),
                  onTap:
                      () => _open(
                        AnalysisScreen(
                          store: widget.store,
                          engines: widget.engines,
                          record: game,
                        ),
                      ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class GameSetup extends StatefulWidget {
  final AppStore store;
  final EngineService engines;
  final Opening? opening;
  final bool dialog;
  const GameSetup({
    super.key,
    required this.store,
    required this.engines,
    this.opening,
    this.dialog = false,
  });
  @override
  State<GameSetup> createState() => _GameSetupState();
}

class _GameSetupState extends State<GameSetup> {
  late int rating = widget.store.rating;
  String side = 'White';
  bool chess960 = false, starting = false;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Opponent',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: rating,
                  items: [
                    for (var r = chess960 ? 1400 : 600; r <= 2600; r += 100)
                      DropdownMenuItem(
                        value: r,
                        child: Text(
                          '${chess960 ? 'Stockfish' : 'Maia 3'} · $r',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => rating = v!),
                ),
              ],
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'White', label: Text('White')),
                ButtonSegment(value: 'Random', label: Text('Random')),
                ButtonSegment(value: 'Black', label: Text('Black')),
              ],
              selected: {side},
              onSelectionChanged: (s) => setState(() => side = s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
        if (widget.opening == null)
          Row(
            children: [
              Checkbox(
                value: chess960,
                onChanged:
                    (v) => setState(() {
                      chess960 = v!;
                      if (chess960 && rating < 1400) rating = 1400;
                    }),
              ),
              const Text('Chess960', style: TextStyle(fontSize: 13)),
              if (chess960)
                const Expanded(
                  child: Text(
                    ' · Stockfish opponent',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed:
              widget.engines.nativeSupported && !starting ? _start : null,
          icon: const Icon(Icons.play_arrow, size: 20),
          label: Text(
            starting
                ? 'Starting…'
                : widget.opening == null
                ? 'Play'
                : 'Play ${widget.opening!.name}',
          ),
        ),
        if (!widget.engines.nativeSupported)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bot play requires the desktop or Android app.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
      ],
    ),
  );
  Future<void> _start() async {
    setState(() => starting = true);
    final white = side == 'Random' ? Random().nextBool() : side == 'White';
    final position = ChessPosition(
      chess960: chess960,
      seed: chess960 ? Random().nextInt(960) : null,
    );
    final game = GameRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startFen: position.fen,
      date: DateTime.now().toIso8601String(),
      title: chess960 ? 'Stockfish $rating' : 'Maia $rating',
      rating: rating,
      humanWhite: white,
      chess960: chess960,
      moves: widget.opening?.moves.toList(),
      opening: widget.opening?.name ?? '',
    );
    if (widget.store.active != null) widget.store.archive(widget.store.active!);
    widget.store.active = game;
    widget.store.rating = rating;
    await widget.store.save();
    if (!mounted) return;
    final route = MaterialPageRoute<void>(
      builder:
          (_) => GameScreen(
            store: widget.store,
            engines: widget.engines,
            record: game,
          ),
    );
    if (widget.dialog) {
      Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push(context, route);
      if (mounted) setState(() => starting = false);
    }
  }
}

Future<void> newGameDialog(
  BuildContext context,
  AppStore store,
  EngineService engines,
) => showDialog<void>(
  context: context,
  builder:
      (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GameSetup(store: store, engines: engines, dialog: true),
        ),
      ),
);

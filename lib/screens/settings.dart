import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  final EngineService engines;
  const SettingsScreen({super.key, required this.store, required this.engines});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Premoves'),
              subtitle: const Text(
                'Queue your move while the bot is thinking.',
                style: TextStyle(fontSize: 12),
              ),
              value: store.premoves,
              onChanged: (v) {
                store.premoves = v;
                store.save();
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Natural thinking delay'),
              subtitle: const Text(
                'Turn off for immediate bot replies.',
                style: TextStyle(fontSize: 12),
              ),
              value: store.naturalDelay,
              onChanged: (v) {
                store.naturalDelay = v;
                store.save();
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Coordinates'),
              value: store.coordinates,
              onChanged: (v) {
                store.coordinates = v;
                store.save();
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptic feedback'),
              value: store.haptics,
              onChanged: (v) {
                store.haptics = v;
                store.save();
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Evaluation during play',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            for (final entry
                in {
                  'off': 'Off',
                  'always': 'Always visible',
                  'postMove': 'After your move',
                  'blunder': 'Only after a drop greater than 2 pawns',
                }.entries)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: entry.key,
                groupValue: store.evaluation,
                title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                onChanged: (v) {
                  store.evaluation = v!;
                  store.save();
                },
              ),
            const Divider(),
            const SizedBox(height: 18),
            const Text(
              'Engines',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Maia 3 · 23M · 600–2600\nStockfish 18 · game analysis and Chess960',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Maia’s rating conditions its human move predictions; it is not a measured account rating. Standard games use Maia. Chess960 uses Stockfish’s strength setting.\n\nMove quality uses Stockfish evaluations. Great and brilliant labels are heuristics, not official chess titles.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Licenses & sources'),
                          content: const SingleChildScrollView(
                            child: Text(
                              'Maia 3 — CSSLab, AGPL-3.0\nMonroe et al., Chessformer: A Unified Architecture for Chess Modeling, ICLR 2026\nhttps://github.com/CSSLab/maia3\n\nStockfish — GPL-3.0\nONNX Runtime — MIT\nBishop — MIT\nLichess puzzles — CC0\nCburnett pieces — GPL-2.0-or-later\nInter and Lora — SIL OFL\n\nTal source and reproducible builds:\nhttps://github.com/ganeshapp/Tal',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  ),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Licenses & sources'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tal 0.3.0',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

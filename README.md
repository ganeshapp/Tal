# Tal

Tal is an offline chess trainer with a long-term goal: **help you develop attacking, creative chess inspired by Mikhail Tal**. Learn to see sacrifices, seize the initiative, calculate imaginative continuations, and create difficult practical problems for a human opponent.

The current release provides the foundation: human-like bots, game review, opening practice and adaptive puzzles. The Tal-specific training described below is a roadmap, not a claim about features already implemented.

No accounts, social features, ads, telemetry, or runtime model downloads. Built with Flutter; Android and Apple Silicon macOS are the tested targets.

## Download

Get the installers from the [latest release](https://github.com/ganeshapp/Tal/releases/latest). The Mac DMG supports Apple Silicon and macOS 12+; the Android APK supports ARM64 devices on Android 7+. Both include the engines and training data and work offline after installation.

## Roadmap: learn to play with imagination

The final goal is an offline trainer for **attacking and creative chess in the spirit of Mikhail Tal**. Success should mean that you notice possibilities, build attacks and make purposeful practical decisions over the board. Matching an engine's first choice is only one piece of feedback.

- [x] Build the foundation: offline human-like opponents, reliable boards, explorable analysis, opening practice, adaptive puzzles and local progress.
- [ ] **Study Tal's decisions.** Curate appropriately licensed or public-domain game positions, with pause-and-choose exercises and explanations of initiative, piece activity, king exposure and compensation.
- [ ] **Generate attacking candidates.** Ask for several plausible moves before revealing analysis. Train forcing moves, quiet attacking moves, exchange sacrifices, clearance and defensive-resource spotting.
- [ ] **Practice sacrifices against humans' likely replies.** Play attacking positions against Maia at different levels; vary the defender's responses and revisit positions where the attack ran out of momentum.
- [ ] **Review creative decisions in context.** Compare objective soundness, compensation, practical defensive difficulty and the idea behind a move. Credit a well-founded attacking idea without pretending that an unsound move is objectively winning.
- [ ] **Build an attacking repertoire.** Train openings and resulting middlegames that create active pieces, imbalances and opportunities for initiative, with plans and typical sacrifices alongside move sequences.
- [ ] **Measure useful progress.** Track candidate generation, calculation, recognition of attacking patterns and conversion of initiative. Use playtesting to refine these measures rather than reduce creativity to a single score.

The design principle is to **develop creativity**: encourage exploration and justified risk, retain honest engine analysis as a reference, and keep the experience useful for daily offline practice. These are planned directions, without promised release dates.

## Play and review

- **Maia 3 23M**, one skill-conditioned transformer, selectable from 600 through 2600 in steps of 100. Both Elo inputs receive the selected rating, as in the official UCI interface. Legal moves are sampled from the model policy at temperature 1. These are model conditioning levels, not independently measured account ratings.
- **Stockfish 18** analyzes positions using three principal variations, two threads and a 64 MB hash. Standard games use Maia; Chess960 uses explicitly labelled Stockfish limited-strength play. No weak practice engine is presented as Maia.
- Tap and drag, piece animation, premoves, promotion selection, takebacks, board rotation, game history, PGN copying, persistent sessions, and clear terminal results. Checkmate always has an exact result and full evaluation bar.
- Review opens immediately. The board and current move feedback remain visible while browsing moves. Navigate with the move table, graph, keyboard arrows, autoplay or key-move buttons. Inspect both players' move categories, click engine variations, show best/alternative/threat arrows, and explore branches without modifying the played game.
- Games can be filtered by your color, result, bot rating and opening family. Position-based opening detection recognizes transpositions.
- 22 suggested lines plus a searchable catalogue of 3,865 named openings, with either color: rehearse or start a game from the opening. Six endgame/conversion drills. A local spaced-repetition queue for analyzed blunders.

## Puzzle training

The bundled CC0 Lichess pack covers ratings 400–3199; its exact count, theme coverage, quality filters and SHA-256 are in `assets/data/puzzles_manifest.json`.

- Local Glicko-2 rating, initialized at 1500 with RD 350. One first attempt is one rating period; puzzle ratings remain fixed. Ratings are provisional while there are fewer than 20 rated attempts or RD exceeds 110. This is a local progression measure, not a synchronized Lichess rating.
- Mixed or themed queues, targeted within 100 points of your current rating plus an offset of −200, −100, 0, +100 or +200. Empty ranges are reported explicitly instead of silently substituting very easy puzzles.
- A wrong move, hint or revealed answer records one failed attempt. Continuing afterward cannot add a second rating change. Previously exposed puzzles are unrated. Every move of the solution must be solved; alternate immediate checkmates are accepted.
- Per-theme ratings, a radar chart with gaps for unplayed themes, strengths/improvement lists, date filters and replayable attempt history.
- Storm runs of three or five minutes and untimed Streak. Both start around 600, increasing the target by 75 per solved puzzle. Storm penalizes wrong moves by five seconds; Streak ends on the first error. Separate Storm duration records. These modes are unrated.

## Build and test

Tested with Flutter 3.29.3 / Dart 3.7.2, Python 3.11+, Java 17, Android SDK 36, NDK 28.2.13676358 and CMake 3.22.1. Android minimum API 24; ARM64 is the current release ABI.

```sh
python3 tool/fetch_build_assets.py
flutter pub get
flutter analyze
flutter test
flutter test integration_test/engine_test.dart -d <android-device>
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Run `tool/fetch_build_assets.py` once after cloning. It verifies and restores the exact model, Stockfish networks and native ONNX libraries from the matching GitHub release; these large files are kept out of Git history. The installers already contain them. To build without network access, download the build-assets archive separately and pass it with `--archive /path/to/Tal-0.3.0-build-assets.tar.gz`.

The macOS package needs Apple command-line tools, the Flutter macOS engine artifacts, CMake and Ninja. The build script assembles the Flutter release and a minimal native host without requiring the Xcode IDE. Set `FLUTTER_BIN`, `CMAKE_BIN` and `NINJA_BIN` if they are not on PATH:

```sh
tool/build_macos.sh
python3 tool/package_dmg.py
```

These create `build/distribution/Tal.app` and `build/Tal-0.3.0-arm64.dmg` for **Apple Silicon, macOS 12+**. The local test package is ad-hoc signed, not notarized. Android uses a development signing key for personal testing.

On macOS, actual model parity and native engine tests can be enabled with:

```sh
TAL_ORT_LIBRARY="$PWD/third_party/onnxruntime/macos/libonnxruntime.1.15.1.dylib" \
TAL_ENGINE_DIR="$PWD/build/mac_engines" flutter test
flutter test tool/review_screenshots_test.dart
```

Tests cover chess rules, all Chess960 starts, every bundled puzzle solution, legal opening lines, the reported Qxb7# regression, score perspective, move/drag/premove interactions, takeback cancellation, review navigation/branches, responsive layouts, Glickman's published rating example, puzzle selection and assistance, timers, persistence and native engines. The Android integration test exercises Maia at eight conditioning levels and Stockfish MultiPV/mate/concurrent operation. See `docs/build-report.json` for the final artifact checks.

## Model provenance and conversion

Maia 3 source and checkpoint revisions are pinned in `assets/data/maia3_manifest.json`. The unquantized policy-only ONNX model is approximately 90 MB. `tool/export_maia3.py` exports the original checkpoint and compares 25 positions/rating combinations against PyTorch; `test/maia3_test.dart` verifies the Dart encoding and shipped native ONNX Runtime against the same fixtures. No training or runtime server is needed.

To reproduce the export, obtain the pinned checkpoint as `build/maia3-23m.pt`, install `tool/maia3-requirements.txt` in a separate Python environment, and run `tool/export_maia3.py`. The converted model is already bundled. `tool/curate_puzzles.py` streams the official CC0 puzzle export, validates every move and selects the rating-balanced pack. `tool/fetch_assets.py` handles pieces and fonts. `tool/fetch_openings.py` bundles the pinned CC0 Lichess opening catalogue.

## Analysis semantics and limits

Scores are stored from White's perspective. The mover's loss uses `100 / (1 + exp(-0.00368208 * cp))`, with exact 0/100 at terminal mate and 50 at a draw. Thresholds: inaccuracy 5–<10 percentage points, mistake 10–20, blunder >20. A miss is a >20-point loss from at least 80% to below 60%. Playing the pre-move engine best move is not penalized for later search drift.

Great and brilliant labels are conservative heuristics, not a replication of commercial platform labels. Great requires the best move and a ≥20-point gap to a second line at the same depth. Brilliant requires a material sacrifice with a predicted reply, at least two pawns of gross and net material loss, less than two points lost and a viable resulting position. Checkmate takes precedence over all labels.

Analysis targets depth 16 with a 2.5-second position budget; achieved depth is shown. Live evaluations use shorter searches. The hypothetical threat overlay analyzes what the opponent could do after a pass; it is unavailable in check. Analysis branches are session-local. Endgame drills are playable positions, not tablebase-graded lessons. The browser supports the interface and puzzles, but native bot play and analysis require the desktop/mobile app. iOS has not been built or validated.

All progress stays on this device. The immutable puzzle pack uses compact JSON; personal state uses serialized local preference snapshots. No previous prototype save migration is attempted. This project is AGPL-3.0-or-later; see `THIRD_PARTY.md` for component notices and source requirements.

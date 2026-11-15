# Third-party software and data

Tal is distributed under AGPL-3.0-or-later; see LICENSE. Original upstream notices are retained.

| Component | Source | License / integration |
| --- | --- | --- |
| Maia 3 23M | https://github.com/CSSLab/maia3 and https://huggingface.co/UofTCSSLab/Maia3-23M | AGPL-3.0; pinned revisions and hashes in assets/data/maia3_manifest.json. Source in third_party/maia3; FP32 policy conversion in tool/export_maia3.py. |
| ONNX Runtime / Flutter wrapper 1.4.1 | https://github.com/microsoft/onnxruntime and https://pub.dev/packages/onnxruntime/versions/1.4.1 | MIT. Vendored third_party/onnxruntime; native runtime 1.15.1. Telemetry disabled; bundled-library resolution on macOS. |
| Stockfish 18 / wrapper 1.8.1 | https://github.com/official-stockfish/Stockfish and https://github.com/ArjanAswal/Stockfish | GPL-3.0. Corresponding source and local stream patches in third_party/stockfish; NNUE origins and hashes in its Android CMakeLists.txt. |
| Bishop 1.4.4 | https://github.com/alexobviously/bishop | MIT; pinned in pubspec.lock. |
| Opening names and lines | https://github.com/lichess-org/chess-openings | CC0. Pinned revision, record count and SHA-256 in assets/data/openings_manifest.json. |
| Puzzle positions, ratings and themes | https://database.lichess.org/#puzzles | CC0. Source URLs are retained in records. Manifest and curation script describe selection and derived queen-sacrifice/multi-move tags. |
| Cburnett chess SVGs | https://github.com/lichess-org/lila/tree/master/public/piece/cburnett | Colin M. L. Burnett, GPL-2.0-or-later; original notices retained. |
| Inter and Lora | https://github.com/google/fonts | SIL Open Font License, bundled notices. |
| Glicko-2 algorithm | https://www.glicko.net/glicko/glicko2.pdf | Implementation follows Mark Glickman's published equations; worked example used as a regression test. |
| Flutter and Dart dependencies | pubspec.lock | Individual notices retained by their packages and Flutter's compiled NOTICES asset. |

Maia-1 and Lc0 are not shipped. The Tal knight icon is original vector artwork in lib/theme.dart.

The application source, vendored native sources, local patches and build scripts are published at https://github.com/ganeshapp/Tal. Each release also includes a corresponding-source archive with the pinned Dart package sources and a verified build-assets archive for the model, NNUE networks and native ONNX libraries. See docs/native-patches.md for changes to the native integrations. Retain these sources and applicable notices when redistributing the installers.

# Native integration

## Maia 3

The application uses CSSLab Maia 3 23M at the code and checkpoint revisions recorded in assets/data/maia3_manifest.json. It does not use Lc0. The policy-only ONNX export preserves float32 weights and replaces RMSNorm with equivalent primitive operations for opset 17. Exported logits are compared with the original PyTorch model across 25 cases, including both orientations, history, promotions and five Elo inputs. Native Dart/ONNX parity uses the same fixtures.

Dart constructs the official 64 × 97 historical token input, including eight board histories, their own side-to-move orientation and oldest-position padding. A persistent inference isolate owns the native session. Only legal UCI moves are sampled from the predicted policy at temperature 1. The isolate shuts down its session before terminating.

The vendored onnxruntime Flutter package is version 1.4.1. Native runtime 1.15.1 is shipped. Changes: disable ONNX telemetry when creating the environment; on macOS resolve the library from the app's Frameworks directory (or an explicit test-only environment override).

## Stockfish

The vendored Flutter wrapper is stockfish 1.8.1; its embedded engine identifies itself as Stockfish 18. On Android/iOS, private pipe stream buffers replace process-global stdin/stdout redirection, preventing interference with other native libraries. Stream declarations are force-included at compile time. Zero-byte pipe reads are treated as EOF. NNUE downloads are cached and verified against full hashes.

On macOS, the same engine sources compile as a separate UCI executable. tool/mac_engines/streams.cpp binds the patched stream declarations to that process's standard streams. It is bundled inside Resources/engines. The macOS packaging script thins ONNX Runtime to ARM64 and signs all native code locally.

Each observer request is serialized. UCI inputs include the initial FEN and full move history for repetition detection. Scores are converted to White's perspective. Terminal rules override engine output. The observer resets limited-strength mode off before analysis; Chess960 playing requests set it explicitly. The application requests two threads, 64 MB hash and MultiPV 3. Timeouts stop and drain searches before reuse.

## Verification

Android native integration covers Maia 600, 1500, 1600, 1700, 1800, 1900, 2000 and 2600; Stockfish depth-16 MultiPV; mate-in-one and the resulting terminal score; and concurrent Maia/Stockfish requests. macOS tests exercise the same exported model, the packaged runtime and the standalone Stockfish executable. Engine failures are surfaced; they never silently select a weaker substitute.

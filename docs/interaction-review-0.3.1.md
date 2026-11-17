# Board interaction and review — 0.3.1

This update addresses selection lost during a bot reply, jerky dragging, a phone review that left room for only two move rows, and false Brilliant labels on castling, h3 and ordinary exchanges.

## Board behavior

Selection and an active drag survive a legal opponent reply if the same selected piece remains on its square. Legal destinations refresh immediately. Capturing that piece, navigating away, taking back, rotating the board, or disabling input clears the interaction safely.

A drag starts after three logical pixels of movement. The piece keeps its original size and the pointer's grab offset. Pointer updates rebuild only the lifted piece; the squares and other pieces remain stable. A completed drop lands directly; tap moves and opponent moves animate for 160 ms. Promotion, premoves, illegal drops and both board orientations remain supported.

The reference was Lichess's separation of selection, dragging, premoves and animation: [Chessground configuration](https://github.com/lichess-org/chessground/blob/master/src/config.ts), [drag handling](https://github.com/lichess-org/chessground/blob/master/src/drag.ts) and [animation](https://github.com/lichess-org/chessground/blob/master/src/anim.ts). Tal implements these behaviors in its Flutter board; this is not an embedded web board.

## Review layout

On phones, compact player names sit above the board, feedback sits immediately below, and transport controls stay at the bottom. Moves and engine variations have the remaining scrollable area. The graph, key-move navigation and category counts are in Summary. A smaller-board control makes additional room for moves without hiding the board.

The layout budgets for the move viewport before sizing the board. A 390 × 844 phone test, including top and bottom system insets, reserves at least 220 logical pixels for 44-pixel move rows. A small 360 × 640 screen retains several rows. Landscape has controls beneath the side panel so they cannot overflow a narrow board column. Desktop keeps the graph and engine lines alongside the board.

The move list has a draggable scrollbar. Manual scrolling is not reset by analysis updates. Selecting a move elsewhere or using autoplay brings that row into view. Category filters retain only matching move pairs, with the other player's move visible as context.

This follows the priorities of the [Lichess mobile analysis layout](https://github.com/lichess-org/mobile/blob/main/lib/src/view/analysis/analysis_layout.dart): a stable board, flexible analysis area, reachable transport controls and an option to reduce board size.

## Honest move labels

The old sacrifice check stopped after the opponent's first capture. It therefore mistook a bishop-for-knight exchange for a sacrifice and attributed that supposed sacrifice to unrelated moves such as castling or h3.

Brilliant now requires all of the following:

- The move offers its own minor or major piece. King and pawn moves are excluded.
- It is the best move or a near-equal engine candidate at the same depth, with less than one percentage point lost. Both searches reach at least depth 16 and do not disagree substantially.
- The resulting position remains viable and the starting position was not already overwhelmingly winning.
- The best reply actually accepts the offer. A legal static exchange search includes every possible recapture on that square and the option to stop. After accounting for material captured by the original move, at least two pawns of material are genuinely given up.

This prioritizes avoiding false praise. It can miss declined sacrifices, offers involving a different piece, and some winning tactical combinations. It is a conservative heuristic, not proof of creativity or a reproduction of Chess.com's proprietary classifications. [Chess.com's published move categories](https://support.chess.com/en/articles/8584089-how-does-game-review-work) also distinguish book play from engine grading.

Book recognition uses all prefixes of the pinned CC0 Lichess opening catalogue. It matches position plus move, so transpositions work. Ponziani 3.c3 is Book even if Stockfish prefers Bb5. The evaluation remains visible; book status is not an assertion that every known opening or gambit is equally sound. Book moves are excluded from error jumps and the mistake-training queue.

Old cached reviews and their derived mistake queue are invalidated. The played games, settings and puzzle progress remain available.

## Regression coverage

- Selection and active dragging across bot replies; capture of a selected piece; premoves; takebacks; promotion; flipped orientation; illegal drops.
- Grab offset and piece dimensions; unchanged static-board widgets during pointer movement; no second animation after landing.
- The reported castling and h3 positions, equal exchanges with truncated principal variations, supported quiet sacrifices, unsound offers and shallow analysis.
- Ponziani c3, all 8,192 indexed book moves, and cache invalidation.
- Long-game scrolling, category filters and responsive review at 360 × 640, 390 × 844, 800 × 390 and 1280 × 800, with phone system insets.
- Android integration with native Maia, plus a frame-timing trace of dragging. Emulator timing measures regression risk; it does not establish how every physical phone feels.

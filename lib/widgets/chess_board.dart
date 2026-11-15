import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/chess.dart';
import '../theme.dart';

class BoardArrow {
  final String move;
  final Color color;
  const BoardArrow(this.move, [this.color = forest]);
}

class ChessBoard extends StatefulWidget {
  final ChessPosition position;
  final bool flipped, interactive, coordinates;
  final bool? premoveWhite;
  final String? lastMove, hint, premove;
  final List<BoardArrow> arrows;
  final ValueChanged<String>? onMove, onPremove;
  final VoidCallback? onCancelPremove;
  const ChessBoard({
    super.key,
    required this.position,
    this.flipped = false,
    this.interactive = true,
    this.coordinates = true,
    this.lastMove,
    this.hint,
    this.onMove,
    this.premoveWhite,
    this.premove,
    this.onPremove,
    this.onCancelPremove,
    this.arrows = const [],
  });
  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String _fen = '', _legalKey = '';
  String? selected, _downSquare, _priorSelection, _dragFrom;
  List<String> _legal = [];
  Map<String, String> _pieces = {};
  final Map<String, int> _ids = {};
  int _nextId = 0;
  String? _checkedKing;
  bool _dragging = false, _drop = false, _promoting = false;
  double _size = 0;
  final ValueNotifier<Offset?> _pointer = ValueNotifier(null);
  bool get _canPremove =>
      widget.premoveWhite != null &&
      widget.position.whiteTurn != widget.premoveWhite;
  bool get _enabled =>
      widget.interactive && widget.onMove != null ||
      _canPremove && widget.onPremove != null;

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  void _sync() {
    final fen = widget.position.fen;
    if (fen != _fen) {
      final next = widget.position.pieces;
      final oldIds = Map<String, int>.from(_ids);
      final remaining = Map<String, String>.from(_pieces);
      _ids.clear();
      // Preserve piece identity so an opponent move slides, rather than disappears.
      final last = widget.lastMove;
      if (last != null && last.length >= 4) {
        final from = last.substring(0, 2), to = last.substring(2, 4);
        if (oldIds[from] != null &&
            next[to] != null &&
            remaining[from] != next[from]) {
          _ids[to] = oldIds[from]!;
          remaining.remove(from);
          remaining.remove(to);
        }
      }
      for (final entry in next.entries) {
        if (_ids.containsKey(entry.key)) continue;
        if (remaining[entry.key] == entry.value) {
          _ids[entry.key] = oldIds[entry.key]!;
          remaining.remove(entry.key);
        }
      }
      for (final entry in next.entries) {
        if (_ids.containsKey(entry.key)) continue;
        final candidates =
            remaining.entries.where((e) => e.value == entry.value).toList();
        if (candidates.isNotEmpty) {
          _ids[entry.key] = oldIds[candidates.first.key]!;
          remaining.remove(candidates.first.key);
        } else {
          _ids[entry.key] = _nextId++;
        }
      }
      _pieces = next;
      _fen = fen;
      selected = null;
      _dragging = false;
      _dragFrom = null;
      _pointer.value = null;
      _checkedKing =
          widget.position.inCheck
              ? _pieces.entries
                  .where(
                    (e) => e.value == (widget.position.whiteTurn ? 'K' : 'k'),
                  )
                  .firstOrNull
                  ?.key
              : null;
    }
    final key = '$fen:$_enabled:$_canPremove';
    if (_legalKey != key) {
      _legalKey = key;
      _legal =
          !_enabled
              ? []
              : _canPremove
              ? widget.position.premoves
              : widget.position.legal;
    }
  }

  Offset _offset(String sq) {
    final file = sq.codeUnitAt(0) - 97, rank = int.parse(sq[1]) - 1;
    return Offset(
      (widget.flipped ? 7 - file : file) * _size / 8,
      (widget.flipped ? rank : 7 - rank) * _size / 8,
    );
  }

  String? _square(Offset p) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= _size || p.dy >= _size) return null;
    final col = (p.dx * 8 / _size).floor(), row = (p.dy * 8 / _size).floor();
    return '${String.fromCharCode(97 + (widget.flipped ? 7 - col : col))}${widget.flipped ? row + 1 : 8 - row}';
  }

  bool _own(String? sq) {
    final p = _pieces[sq];
    return p != null &&
        (p == p.toUpperCase()) ==
            (widget.premoveWhite ?? widget.position.whiteTurn);
  }

  void _down(DragDownDetails d) {
    _downSquare = _square(d.localPosition);
    _priorSelection = selected;
    if (_own(_downSquare)) {
      setState(() {
        selected = _downSquare;
        _dragFrom = _downSquare;
      });
      _pointer.value = d.localPosition;
    }
  }

  void _tap(TapUpDetails d) {
    final to = _square(d.localPosition);
    if (_priorSelection != null &&
        to != null &&
        _legal.any((m) => m.startsWith('$_priorSelection$to'))) {
      _attempt(_priorSelection!, to);
    } else {
      setState(() => selected = _own(to) && to != _priorSelection ? to : null);
      if (selected == null) widget.onCancelPremove?.call();
    }
    _dragFrom = null;
    _pointer.value = null;
  }

  void _end(DragEndDetails _) {
    final to = _pointer.value == null ? null : _square(_pointer.value!);
    final from = _dragFrom;
    setState(() {
      _dragging = false;
      _dragFrom = null;
    });
    _pointer.value = null;
    if (from != null && to != null && from != to) {
      _drop = true;
      _attempt(from, to);
    }
  }

  Future<void> _attempt(String from, String to) async {
    if (_promoting) return;
    final options = _legal.where((m) => m.startsWith(from + to)).toList();
    if (options.isEmpty) {
      setState(() => selected = null);
      return;
    }
    final fen = _fen;
    String? move = options.first;
    if (options.length > 1) {
      _promoting = true;
      move = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Promote to'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    options
                        .map(
                          (m) => IconButton(
                            tooltip: pieceName(m[4]),
                            onPressed: () => Navigator.pop(context, m),
                            icon: Piece(
                              piece:
                                  _own(from) && (_pieces[from] == 'P')
                                      ? m[4].toUpperCase()
                                      : m[4],
                              size: 48,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
      );
      _promoting = false;
    }
    if (!mounted || move == null || fen != widget.position.fen) return;
    setState(() => selected = null);
    if (_canPremove) {
      widget.onPremove?.call(move);
    } else {
      widget.onMove?.call(move);
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final duration = _drop ? Duration.zero : const Duration(milliseconds: 140);
    _drop = false;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.maxWidth;
          final side = _size / 8;
          final targets =
              selected == null
                  ? <String>{}
                  : _legal
                      .where((m) => m.startsWith(selected!))
                      .map((m) => m.substring(2, 4))
                      .toSet();
          return RepaintBoundary(
            child: MouseRegion(
              cursor: _enabled ? SystemMouseCursors.grab : MouseCursor.defer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: _enabled ? _down : null,
                onTapUp: _enabled ? _tap : null,
                onPanStart:
                    _enabled
                        ? (d) {
                          if (_dragFrom != null) {
                            _pointer.value = d.localPosition;
                            setState(() => _dragging = true);
                          }
                        }
                        : null,
                onPanUpdate:
                    _enabled
                        ? (d) {
                          if (_dragging) _pointer.value = d.localPosition;
                        }
                        : null,
                onPanEnd: _enabled ? _end : null,
                onPanCancel: () {
                  if (mounted && _dragging) setState(() => _dragging = false);
                },
                onSecondaryTap: widget.onCancelPremove,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SquaresPainter(
                          flipped: widget.flipped,
                          last: widget.lastMove,
                          selected: selected,
                          hint: widget.hint,
                          premove: widget.premove,
                          checked: _checkedKing,
                          targets: targets,
                          occupied: _pieces.keys.toSet(),
                          coordinates: widget.coordinates,
                        ),
                      ),
                    ),
                    for (final entry in _pieces.entries)
                      AnimatedPositioned(
                        key: ValueKey('piece-${_ids[entry.key]}'),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        left: _offset(entry.key).dx,
                        top: _offset(entry.key).dy,
                        width: side,
                        height: side,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity:
                                _dragging && _dragFrom == entry.key ? 0 : 1,
                            child: Center(
                              child: Piece(
                                piece: entry.value,
                                size: side * .91,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // A small accessible target for each square; hit testing still happens once at board level.
                    for (var rank = 1; rank <= 8; rank++)
                      for (var file = 0; file < 8; file++)
                        Positioned(
                          left:
                              _offset(
                                '${String.fromCharCode(97 + file)}$rank',
                              ).dx,
                          top:
                              _offset(
                                '${String.fromCharCode(97 + file)}$rank',
                              ).dy,
                          width: side,
                          height: side,
                          child: Semantics(
                            label:
                                '${String.fromCharCode(97 + file)}$rank ${_pieces['${String.fromCharCode(97 + file)}$rank'] ?? 'empty'}',
                            button: _enabled,
                            onTap:
                                !_enabled
                                    ? null
                                    : () {
                                      final sq =
                                          '${String.fromCharCode(97 + file)}$rank';
                                      if (selected != null && !_own(sq)) {
                                        _attempt(selected!, sq);
                                      } else {
                                        setState(() => selected = sq);
                                      }
                                    },
                            child: const SizedBox.expand(),
                          ),
                        ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ArrowsPainter(
                            widget.arrows,
                            widget.flipped,
                          ),
                        ),
                      ),
                    ),
                    if (_dragging && _dragFrom != null)
                      ValueListenableBuilder<Offset?>(
                        valueListenable: _pointer,
                        builder:
                            (_, p, child) =>
                                p == null
                                    ? const SizedBox()
                                    : Positioned(
                                      left: p.dx - side / 2,
                                      top: p.dy - side / 2,
                                      width: side,
                                      height: side,
                                      child: IgnorePointer(child: child),
                                    ),
                        child: Piece(piece: _pieces[_dragFrom]!, size: side),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SquaresPainter extends CustomPainter {
  final bool flipped, coordinates;
  final String? last, selected, hint, premove, checked;
  final Set<String> targets, occupied;
  _SquaresPainter({
    required this.flipped,
    required this.coordinates,
    required this.last,
    required this.selected,
    required this.hint,
    required this.premove,
    required this.checked,
    required this.targets,
    required this.occupied,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 8;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final file = flipped ? 7 - col : col,
            rank = flipped ? row + 1 : 8 - row;
        final square = '${String.fromCharCode(97 + file)}$rank',
            light = (row + col) % 2 == 0;
        var color = light ? const Color(0xFFE7E5D4) : const Color(0xFF8CA187);
        bool includes(String? move) =>
            move != null &&
            move.length >= 4 &&
            (move.substring(0, 2) == square || move.substring(2, 4) == square);
        if (includes(last)) {
          color = light ? const Color(0xFFF0E7A0) : const Color(0xFFBCC483);
        }
        if (includes(premove)) color = const Color(0xFF8DA8CB);
        if (square == selected || square == hint) {
          color = const Color(0xFFCCB966);
        }
        if (square == checked) color = const Color(0xFFD78870);
        final rect = Rect.fromLTWH(col * s, row * s, s, s);
        canvas.drawRect(rect, Paint()..color = color);
        if (targets.contains(square)) {
          canvas.drawCircle(
            rect.center,
            occupied.contains(square) ? s * .43 : s * .13,
            Paint()
              ..color = ink.withValues(alpha: .23)
              ..style =
                  occupied.contains(square)
                      ? PaintingStyle.stroke
                      : PaintingStyle.fill
              ..strokeWidth = s * .07,
          );
        }
        if (coordinates && (col == 0 || row == 7)) {
          void text(String text, Offset offset) {
            final p = TextPainter(
              text: TextSpan(
                text: text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: max(9, s * .17),
                  fontWeight: FontWeight.w600,
                  color: light ? forest : paper,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            p.paint(canvas, offset);
          }

          if (col == 0) text('$rank', Offset(col * s + 2, row * s + 1));
          if (row == 7) {
            text(
              String.fromCharCode(97 + file),
              Offset((col + 1) * s - s * .19, (row + 1) * s - s * .23),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SquaresPainter old) => true;
}

class _ArrowsPainter extends CustomPainter {
  final List<BoardArrow> arrows;
  final bool flipped;
  _ArrowsPainter(this.arrows, this.flipped);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 8;
    Offset center(String sq) {
      final f = sq.codeUnitAt(0) - 97, r = int.parse(sq[1]) - 1;
      return Offset(
        (flipped ? 7 - f : f) * s + s / 2,
        (flipped ? r : 7 - r) * s + s / 2,
      );
    }

    for (final arrow in arrows) {
      if (arrow.move.length < 4) continue;
      final from = center(arrow.move.substring(0, 2)),
          to = center(arrow.move.substring(2, 4));
      if (from == to) continue;
      final angle = atan2(to.dy - from.dy, to.dx - from.dx),
          unit = Offset(cos(angle), sin(angle));
      final p =
          Paint()
            ..color = arrow.color.withValues(alpha: .8)
            ..strokeWidth = s * .13
            ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to - unit * s * .17, p);
      final wing = Offset(-unit.dy, unit.dx) * s * .17;
      canvas.drawPath(
        Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(
            (to - unit * s * .33 + wing).dx,
            (to - unit * s * .33 + wing).dy,
          )
          ..lineTo(
            (to - unit * s * .33 - wing).dx,
            (to - unit * s * .33 - wing).dy,
          )
          ..close(),
        Paint()..color = p.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter old) =>
      old.arrows != arrows || old.flipped != flipped;
}

String pieceName(String p) =>
    const {
      'p': 'pawn',
      'r': 'rook',
      'n': 'knight',
      'b': 'bishop',
      'q': 'queen',
      'k': 'king',
    }[p.toLowerCase()] ??
    p;

class Piece extends StatelessWidget {
  final String piece;
  final double size;
  const Piece({super.key, required this.piece, required this.size});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/pieces/${piece == piece.toUpperCase() ? 'w' : 'b'}${piece.toUpperCase()}.svg',
    width: size,
    height: size,
  );
}

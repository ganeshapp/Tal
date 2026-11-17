import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/chess.dart';
import '../theme.dart';

const reviewLabels = [
  'Book',
  'Brilliant',
  'Great',
  'Best',
  'Good',
  'Inaccuracy',
  'Mistake',
  'Blunder',
  'Miss',
];
const reviewSymbols = {
  'Book': '',
  'Brilliant': '!!',
  'Great': '!',
  'Best': '★',
  'Good': '✓',
  'Inaccuracy': '?!',
  'Mistake': '?',
  'Blunder': '??',
  'Miss': '×',
};
Color reviewColor(String label) => switch (label) {
  'Book' => const Color(0xFF7A6550),
  'Brilliant' => const Color(0xFF078B91),
  'Great' => const Color(0xFF397EBA),
  'Inaccuracy' => const Color(0xFFB58A19),
  'Mistake' => const Color(0xFFD37C2D),
  'Blunder' || 'Miss' => const Color(0xFFBB4642),
  _ => forest,
};
String evaluationText(int? cp, [int? mate]) =>
    cp == null
        ? '—'
        : mate == 0 && cp.abs() >= 100000
        ? (cp > 0 ? '1–0' : '0–1')
        : mate != null
        ? '${mate < 0 ? '−' : ''}M${mate.abs()}'
        : cp.abs() >= 100000
        ? (cp > 0 ? 'M' : '−M')
        : '${cp >= 0 ? '+' : ''}${(cp / 100).toStringAsFixed(1)}';

class EvaluationBar extends StatelessWidget {
  final int? cp, mate;
  final bool flipped;
  final bool loading;
  const EvaluationBar({
    super.key,
    this.cp,
    this.mate,
    this.flipped = false,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final white = cp == null ? .5 : winningChances(cp!) / 100;
    return Semantics(
      label:
          cp == null
              ? 'Evaluation unavailable'
              : 'White winning chances ${(white * 100).toStringAsFixed(0)} percent',
      child: Tooltip(
        message:
            cp == null
                ? 'Analysis pending'
                : 'White ${(white * 100).toStringAsFixed(1)}% · ${evaluationText(cp, mate)}',
        child: SizedBox(
          width: 26,
          child: LayoutBuilder(
            builder:
                (_, c) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF303D35)),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: 0,
                        right: 0,
                        bottom: flipped ? null : 0,
                        top: flipped ? 0 : null,
                        height: c.maxHeight * white,
                        child: const ColoredBox(color: Color(0xFFF4F1DE)),
                      ),
                      Align(
                        alignment:
                            cp != null && cp! < 0 != flipped
                                ? Alignment.topCenter
                                : Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              evaluationText(cp, mate),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    cp != null && cp! < 0 ? Colors.white : ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (loading)
                        const Positioned(
                          top: 2,
                          left: 5,
                          child: SizedBox(
                            width: 16,
                            height: 2,
                            child: LinearProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class PlayerStrip extends StatelessWidget {
  final String name;
  final bool white, active;
  final String? status;
  const PlayerStrip({
    super.key,
    required this.name,
    required this.white,
    this.active = false,
    this.status,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: white ? Colors.white : ink,
            shape: BoxShape.circle,
            border: Border.all(color: ink),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const Spacer(),
        if (status != null)
          Text(status!, style: const TextStyle(fontSize: 11, color: muted)),
        if (active)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.circle, size: 7, color: forest),
          ),
      ],
    ),
  );
}

class MoveTable extends StatefulWidget {
  final GameRecord record;
  final int cursor;
  final ValueChanged<int> onSelect;
  final String? filter;
  final bool? filterWhite;
  final bool showPlayers;
  const MoveTable({
    super.key,
    required this.record,
    required this.cursor,
    required this.onSelect,
    this.filter,
    this.filterWhite,
    this.showPlayers = true,
  });
  @override
  State<MoveTable> createState() => _MoveTableState();
}

class _MoveTableState extends State<MoveTable> {
  final controller = ScrollController();
  List<int> _rows = [];
  double _rowHeight = 44;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoveTable old) {
    super.didUpdateWidget(old);
    if (old.cursor != widget.cursor ||
        old.filter != widget.filter ||
        old.filterWhite != widget.filterWhite ||
        old.record.id != widget.record.id) {
      _scroll();
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll();
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients || _rows.isEmpty) return;
      final row =
          (max(0, widget.cursor - 1) +
              (widget.record.startFen.split(' ')[1] == 'b' ? 1 : 0)) ~/
          2;
      final index = _rows.indexOf(row);
      if (index < 0) return;
      final offset = index * _rowHeight;
      final view = controller.position.viewportDimension;
      // Engine updates never pull a manually scrolled list back to the cursor.
      // Navigation scrolls only when the newly selected row is off screen.
      if (offset < controller.offset ||
          offset + _rowHeight > controller.offset + view) {
        controller.animateTo(
          (offset - (view - _rowHeight) / 2).clamp(
            0,
            controller.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record, sans = record.sans;
    final offset = record.startFen.split(' ')[1] == 'b' ? 1 : 0,
        firstNumber = int.parse(record.startFen.split(' ')[5]);
    final reviews = {for (final r in record.reviews) r.ply: r};
    _rowHeight = 44 * max(1.0, MediaQuery.textScalerOf(context).scale(1));
    bool matches(int i) =>
        i >= 0 &&
        i < sans.length &&
        (widget.filter == null || reviews[i]?.label == widget.filter) &&
        (widget.filterWhite == null ||
            widget.filterWhite == ((i + offset) % 2 == 0));
    _rows = [
      for (var row = 0; row < (sans.length + offset + 1) ~/ 2; row++)
        if (matches(row * 2 - offset) || matches(row * 2 + 1 - offset)) row,
    ];
    Widget cell(int i) {
      if (i < 0 || i >= sans.length) return const Expanded(child: SizedBox());
      final review = reviews[i], selected = widget.cursor == i + 1;
      return Expanded(
        child: Semantics(
          selected: selected,
          label:
              '${(i + offset) % 2 == 0 ? 'White' : 'Black'} ${firstNumber + (i + offset) ~/ 2}. ${sans[i]}${review == null ? '' : ', ${review.label}'}',
          child: Material(
            color: selected ? sage : Colors.transparent,
            child: InkWell(
              key: ValueKey('move-ply-${i + 1}'),
              onTap: () => widget.onSelect(i + 1),
              child: Container(
                height: _rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: selected ? forest : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Opacity(
                  opacity: matches(i) ? 1 : .38,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sans[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (review != null)
                        Tooltip(
                          message: review.label,
                          child:
                              review.label == 'Book'
                                  ? Icon(
                                    Icons.menu_book_outlined,
                                    size: 15,
                                    color: reviewColor('Book'),
                                  )
                                  : Text(
                                    reviewSymbols[review.label] ?? '',
                                    style: TextStyle(
                                      color: reviewColor(review.label),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (widget.showPlayers)
          Container(
            height: 30,
            color: sage.withValues(alpha: .45),
            padding: const EdgeInsets.only(left: 34),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'White · ${record.whiteName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Black · ${record.blackName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child:
              _rows.isEmpty
                  ? Center(
                    child: Text(
                      sans.isEmpty ? 'No moves yet' : 'No matching moves',
                      style: const TextStyle(color: muted),
                    ),
                  )
                  : Scrollbar(
                    controller: controller,
                    thumbVisibility: true,
                    interactive: true,
                    thickness: 3,
                    radius: const Radius.circular(2),
                    child: ListView.builder(
                      key: const ValueKey('move-list'),
                      controller: controller,
                      padding: EdgeInsets.zero,
                      itemExtent: _rowHeight,
                      itemCount: _rows.length,
                      itemBuilder: (_, index) {
                        final row = _rows[index];
                        return ColoredBox(
                          color:
                              index.isEven
                                  ? Colors.white.withValues(alpha: .5)
                                  : Colors.transparent,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${firstNumber + row}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              cell(row * 2 - offset),
                              cell(row * 2 + 1 - offset),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class EvaluationGraph extends StatelessWidget {
  final List<double?> points;
  final int cursor;
  final ValueChanged<int> onSelect;
  const EvaluationGraph({
    super.key,
    required this.points,
    required this.cursor,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      void select(Offset p) => onSelect(
        (p.dx / c.maxWidth * max(1, points.length - 1)).round().clamp(
          0,
          points.length - 1,
        ),
      );
      return Semantics(
        label: 'Evaluation graph. Drag to choose a move.',
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              onSelect(
                (cursor + (event.scrollDelta.dy > 0 ? 1 : -1)).clamp(
                  0,
                  points.length - 1,
                ),
              );
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => select(d.localPosition),
              onHorizontalDragStart: (d) => select(d.localPosition),
              onHorizontalDragUpdate: (d) => select(d.localPosition),
              child: CustomPaint(
                painter: _GraphPainter(points, cursor),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _GraphPainter extends CustomPainter {
  final List<double?> points;
  final int cursor;
  _GraphPainter(this.points, this.cursor);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white);
    for (final v in [.25, .5, .75]) {
      c.drawLine(
        Offset(0, s.height * v),
        Offset(s.width, s.height * v),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
    }
    final path = Path();
    var started = false;
    for (var i = 0; i < points.length; i++) {
      if (points[i] == null) {
        started = false;
        continue;
      }
      final x = i / max(1, points.length - 1) * s.width,
          y = 4 + (1 - points[i]! / 100) * (s.height - 8);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final x = cursor / max(1, points.length - 1) * s.width;
    c.drawLine(
      Offset(x, 0),
      Offset(x, s.height),
      Paint()
        ..color = rust
        ..strokeWidth = 1,
    );
    if (cursor < points.length && points[cursor] != null) {
      c.drawCircle(
        Offset(x, 4 + (1 - points[cursor]! / 100) * (s.height - 8)),
        4,
        Paint()..color = rust,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}

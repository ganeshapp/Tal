import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/chess.dart';
import '../theme.dart';

const reviewLabels = [
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
  const MoveTable({
    super.key,
    required this.record,
    required this.cursor,
    required this.onSelect,
    this.filter,
    this.filterWhite,
  });
  @override
  State<MoveTable> createState() => _MoveTableState();
}

class _MoveTableState extends State<MoveTable> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoveTable old) {
    super.didUpdateWidget(old);
    if (old.cursor != widget.cursor ||
        old.record.moves.length != widget.record.moves.length) {
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
      if (!mounted || !controller.hasClients) return;
      final offset =
          (max(0, widget.cursor - 1) +
              (widget.record.startFen.split(' ')[1] == 'b' ? 1 : 0)) ~/
          2 *
          36.0;
      final view = controller.position.viewportDimension;
      if (offset < controller.offset ||
          offset + 36 > controller.offset + view) {
        controller.animateTo(
          (offset - view * .45).clamp(0, controller.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
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
    Widget cell(int i) {
      if (i < 0 || i >= sans.length) return const Expanded(child: SizedBox());
      final review = record.reviews.where((r) => r.ply == i).firstOrNull;
      final white = (i + offset) % 2 == 0;
      final matches =
          (widget.filter == null || review?.label == widget.filter) &&
          (widget.filterWhite == null || widget.filterWhite == white);
      return Expanded(
        child: Material(
          color: widget.cursor == i + 1 ? sage : Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSelect(i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Opacity(
                opacity: matches ? 1 : .3,
                child: Row(
                  children: [
                    Text(
                      sans[i],
                      style: TextStyle(
                        fontWeight:
                            widget.cursor == i + 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (review != null)
                      Tooltip(
                        message: review.label,
                        child: Text(
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
      );
    }

    return Column(
      children: [
        Container(
          height: 30,
          color: sage.withValues(alpha: .45),
          padding: const EdgeInsets.only(left: 38),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'White · ${record.whiteName}',
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  'Black · ${record.blackName}',
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              sans.isEmpty
                  ? const Center(
                    child: Text('No moves yet', style: TextStyle(color: muted)),
                  )
                  : ListView.builder(
                    controller: controller,
                    itemExtent: 36,
                    itemCount: (sans.length + offset + 1) ~/ 2,
                    itemBuilder:
                        (_, row) => Row(
                          children: [
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${firstNumber + row}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            cell(row * 2 - offset),
                            cell(row * 2 + 1 - offset),
                          ],
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

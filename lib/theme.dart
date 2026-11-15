import 'package:flutter/material.dart';

const paper = Color(0xFFF7F6F0);
const ink = Color(0xFF263D32);
const muted = Color(0xFF7A8178);
const forest = Color(0xFF315C46);
const sage = Color(0xFFE8EDE3);
const line = Color(0xFFE1E5DC);
const rust = Color(0xFFAD7354);

ThemeData talTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: forest,
    surface: paper,
    primary: forest,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Lora',
      fontSize: 48,
      height: 1.15,
      color: ink,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Lora',
      fontSize: 34,
      height: 1.2,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Lora',
      fontSize: 28,
      height: 1.25,
      color: ink,
    ),
    titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 20, color: ink),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: ink),
    bodyMedium: TextStyle(fontSize: 13, height: 1.6, color: ink),
    bodySmall: TextStyle(fontSize: 11, height: 1.5, color: muted),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: forest,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 50),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(0, 46),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, space: 1),
  chipTheme: ChipThemeData(
    backgroundColor: paper,
    selectedColor: sage,
    side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: paper,
    indicatorColor: sage,
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  ),
  dialogTheme: DialogTheme(
    backgroundColor: paper,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
);

class Mark extends StatelessWidget {
  final double size;
  const Mark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(size * .27),
    ),
    child: CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48);
    final p =
        Paint()
          ..color = const Color(0xFFF3F1DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path =
        Path()
          ..moveTo(14, 35)
          ..lineTo(34, 35)
          ..moveTo(16, 30)
          ..cubicTo(17, 24, 27, 25, 27, 18)
          ..lineTo(22, 21)
          ..lineTo(14, 21)
          ..lineTo(14, 17)
          ..lineTo(23, 10)
          ..lineTo(25, 6)
          ..lineTo(28, 11)
          ..cubicTo(36, 15, 36, 25, 32, 30)
          ..close();
    canvas.drawPath(path, p);
    canvas.drawCircle(
      const Offset(23, 15),
      1,
      Paint()..color = const Color(0xFFF3F1DD),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = muted});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      color: color,
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const Surface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

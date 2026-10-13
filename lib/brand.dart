import 'package:flutter/material.dart';
import 'widgets.dart';

/// A small open journal whose pages also form a sound wave.
class HamnavaMark extends StatelessWidget {
  const HamnavaMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'نشان هم‌نوا؛ دفتر و موج صدا',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter()),
    ),
  );
}

class HamnavaWordmark extends StatelessWidget {
  const HamnavaWordmark({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HamnavaMark(size: 42),
      SizedBox(width: 12),
      Text(
        'هم‌نوا',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          color: forest,
        ),
      ),
    ],
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 64, 64),
        const Radius.circular(20),
      ),
      Paint()..color = forest,
    );
    final page = Path()
      ..moveTo(13, 26)
      ..cubicTo(19, 23, 25, 25, 32, 31)
      ..cubicTo(39, 25, 45, 23, 51, 26)
      ..lineTo(51, 44)
      ..cubicTo(44, 41, 39, 43, 32, 49)
      ..cubicTo(25, 43, 20, 41, 13, 44)
      ..close();
    final stroke = Paint()
      ..color = const Color(0xfff6f2e9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(page, stroke);
    canvas.drawLine(const Offset(32, 31), const Offset(32, 49), stroke);
    final wave = Paint()
      ..color = const Color(0xffe4b58d)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(25, 17), const Offset(25, 21), wave);
    canvas.drawLine(const Offset(32, 12), const Offset(32, 23), wave);
    canvas.drawLine(const Offset(39, 17), const Offset(39, 21), wave);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class HrDisplay extends StatelessWidget {
  const HrDisplay({
    super.key,
    required this.heartRate,
    required this.color,
    this.gradientPhase = 0,
    this.useGradient = false,
    this.fontSize = 96,
  });

  final int? heartRate;
  final Color color;
  final double gradientPhase;
  final bool useGradient;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      heartRate?.toString() ?? '--',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: 4,
        height: 1.1,
      ),
    );
    if (!useGradient) {
      return DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: Text(
          heartRate?.toString() ?? '--',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 4,
            height: 1.1,
          ),
        ),
      );
    }
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1 + gradientPhase * 2, -1),
        end: Alignment(1 + gradientPhase * 2, 1),
        colors: const [
          Color(0xFF7F7FD5),
          Color(0xFF86A8E7),
          Color(0xFF91EAE4),
          Color(0xFFE0C3FC),
        ],
      ).createShader(bounds),
      child: text,
    );
  }
}

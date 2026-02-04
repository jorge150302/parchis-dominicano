import 'dart:math';
import 'package:flutter/material.dart';

/// =======================================================
/// 🎲 CONFIGURACIÓN DEL DADO (future-proof)
/// =======================================================
class DiceStyle {
  final int sides;
  final String assetPath;
  final double size;

  const DiceStyle({
    required this.sides,
    required this.assetPath,
    this.size = 60,
  });
}

/// =======================================================
/// 🎲 DICE WIDGET (sprites LIMPIO, sin rebotes)
/// =======================================================
/// Filosofía:
/// • mientras rolling → caras random rápidas
/// • cuando termina → se queda fijo instantáneo
/// • sin bounce, sin scale, sin glitches
/// =======================================================
class DiceWidget extends StatefulWidget {
  final int value;
  final bool rolling;
  final DiceStyle style;

  const DiceWidget({
    super.key,
    required this.value,
    required this.rolling,
    required this.style,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final _random = Random();
  int displayedValue = 1;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 90), // rápido tipo casino
      vsync: this,
    );

    /// mientras rueda → caras random
    _controller.addListener(() {
      if (widget.rolling) {
        setState(() {
          displayedValue = _random.nextInt(widget.style.sides) + 1;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// empezó a rodar
    if (widget.rolling && !_controller.isAnimating) {
      _controller.repeat();
    }

    /// terminó → mostrar valor real instantáneo
    if (!widget.rolling && _controller.isAnimating) {
      _controller.stop();

      setState(() {
        displayedValue = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.style.size;

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        '${widget.style.assetPath}/$displayedValue.png',
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

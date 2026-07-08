import 'package:flutter/material.dart';
import 'dart:math';

class Dice3DWidget extends StatefulWidget {
  final int value;
  final bool rolling;

  /// para futuro: classic, gold, neon, etc
  final String theme;

  const Dice3DWidget({
    super.key,
    required this.value,
    required this.rolling,
    this.theme = 'classic',
  });

  @override
  State<Dice3DWidget> createState() => _Dice3DWidgetState();
}

class _Dice3DWidgetState extends State<Dice3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  String _asset(int value) =>
      'assets/dice/${widget.theme}/dice_$value.png';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _rotation = Tween(
      begin: 0.0,
      end: 4 * pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant Dice3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// 🎲 animar SOLO cuando empieza a rodar
    if (widget.rolling && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (_, __) {
        return Transform(
          alignment: Alignment.center,

          /// 🔥 perspectiva real 3D
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(_rotation.value)
            ..rotateY(_rotation.value * 0.7),

          child: Container(
            width: 64,
            height: 64,

            /// 🔥 sombra = profundidad visual
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  color: Colors.black38,
                  offset: Offset(0, 6),
                )
              ],
            ),

            child: Image.asset(
              _asset(widget.value > 0 ? widget.value : 1),
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

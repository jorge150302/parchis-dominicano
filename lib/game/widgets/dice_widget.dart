import 'dart:math';
import 'package:flutter/material.dart';

/// =======================================================
/// 🎲 CONFIGURACIÓN (future-proof)
/// =======================================================
class DiceStyle {
  final int sides;
  final String assetPath;
  final double size;

  const DiceStyle({
    required this.sides,
    required this.assetPath,
    this.size = 120, // 🔥 más grande por defecto
  });
}

/// =======================================================
/// 🎲 DICE WIDGET PRO (spin + bounce + sombra + base)
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

  late Animation<double> _rotation;
  late Animation<double> _bounce;
  late Animation<double> _scale;

  final _random = Random();

  int displayedValue = 1;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450)
    );

    /// giro continuo
    _rotation = Tween<double>(begin: 0, end: 4 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    /// rebote vertical suave
    _bounce = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    /// squash/stretch tipo físico
    _scale = Tween<double>(begin: 1, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    /// caras random mientras rueda
    _controller.addListener(() {
      if (widget.rolling) {
        setState(() {
          displayedValue = _random.nextInt(widget.style.sides) + 1;
        });
      }
    });

    /// termina → mostrar valor real fijo
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          displayedValue = widget.value;
        });
      }
    });
  }
  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ empezar a rodar suave (loop continuo)
    if (widget.rolling && !oldWidget.rolling) {
      _controller.repeat();
    }

    // ✅ terminar suave (no corte brusco)
    if (!widget.rolling && oldWidget.rolling) {
      _controller.stop();
      displayedValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.style.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: Transform.rotate(
            angle: _rotation.value,
            child: Transform.scale(
              scale: widget.rolling ? _scale.value : 1,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: Offset(0, 8),
                      color: Colors.black26,
                    )
                  ],
                ),
                child: Image.asset(
                  '${widget.style.assetPath}/$displayedValue.png',
                  fit: BoxFit.contain,
                ),
              ),
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

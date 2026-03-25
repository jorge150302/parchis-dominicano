import 'dart:math';
import 'package:flutter/material.dart';

class DiceStyle {
  final int sides;
  final String assetPath;
  final double size;

  const DiceStyle({
    required this.sides,
    required this.assetPath,
    this.size = 120,
  });
}

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

  late int displayedValue;

  @override
  void initState() {
    super.initState();

    // Inicializar con el valor actual (útil para la reanudación)
    displayedValue = widget.value;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450)
    );

    _rotation = Tween<double>(begin: 0, end: 4 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _bounce = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 1, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addListener(() {
      if (widget.rolling) {
        setState(() {
          displayedValue = _random.nextInt(widget.style.sides) + 1;
        });
      }
    });

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

    // Si este dado empieza a rodar
    if (widget.rolling && !oldWidget.rolling) {
      _controller.repeat();
    }

    // Si este dado termina de rodar, fijar el valor final
    if (!widget.rolling && oldWidget.rolling) {
      _controller.stop();
      setState(() {
        displayedValue = widget.value;
      });
    }

    // ✅ HEMOS ELIMINADO el bloque que sincronizaba el valor automáticamente.
    // Ahora, si el valor del controlador cambia pero ESTE dado no estaba rodando,
    // se ignorará el cambio, manteniendo la independencia entre jugadores.
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

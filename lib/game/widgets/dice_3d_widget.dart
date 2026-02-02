import 'package:flutter/material.dart';
import 'dart:math';

class Dice3DWidget extends StatefulWidget {
  final int value; // número final del dado
  final bool rolling;

  const Dice3DWidget({super.key, required this.value, required this.rolling});

  @override
  State<Dice3DWidget> createState() => _Dice3DWidgetState();
}

class _Dice3DWidgetState extends State<Dice3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationX;
  late Animation<double> _rotationY;
  late Animation<double> _bounce;
  int displayedValue = 1;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rotationX = Tween<double>(begin: 0, end: pi * 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationY = Tween<double>(begin: 0, end: pi * 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _bounce = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.addListener(() {
      if (widget.rolling) {
        setState(() {
          displayedValue = _random.nextInt(6) + 1;
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
  void didUpdateWidget(covariant Dice3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.rolling && _controller.isAnimating) {
      _controller.stop(canceled: false);
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = widget.rolling
            ? Offset(_random.nextDouble() * 4 - 2, _random.nextDouble() * 4 - 2)
            : Offset(0, -_bounce.value);
        return Transform.translate(
          offset: offset,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateX(_rotationX.value)
              ..rotateY(_rotationY.value),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  displayedValue.toString(),
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
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

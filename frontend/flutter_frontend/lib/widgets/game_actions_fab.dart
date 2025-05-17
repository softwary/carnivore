import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmat;

class GameActionsFab extends StatefulWidget {
  final VoidCallback onClear;
  final VoidCallback? onSend;
  final VoidCallback? onFlip;
  final bool isCurrentUsersTurn;
  final bool isFlipping;

  const GameActionsFab({
    super.key,
    required this.onClear,
    this.onSend,
    this.onFlip,
    required this.isCurrentUsersTurn,
    required this.isFlipping,
  });

  @override
  _GameActionsFabState createState() => _GameActionsFabState();
}

class _GameActionsFabState extends State<GameActionsFab>
    with TickerProviderStateMixin {
  late AnimationController _localFlipController;
  late Animation<double> _localFlipAnimation;
  late AnimationController _localBlinkController;
  late Animation<double> _localBlinkAnimation;

  @override
  void initState() {
    super.initState();
    _localFlipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _localFlipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _localFlipController, curve: Curves.easeInOut),
    );

    _localBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _localBlinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _localBlinkController, curve: Curves.easeInOut),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    _updateBlinkState();
  }

  @override
  void didUpdateWidget(GameActionsFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentUsersTurn != oldWidget.isCurrentUsersTurn ||
        widget.isFlipping != oldWidget.isFlipping) {
      _updateBlinkState();
    }
  }

  void _updateBlinkState() {
    if (widget.isCurrentUsersTurn && !widget.isFlipping) {
      if (!_localBlinkController.isAnimating) {
        _localBlinkController.repeat(reverse: true);
      }
    } else {
      if (_localBlinkController.isAnimating) {
        _localBlinkController.stop();
        _localBlinkController.value = _localBlinkController.upperBound;
      }
    }
  }

  @override
  void dispose() {
    _localFlipController.dispose();
    _localBlinkController.dispose();
    super.dispose();
  }

  void _handleFlip() {
    if (widget.onFlip != null) {
      widget.onFlip!();
    }
    if (!_localFlipController.isAnimating) {
      _localFlipController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preRotatedText = Transform.rotate(
      angle: -math.pi / 4,
      child: const Text(
        'FLIP',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: widget.onClear,
          child: const Icon(Icons.clear),
          backgroundColor: Colors.red,
          heroTag: 'clear',
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          onPressed: widget.onSend,
          child: const Icon(Icons.send_rounded),
          backgroundColor: widget.onSend != null ? null : Colors.grey,
          heroTag: 'send',
        ),
        const SizedBox(width: 10),
        AnimatedBuilder(
          animation: Listenable.merge([_localFlipAnimation, _localBlinkAnimation]),
          child: preRotatedText,
          builder: (context, animatedChild) {
            final flipAnimationValue = _localFlipAnimation.value;
            final angle = -flipAnimationValue * math.pi;
            final isBack = angle.abs() > (math.pi / 2);

            final axis = vmat.Vector3(1, -1, 0).normalized();

            final transformMatrix = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotate(axis, angle);

            final Matrix4 unmirrorTransform;
            if (isBack) {
              unmirrorTransform = Matrix4.identity()..rotate(axis, math.pi);
            } else {
              unmirrorTransform = Matrix4.identity();
            }

            Color borderColor = const Color.fromARGB(255, 255, 0, 251);
            if (widget.isCurrentUsersTurn &&
                !widget.isFlipping &&
                _localBlinkController.isAnimating) {
              borderColor = borderColor.withOpacity(_localBlinkAnimation.value);
            } else if (widget.isCurrentUsersTurn) {
              borderColor = const Color.fromARGB(255, 255, 0, 251);
            }

            return Transform(
              alignment: Alignment.center,
              transform: transformMatrix,
              child: FloatingActionButton(
                onPressed: widget.isCurrentUsersTurn && !widget.isFlipping
                    ? _handleFlip
                    : null,
                backgroundColor: widget.isCurrentUsersTurn
                    ? Colors.yellow
                    : Colors.grey.shade400,
                foregroundColor: Colors.black,
                heroTag: 'flip',
                shape: widget.isCurrentUsersTurn
                    ? RoundedRectangleBorder(
                        side: BorderSide(
                          color: borderColor,
                          width: 5.0,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      )
                    : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: unmirrorTransform,
                  child: animatedChild,
                ),
              ),
            );
          },
        )
      ],
    );
  }
}

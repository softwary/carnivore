import 'package:flutter/material.dart';
import 'dart:async';

class MobileGameLogOverlay extends StatefulWidget {
  final String message; // The main log message
  final VoidCallback onComplete;
  final String? playerId; // The ID of the player associated with the log
  final Map<String, Color> playerColors; // Map of player IDs to colors
  final Map<String, String> playerIdToUsernameMap; // Map of player IDs to usernames

  const MobileGameLogOverlay({
    Key? key,
    required this.message,
    required this.onComplete,
    this.playerId,
    required this.playerColors,
    required this.playerIdToUsernameMap,
  }) : super(key: key);

  @override
  _MobileGameLogOverlayState createState() => _MobileGameLogOverlayState();
}

class _MobileGameLogOverlayState extends State<MobileGameLogOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Start a timer to begin the fade-out process
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.forward();
      }
    });

    // When the animation completes, call the onComplete callback
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85), // Slightly darker for contrast
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Wrap content
            children: [
              if (widget.playerId != null) ...[
                Container(
                  width: 12, // Smaller color indicator for overlay
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.playerColors[widget.playerId] ?? Colors.grey,
                    shape: BoxShape.circle, // Circular for a softer look
                  ),
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  '${widget.playerIdToUsernameMap[widget.playerId] ?? 'Player'}: ',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
              Expanded( // Allow message to take remaining space and wrap
                child: Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
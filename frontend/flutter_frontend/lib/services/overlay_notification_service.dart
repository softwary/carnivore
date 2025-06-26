import 'package:flutter/material.dart';
import 'package:flutter_frontend/widgets/mobile_game_log_overlay.dart';

class OverlayNotificationService {
  static void show(
    BuildContext context, {
    required String message,
    String? playerId,
    required Map<String, Color> playerColors,
    required Map<String, String> playerIdToUsernameMap,
  }) {
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50.0, // Position from the bottom of the screen
        left: 16,
        right: 16,
        child: Align(
          alignment: Alignment.center,
          child: MobileGameLogOverlay(
            message: message,
            playerId: playerId,
            playerColors: playerColors,
            playerIdToUsernameMap: playerIdToUsernameMap,
            onComplete: () {
              overlayEntry?.remove();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}
import 'package:flutter/material.dart';

class GameInstructionsDialogContent extends StatelessWidget {
  final bool isMobile;

  const GameInstructionsDialogContent({super.key, this.isMobile = false});

  TextSpan _keyStyle(String key, BuildContext context) {
    // Using context to potentially access theme in the future if needed
    return TextSpan(
      text: " $key ",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        backgroundColor: Colors.black,
        color: Colors.white,
        fontSize: 20, // Consider making this responsive or theme-based
        letterSpacing: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context)
            .style
            .copyWith(fontSize: 20, color: Colors.white),
        children: <TextSpan>[
          if (isMobile) ...[
            const TextSpan(text: "Tap the "),
            _keyStyle("X", context),
            const TextSpan(text: " on a selected tile to remove it.\n"),
            const TextSpan(text: "Tap "),
            _keyStyle("DEL", context),
            const TextSpan(text: " to remove the last typed letter.\nTap "),
            _keyStyle("FLIP", context),
            const TextSpan(text: " to flip a new tile.\n"),
          ] else ...[
            const TextSpan(text: "Press "),
            _keyStyle("ESC", context),
            const TextSpan(text: " to deselect tiles.\nPress "),
            _keyStyle("Enter", context),
            const TextSpan(text: " to submit a word or flip a new tile.\n"),
          ],
          const TextSpan(
              text: """\nWordivore is a word game played with 2+ players. There are 144 face-down letter tiles in the middle.  
Players take turns flipping over a tile to create words. The first player to type out a valid English word  
using the flipped tile gets to keep the letters in their word. Players can steal words by creating an anagram  
using the existing letters.  

The game ends when there are no more tiles left, and the player with the most tiles wins!"""
          ),
        ],
      ),
    );
  }
}
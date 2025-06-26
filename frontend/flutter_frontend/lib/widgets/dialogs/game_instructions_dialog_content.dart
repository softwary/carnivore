import 'package:flutter/material.dart';

class GameInstructionsDialogContent extends StatelessWidget {
  const GameInstructionsDialogContent({super.key});

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
        children: [
          const TextSpan(text: "Press "),
          _keyStyle("ESC", context),
          const TextSpan(text: " to deselect tiles\nPress "),
          _keyStyle("Enter", context),
          const TextSpan(text: " to submit tiles\nPress "),
          _keyStyle("Spacebar", context),
          const TextSpan(
              text: " to flip a tile\nClick a word to select all its tiles"),
          const TextSpan(
              text: """\nRWordivore is a word game played with 2+ players. There are 144 face-down letter tiles in the middle.  
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
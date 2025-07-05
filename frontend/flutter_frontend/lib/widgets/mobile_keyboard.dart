import 'package:flutter/material.dart';

class MobileKeyboard extends StatelessWidget {
  final void Function(String) onLetterPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onEnterPressed;

  const MobileKeyboard({
    super.key,
    required this.onLetterPressed,
    required this.onDeletePressed,
    required this.onEnterPressed,
  });

  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).size.height / 3;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MobileKeyboard.getKeyboardHeight(context);

    return Container(
      height: keyboardHeight,
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: _buildKeyboardRow(
                  ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'])),
          Expanded(
              child: _buildKeyboardRow(
                  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'])),
          Expanded(
              child: _buildKeyboardRow(
                  ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'DEL'])),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.map((letter) {
        if (letter == 'ENTER') {
          return _buildSpecialKey(letter, onEnterPressed, flex: 3);
        } else if (letter == 'DEL') {
          return _buildSpecialKey(letter, onDeletePressed, flex: 3);
        }
        return _buildLetterKey(letter);
      }).toList(),
    );
  }

  Widget _buildLetterKey(String letter) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Material(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: () => onLetterPressed(letter),
              child: Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(String label, VoidCallback onPressed, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Material(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

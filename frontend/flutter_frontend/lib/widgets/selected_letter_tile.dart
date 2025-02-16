import 'package:flutter/material.dart';

class SelectedLetterTile extends StatelessWidget {
  final String letter;
  final VoidCallback onRemove;
  final double tileSize; // NEW: Tile size parameter
  final Color textColor; // NEW: Text color parameter

  const SelectedLetterTile({
    Key? key,
    required this.letter,
    required this.onRemove,
    this.tileSize = 40, // Default size
    this.textColor = Colors.black, // Default text color
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: tileSize, // Use dynamic size
          height: tileSize, // Use dynamic size
          padding: const EdgeInsets.all(2.0), // Reduce padding for compact fit
          decoration: BoxDecoration(
            color: Colors.purple[700], // Same color as selected TileWidget
            border: Border.all(
              color: Colors.white, // Same border color as selected TileWidget
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Center(
            child: Text(
              letter,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: tileSize * 0.5, // Scale text to fit smaller tiles
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2.0), // Reduce padding
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 8, // Reduce icon size
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/widgets/selected_letter_tile.dart';

class SelectedTilesDisplay extends StatelessWidget {
  final List<Tile> inputtedLetters;
  final double tileSize;
  final Color Function(Tile tile) getTileBackgroundColor;
  final VoidCallback onRemoveTile; // Callback when any tile's remove icon is pressed

  const SelectedTilesDisplay({
    super.key,
    required this.inputtedLetters,
    required this.tileSize,
    required this.getTileBackgroundColor,
    required this.onRemoveTile,
  });

  @override
  Widget build(BuildContext context) {
    if (inputtedLetters.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no tiles are selected
    }
    return Wrap(
      spacing: 2.0, // Standardized spacing for selected tiles
      runSpacing: 2.0,
      children: inputtedLetters.map((tile) {
        return SelectedLetterTile(
          // It's good practice to provide a key if the list items can change
          key: ValueKey('selected_${tile.tileId}_${tile.letter}_${inputtedLetters.indexOf(tile)}'),
          tile: tile,
          tileSize: tileSize,
          backgroundColor: getTileBackgroundColor(tile),
          onRemove: onRemoveTile, // This will trigger the callback passed from GameScreen
        );
      }).toList(),
    );
  }
}

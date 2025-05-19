import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';

class MiddleTilesGridWidget extends StatelessWidget {
  final List<Tile> middleTiles;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final Map<String, GlobalKey> tileGlobalKeys;
  final double tileSize;
  final Function(Tile tile, bool isSelected) onTileSelected;
  final String currentPlayerTurnUsername;
  final int crossAxisCount;

  const MiddleTilesGridWidget({
    super.key,
    required this.middleTiles,
    required this.officiallySelectedTileIds,
    required this.potentiallySelectedTileIds,
    required this.tileGlobalKeys,
    required this.tileSize,
    required this.onTileSelected,
    required this.currentPlayerTurnUsername,
    this.crossAxisCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (middleTiles.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Flip a tile to begin – it's $currentPlayerTurnUsername's turn to flip a tile!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.0,
          crossAxisSpacing: 2.0,
          mainAxisSpacing: 2.0,
        ),
        itemCount: middleTiles.length,
        itemBuilder: (context, index) {
          if (index >= middleTiles.length) {
            return const SizedBox.shrink();
          }

          final tile = middleTiles[index];
          final tileIdStr = tile.tileId.toString();
          final tileKey = tileGlobalKeys[tileIdStr];
          final isSelected = officiallySelectedTileIds.contains(tileIdStr);
          final isHighlighted = potentiallySelectedTileIds.contains(tileIdStr) && !isSelected;

          Color backgroundColor;
          if (isSelected) {
            backgroundColor = Colors.deepPurple.shade700;
          } else if (isHighlighted) {
            backgroundColor = Colors.purple.withOpacity(0.35);
          } else {
            backgroundColor = Colors.purple;
          }

          return Padding(
            padding: const EdgeInsets.all(1.0),
            child: TileWidget(
              key: tileKey,
              tile: tile,
              tileSize: tileSize,
              onClickTile: (t, selectedState) => onTileSelected(t, selectedState),
              isSelected: isSelected,
              backgroundColor: backgroundColor,
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/widgets/animated_tile_widget.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';

class MiddleTilesGridWidget extends StatelessWidget {
  final List<Tile> middleTiles;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final Map<String, GlobalKey> tileGlobalKeys;
  final double tileSize;
  final Function(Tile, bool) onTileSelected;
  final String currentPlayerTurnUsername;
  final int crossAxisCount;
  final Map<String, Color> playerColors;
  final String? selectingPlayerId;
  final String? newestTileId;
  final bool isKeyboardMode;
  
  const MiddleTilesGridWidget({
    Key? key,
    required this.middleTiles,
    required this.officiallySelectedTileIds,
    required this.potentiallySelectedTileIds,
    required this.tileGlobalKeys,
    required this.tileSize,
    required this.onTileSelected,
    required this.currentPlayerTurnUsername,
    required this.crossAxisCount,
    required this.playerColors,
    this.selectingPlayerId,
    this.newestTileId,
    this.isKeyboardMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double spacing = 2.0;
    final int rowCount = (middleTiles.length / crossAxisCount).ceil();
    final double gridHeight = rowCount * tileSize + (rowCount - 1) * spacing;

    return SizedBox(
      height: gridHeight.isFinite && gridHeight > 0 ? gridHeight : tileSize,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: middleTiles.length,
        itemBuilder: (context, index) {
          final tile = middleTiles[index];
          final tileId = tile.tileId.toString();
          final isSelected = officiallySelectedTileIds.contains(tileId);
    
          final selectingPlayerColor =
              playerColors[selectingPlayerId] ?? const Color(0xFF4A148C);
          final tileColor = const Color(0xFF4A148C);
    
          if (tileId == newestTileId) {
            return AnimatedTileWidget(
              key: ValueKey(tileId),
              tile: tile,
              globalKey: tileGlobalKeys[tileId],
              tileSize: tileSize,
              onClickTile: onTileSelected,
              isSelected: isSelected,
              selectingPlayerColor: selectingPlayerColor,
              isKeyboardMode: isKeyboardMode,
            );
          }
    
          return TileWidget(
            key: ValueKey(tileId),
            tile: tile,
            globalKey: tileGlobalKeys[tileId],
            tileSize: tileSize,
            onClickTile: onTileSelected,
            isSelected: isSelected,
            backgroundColor: isSelected ? selectingPlayerColor : tileColor,
            isKeyboardMode: isKeyboardMode,
          );
        },
      ),
    );
  }
}
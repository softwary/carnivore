import 'package:flutter/material.dart';
import 'tile_widget.dart';
import 'package:flutter_frontend/classes/tile.dart';

class WordCard extends StatefulWidget {
  final List<Tile> tiles;
  final String currentOwnerUserId;
  final Function(List<dynamic>) onWordTap;
  final Map<String, Color> playerColors;
  final Function(Tile, bool) onClickTile;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final VoidCallback onClearSelection;
  final double tileSize;
  final Map<String, GlobalKey> tileGlobalKeys;
  final String? selectingPlayerId;
  final bool isKeyboardMode;

  const WordCard({
    Key? key,
    required this.tiles,
    required this.currentOwnerUserId,
    required this.onWordTap,
    required this.playerColors,
    required this.onClickTile,
    required this.officiallySelectedTileIds,
    required this.potentiallySelectedTileIds,
    required this.onClearSelection,
    required this.tileSize,
    required this.tileGlobalKeys,
    this.selectingPlayerId,
    this.isKeyboardMode = false,
  }) : super(key: key);

  @override
  _WordCardState createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  void _selectAllTiles() {
    setState(() {
      widget.onClearSelection();

      for (var tile in widget.tiles) {
        widget.onClickTile(tile, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownerColor =
        widget.playerColors[widget.currentOwnerUserId] ?? Colors.white;

    if (widget.isKeyboardMode) {
      final wordString = widget.tiles.map((t) => t.letter ?? '').join('');
      return Padding(
        // Padding to separate words from each other
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Text(
          wordString,
          style: TextStyle(
            color: ownerColor,
            // Match the font size from the original TileWidget for consistency
            fontSize: widget.tileSize * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _selectAllTiles();
        widget.onWordTap(widget.tiles.map((tile) => tile.tileId).toList());
      },
      child: Card(
        margin: const EdgeInsets.all(2.0), // Standardized margin for word cards
        color: ownerColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.tiles.isNotEmpty)
                Container(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.tiles
                        .where((tile) =>
                            tile.letter != null && tile.tileId != null)
                        .map<Widget>((tile) {
                      final tileId = tile.tileId?.toString() ?? "";
                      final tileOwner = widget.currentOwnerUserId;
                      final tileColor = widget.playerColors[tileOwner] ?? Colors.black;
                      final isSelected =
                          widget.officiallySelectedTileIds.contains(tileId);
                      final isHighlighted =
                          widget.potentiallySelectedTileIds.contains(tileId);
                      final selectingPlayerColor =
                          widget.playerColors[widget.selectingPlayerId] ??
                              const Color(0xFF4A148C);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 1), // Adjusted spacing
                        child: TileWidget(
                          key: ValueKey(tileId), 
                          tile: tile,
                          globalKey: widget.tileGlobalKeys[tileId],
                          tileSize: widget.tileSize,
                          onClickTile: widget.onClickTile,
                          isSelected: isSelected,
                          backgroundColor: isSelected
                              ? selectingPlayerColor
                              : isHighlighted
                                  ? tileColor.withOpacity(0.25)
                                  : tileColor,
                          isKeyboardMode: widget.isKeyboardMode,
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "No words submitted yet. Who will draw first blood?",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

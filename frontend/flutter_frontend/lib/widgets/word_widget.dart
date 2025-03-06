import 'package:flutter/material.dart';
import 'tile_widget.dart';
import 'selected_letter_tile.dart';

class WordCard extends StatefulWidget {
  final List<Map<String, dynamic>> tiles;
  final String currentOwnerUserId;
  final Function(List<dynamic>) onWordTap;
  final Map<String, Color> playerColors;
  final Function(String, String, bool) onClickTile;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final VoidCallback onClearSelection;
  final double tileSize;

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
  }) : super(key: key);

  @override
  _WordCardState createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  void _selectAllTiles() {
    setState(() {
      widget.onClearSelection();

      for (var tile in widget.tiles) {
        final letter = tile['letter']?.toString() ?? "?";
        final tileId = tile['tileId']?.toString() ?? "";
        widget.onClickTile(letter, tileId, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownerColor =
        widget.playerColors[widget.currentOwnerUserId] ?? Colors.grey;
    return GestureDetector(
      onTap: () {
        _selectAllTiles();
        widget.onWordTap(widget.tiles.map((tile) => tile['tileId']).toList());
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: ownerColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.tiles.isNotEmpty)
                Container(
                  alignment:
                      Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.tiles
                        .where((tile) =>
                            tile['letter'] != null && tile['tileId'] != null)
                        .map<Widget>((tile) {
                      final letter = tile['letter']?.toString() ?? "?";
                      final tileId = tile['tileId']?.toString() ?? "";
                      final tileOwner = tile['ownerUserId'] as String?;
                      final tileColor =
                          widget.playerColors[tileOwner] ?? Colors.black;
                      final isSelected =
                          widget.officiallySelectedTileIds.contains(tileId);
                      final isHighlighted =
                          widget.potentiallySelectedTileIds.contains(tileId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 1), // Adjusted spacing
                        child: TileWidget(
                          letter: letter,
                          tileId: tileId,
                          tileSize: widget.tileSize,
                          onClickTile: widget.onClickTile,
                          isSelected: isSelected,
                          backgroundColor: isSelected
                              ? Color(0xFF4A148C)
                              : isHighlighted
                                  ? tileColor.withOpacity(0.25)
                                  : tileColor,
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

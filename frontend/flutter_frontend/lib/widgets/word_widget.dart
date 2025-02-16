import 'package:flutter/material.dart';
import 'tile_widget.dart';

class WordCard extends StatelessWidget {
  final List<Map<String, dynamic>> tiles;
  final String currentOwnerUserId;
  final Function(List<dynamic>) onWordTap;
  final Map<String, Color> playerColors;
  final Function(String, String, bool) onClickTile;

  const WordCard({
    Key? key,
    required this.tiles,
    required this.currentOwnerUserId,
    required this.onWordTap,
    required this.playerColors,
    required this.onClickTile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ownerColor = playerColors[currentOwnerUserId] ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        onWordTap(tiles.map((tile) => tile['tileId']).toList());
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: ownerColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevents excessive vertical stretching
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (tiles.isNotEmpty)
                Container(
                  height: 40, // Fixed height for tile row to maintain alignment
                  alignment: Alignment.center, // Center tiles within the card
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: tiles
                        .where((tile) => tile['letter'] != null && tile['tileId'] != null)
                        .map<Widget>((tile) {
                      final letter = tile['letter']?.toString() ?? "?";
                      final tileId = tile['tileId']?.toString() ?? "";
                      final tileOwner = tile['ownerUserId'] as String?;
                      final tileColor = playerColors[tileOwner] ?? Colors.black;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3), // Adjusted spacing
                        child: TileWidget(
                          letter: letter,
                          tileId: tileId,
                          onClickTile: onClickTile,
                          isSelected: false,
                          textColor: tileColor,
                          tileSize: 36, // Ensuring consistent tile size
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "No tiles available",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 6),
              Text(
                "Submitted by: $currentOwnerUserId",
                style: TextStyle(fontSize: 10, color: ownerColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

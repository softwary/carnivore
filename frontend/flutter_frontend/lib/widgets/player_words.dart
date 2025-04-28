import 'package:flutter/material.dart';
import 'word_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_frontend/classes/tile.dart';


class PlayerWords extends StatelessWidget {
  final String playerId;
  final String username;
  final List<Map<String, dynamic>> words;
  final Map<String, Color> playerColors;
  final Function(Tile, bool) onClickTile;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final VoidCallback onClearSelection;
  final List<Tile> allTiles;
  final double tileSize;
  final bool isCurrentPlayerTurn; 
  final int score; 

  const PlayerWords({
    Key? key,
    required this.username,
    required this.playerId,
    required this.words,
    required this.playerColors,
    required this.onClickTile,
    required this.officiallySelectedTileIds,
    required this.potentiallySelectedTileIds,
    required this.onClearSelection,
    required this.allTiles,
    this.tileSize = 36,
    required this.isCurrentPlayerTurn,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                isCurrentPlayerTurn
            ? Shimmer.fromColors(
                baseColor: Colors.white,
                highlightColor: Colors.yellow,
                child: Text(
                  '$username ($score)',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              )
            : Text(
                '$username ($score)',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 2.0, // Space between cards
          runSpacing: 2.0, // Space between lines
          children: words.map((word) {
            List<Tile> tiles = [];
            if (word['tileIds'] is List<dynamic>) {
              tiles = (word['tileIds'] as List<dynamic>)
                  .map((tileId) {
                    final matchingTile = allTiles.firstWhere(
                      (tile) =>
                      tile.tileId == tileId,
                      orElse: () => Tile(tileId: '', letter: '', location: ''),
                    );
                    return matchingTile.tileId == '' ? null : matchingTile;
                  })
                  .whereType<Tile>()
                  .toList();
            }

            return IntrinsicWidth(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: WordCard(
                    tiles: tiles,
                    currentOwnerUserId: playerId,
                    onWordTap: (tileIds) {
                    },
                    playerColors: playerColors,
                    onClickTile: onClickTile,
                    officiallySelectedTileIds: officiallySelectedTileIds,
                    potentiallySelectedTileIds: potentiallySelectedTileIds,
                    onClearSelection: onClearSelection,
                    tileSize: tileSize,
                  )),
            );
          }).toList(),
        ),
      ],
    );
  }
}

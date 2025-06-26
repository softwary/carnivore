import 'package:flutter/material.dart';
import 'word_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_frontend/classes/tile.dart';

class PlayerWords extends StatelessWidget {
  final String playerId;
  final int playerIndex;
  final int playerCount;
  final String username;
  final List<Map<String, dynamic>> words;
  final Map<String, Color> playerColors;
  final Function(Tile, bool) onClickTile;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final VoidCallback onClearSelection;
  final List<Tile> allTiles;
  final Map<String, GlobalKey> tileGlobalKeys;
  final double tileSize;
  final bool isCurrentPlayerTurn;
  final int score;
  final int maxScoreToWin;
  final String? selectingPlayerId;

  const PlayerWords({
    required this.playerIndex,
    required this.playerCount,
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
    required this.tileGlobalKeys,
    this.tileSize = 36,
    required this.isCurrentPlayerTurn,
    required this.score,
    required this.maxScoreToWin,
    this.selectingPlayerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Wrap(
          spacing: 0.0,
          runSpacing: 0.0,
          children: words.map((word) {
            List<Tile> tiles = [];
            final bool isAnimatingPlaceholder =
                word['isAnimatingDestinationPlaceholder'] == true;

            if (word['tileIds'] is List<dynamic>) {
              tiles = (word['tileIds'] as List<dynamic>)
                  .map((tileId) {
                    final matchingTile = allTiles.firstWhere(
                      (tile) => tile.tileId == tileId,
                      orElse: () => Tile(tileId: '', letter: '', location: ''),
                    );
                    return matchingTile.tileId == '' ? null : matchingTile;
                  })
                  .whereType<Tile>()
                  .toList();
            }

            return Opacity(
              opacity: isAnimatingPlaceholder ? 0.0 : 1.0,
              child: IntrinsicWidth(
                  child: WordCard(
                key: ValueKey(word['wordId']),
                tiles: tiles,
                selectingPlayerId: selectingPlayerId,
                currentOwnerUserId: playerId,
                onWordTap: (tileIds) {},
                playerColors: playerColors,
                onClickTile: onClickTile,
                officiallySelectedTileIds: officiallySelectedTileIds,
                potentiallySelectedTileIds: potentiallySelectedTileIds,
                onClearSelection: onClearSelection,
                tileSize: tileSize,
                tileGlobalKeys: tileGlobalKeys,
              )),
            );
          }).toList(),
        ),
      ],
    );
  }
}

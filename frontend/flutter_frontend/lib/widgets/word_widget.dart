import 'package:flutter/material.dart';
import 'tile_widget.dart';

class WordCard extends StatelessWidget {
  final List<Map<String, dynamic>> tiles;
  final String currentOwnerUserId;
  final Function(List<dynamic>) onWordTap;

  const WordCard({
    Key? key,
    required this.tiles,
    required this.currentOwnerUserId,
    required this.onWordTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onWordTap(tiles.map((tile) => tile['tileId']).toList());
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: tiles.map<Widget>((tile) {
                  if (tile == null) {
                    return const SizedBox.shrink();
                  }
                  final letter = tile['letter'] as String? ?? "";
                  final tileId = tile['tileId']?.toString() ?? "";
                  return TileWidget(
                    letter: letter,
                    tileId: tileId,
                    onClickTile: (letter, tileId, isSelected) {},
                    isSelected: false,
                  );
                }).toList(),
              ),
              Text(
                "Submitted by: $currentOwnerUserId",
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
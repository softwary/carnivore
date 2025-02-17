// import 'package:flutter/material.dart';
// import 'tile_widget.dart';
// import 'package:flutter_frontend/widgets/selected_letter_tile.dart';

// class WordCard extends StatefulWidget {
//   final List<Map<String, dynamic>> tiles;
//   final String currentOwnerUserId;
//   final Function(List<dynamic>) onWordTap;
//   final Map<String, Color> playerColors;
//   final Function(String, String, bool) onClickTile;
//   final Set<String> selectedTileIds; // NEW: Selected tile IDs

//   const WordCard({
//     Key? key,
//     required this.tiles,
//     required this.currentOwnerUserId,
//     required this.onWordTap,
//     required this.playerColors,
//     required this.onClickTile,
//     required this.selectedTileIds, // NEW: Selected tile IDs
//   }) : super(key: key);

//   @override
//   _WordCardState createState() => _WordCardState();
// }

// class _WordCardState extends State<WordCard> {
//   @override
//   Widget build(BuildContext context) {
//     final ownerColor =
//         widget.playerColors[widget.currentOwnerUserId] ?? Colors.grey;

//     return GestureDetector(
//       onTap: () {
//         widget.onWordTap(widget.tiles.map((tile) => tile['tileId']).toList());
//       },
//       child: Card(
//         margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//         color: ownerColor.withOpacity(0.2),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//           child: Column(
//             mainAxisSize:
//                 MainAxisSize.min, // Prevents excessive vertical stretching
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               if (widget.tiles.isNotEmpty)
//                 Container(
//                   height: 40, // Fixed height for tile row to maintain alignment
//                   alignment: Alignment.center, // Center tiles within the card
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: widget.tiles
//                         .where((tile) =>
//                             tile['letter'] != null && tile['tileId'] != null)
//                         .map<Widget>((tile) {
//                       final letter = tile['letter']?.toString() ?? "?";
//                       final tileId = tile['tileId']?.toString() ?? "";
//                       final tileOwner = tile['ownerUserId'] as String?;
//                       final tileColor =
//                           widget.playerColors[tileOwner] ?? Colors.black;
//                       final isSelected =
//                           widget.selectedTileIds.contains(tileId);

//                       return Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 3), // Adjusted spacing
//                         child: isSelected
//                             ? SelectedLetterTile(
//                                 letter: letter,
//                                 onRemove: () {
//                                   widget.onClickTile(letter, tileId, false);
//                                 },
//                                 tileSize: 36, // Ensuring consistent tile size
//                                 textColor: tileColor, // Pass text color
//                               )
//                             : TileWidget(
//                                 letter: letter,
//                                 tileId: tileId,
//                                 onClickTile: widget.onClickTile,
//                                 isSelected: isSelected,
//                                 textColor: tileColor,
//                                 tileSize: 36, // Ensuring consistent tile size
//                               ),
//                       );
//                     }).toList(),
//                   ),
//                 )
//               else
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Text(
//                     "No tiles available",
//                     style: TextStyle(color: Colors.red, fontSize: 12),
//                   ),
//                 ),
//               const SizedBox(height: 6),
//               Text(
//                 "Submitted by: ${widget.currentOwnerUserId}",
//                 style: TextStyle(fontSize: 10, color: ownerColor),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'tile_widget.dart';
import 'selected_letter_tile.dart';

class WordCard extends StatefulWidget {
  final List<Map<String, dynamic>> tiles;
  final String currentOwnerUserId;
  final Function(List<dynamic>) onWordTap;
  final Map<String, Color> playerColors;
  final Function(String, String, bool) onClickTile;
  final Set<String> selectedTileIds; // NEW: Selected tile IDs

  const WordCard({
    Key? key,
    required this.tiles,
    required this.currentOwnerUserId,
    required this.onWordTap,
    required this.playerColors,
    required this.onClickTile,
    required this.selectedTileIds, // NEW: Selected tile IDs
  }) : super(key: key);

  @override
  _WordCardState createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  void _selectAllTiles() {
    for (var tile in widget.tiles) {
      final letter = tile['letter']?.toString() ?? "?";
      final tileId = tile['tileId']?.toString() ?? "";
      widget.onClickTile(letter, tileId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerColor = widget.playerColors[widget.currentOwnerUserId] ?? Colors.grey;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevents excessive vertical stretching
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.tiles.isNotEmpty)
                Container(
                  height: 40, // Fixed height for tile row to maintain alignment
                  alignment: Alignment.center, // Center tiles within the card
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.tiles
                        .where((tile) => tile['letter'] != null && tile['tileId'] != null)
                        .map<Widget>((tile) {
                      final letter = tile['letter']?.toString() ?? "?";
                      final tileId = tile['tileId']?.toString() ?? "";
                      final tileOwner = tile['ownerUserId'] as String?;
                      final tileColor = widget.playerColors[tileOwner] ?? Colors.black;
                      final isSelected = widget.selectedTileIds.contains(tileId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3), // Adjusted spacing
                        child: isSelected
                            ? SelectedLetterTile(
                                letter: letter,
                                onRemove: () {
                                  widget.onClickTile(letter, tileId, false);
                                },
                                tileSize: 36, // Ensuring consistent tile size
                                textColor: tileColor, // Pass text color
                              )
                            : TileWidget(
                                letter: letter,
                                tileId: tileId,
                                onClickTile: widget.onClickTile,
                                isSelected: isSelected,
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
                "Submitted by: ${widget.currentOwnerUserId}",
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
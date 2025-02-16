import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/widgets/horizontal_reorderable_list_view.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_frontend/widgets/word_widget.dart';
import 'package:flutter_frontend/widgets/selected_letter_tile.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  late DatabaseReference gameRef;
  Map<String, dynamic>? gameData;
  Map<String, Color> playerColorMap = {}; // Store player colors
  List<int> orderedTiles = [];
  List<Map<String, String>> selectedTiles = [];
  List<Color> playerColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    fetchGameData();
  }

  void fetchGameData() {
    gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');

    gameRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data is Map) {
        setState(() {
          gameData = jsonDecode(jsonEncode(
              data)); // 🔹 Fix: Convert LinkedHashMap to standard Map

          // Assign colors to players
          final playerIds = gameData?['players']?.keys.toList() ?? [];
          for (int i = 0; i < playerIds.length; i++) {
            playerColorMap[playerIds[i]] =
                playerColors[i % playerColors.length];
          }
        });
      } else {
        print("Unexpected data format: $data");
      }
    });
  }

  Future<void> _sendTileIds() async {
    if (orderedTiles.isEmpty || orderedTiles.length < 3) {
      return;
    }
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final url = Uri.parse('http://192.168.1.218:4000/submit-word');
    print("Sending tileIds: $orderedTiles");
    final game_id_log = widget.gameId;
    print("Sending tileIds: $game_id_log");
    final Map<String, dynamic> payload = {
      'game_id': widget.gameId,
      'tile_ids': orderedTiles,
    };
    print("Payload: $payload");

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          print("Response Data: $responseData");
          selectedTiles.clear();
          orderedTiles.clear();
        });
      } else {
        print(
            'Error sending tileIds: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending tileIds: $e');
    }
  }

  Future<void> _flipNewTile() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final url = Uri.parse('http://192.168.1.218:4000/flip-tile');
    print("Trying to flip a new tile");
    final Map<String, dynamic> payload = {
      'game_id': widget.gameId,
    };
    print("Payload: $payload");

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          gameData = responseData["data"]["game"];
        });
      } else {
        print(
            'Error flipping new tile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error making flip new tile request: $e');
    }
  }

  void handleTileSelection(String letter, String tileId, bool isSelected) {
    setState(() {
      final tileData = {'letter': letter, 'tileId': tileId};
      if (isSelected) {
        if (!selectedTiles.any((tile) => tile['tileId'] == tileId)) {
          selectedTiles.add(tileData);
        }
      } else {
        selectedTiles.removeWhere((tile) => tile['tileId'] == tileId);
      }
      if (selectedTiles.isNotEmpty) {
        _handleReorderFinished(
            selectedTiles.map((tile) => int.parse(tile['tileId']!)).toList());
      }
    });
  }

  void _handleReorderFinished(List<int> newTileIds) {
    setState(() {
      orderedTiles = newTileIds;
    });
  }

  dynamic _convertToMap(dynamic value) {
    if (value is Map<Object?, Object?> ||
        value is LinkedHashMap<Object?, Object?>) {
      return value
          .map((key, value) => MapEntry(key.toString(), _convertToMap(value)));
    } else if (value is List) {
      return value.map((item) => _convertToMap(item)).toList();
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Game ${widget.gameId}")),
      body: gameData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Player IDs:",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    gameData?['players']
                            ?.entries
                            .map((entry) =>
                                '${entry.key} (${entry.value['score'] ?? 0})')
                            .join(', ') ??
                        'No players',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  // Words
                  // Words
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // Number of columns
                        childAspectRatio:
                            3, // Adjust the aspect ratio as needed
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: gameData?['words']?.length ?? 0,
                      itemBuilder: (context, index) {
                        final wordKey =
                            gameData?['words']?.keys.toList()[index];
                        final wordEntryRaw = gameData?['words']?[wordKey];

                        final wordEntry = wordEntryRaw is Map
                            ? Map<String, dynamic>.from(wordEntryRaw.map(
                                (key, value) =>
                                    MapEntry(key.toString(), value)))
                            : null;

                        final ownerId =
                            wordEntry?['current_owner_user_id'] as String? ??
                                '';

                        // 🔹 Fetch tileIds safely
                        final tileIds =
                            (wordEntry?['tileIds'] as List<dynamic>?) ?? [];
                        print(
                            "🟢 Word: $wordKey, Tile IDs: $tileIds"); // Debugging output

                        List<Map<String, dynamic>> tiles = [];

                        if (gameData?['tiles'] is List<dynamic>) {
                          final allTiles = List<Map<String, dynamic>>.from(
                            gameData!['tiles'].whereType<Map>().toList(),
                          );

                          print(
                              "🔵 All Tiles in gameData: $allTiles"); // Debugging all tiles

                          // 🔹 Ensure tile ID comparison is correct
                          tiles = tileIds
                              .map((tileId) {
                                final matchingTile = allTiles.firstWhere(
                                  (tile) =>
                                      tile.containsKey('tileId') &&
                                      tile['tileId'].toString() ==
                                          tileId.toString(),
                                  orElse: () => <String,
                                      dynamic>{}, // Return an empty map instead of null
                                );

                                if (matchingTile.isEmpty) {
                                  print("⚠️ Tile with ID $tileId not found!");
                                  return null;
                                } else {
                                  print(
                                      "✅ Found tile for word $wordKey: $matchingTile");
                                  return matchingTile;
                                }
                              })
                              .where((tile) => tile != null)
                              .cast<Map<String, dynamic>>()
                              .toList();
                        } else {
                          print("⚠️ gameData['tiles'] is null or not a List");
                        }

                        print(
                            "🟣 Tiles passed to WordCard: $tiles"); // Debugging

                        return WordCard(
                          tiles: tiles,
                          currentOwnerUserId: ownerId,
                          playerColors: playerColorMap,
                          onWordTap: (List<dynamic> tiles) {},
                          onClickTile: handleTileSelection,
                        );
                      },
                    ),
                  ),
                  // Tiles
                  Text(
                    gameData?['tiles'] != null ? "Tiles:" : "",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 12, // Increase the number of columns
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 1.0, // Reduce spacing
                        mainAxisSpacing: 1.0, // Reduce spacing
                      ),
                      itemCount: (gameData?['tiles'] as List?)
                              ?.where((tile) =>
                                  tile != null &&
                                  tile is Map &&
                                  tile['location'] == 'middle' &&
                                  (tile['letter'] as String?)?.isNotEmpty ==
                                      true)
                              .length ??
                          0,
                      itemBuilder: (context, index) {
                        final tiles = (gameData?['tiles'] as List?)
                            ?.where((tile) =>
                                tile != null &&
                                tile is Map &&
                                tile['location'] == 'middle' &&
                                (tile['letter'] as String?)?.isNotEmpty == true)
                            .toList();

                        if (tiles == null || index >= tiles.length) {
                          return const SizedBox.shrink();
                        }

                        final tile = tiles[index] as Map<dynamic, dynamic>?;
                        final letter = tile?['letter'] as String? ?? "";
                        final tileId = tile?['tileId']?.toString() ?? "";
                        print("gameData?['tiles']: $gameData?['tiles']");
                        return Padding(
                          padding: const EdgeInsets.all(1.0), // Reduced padding
                          child: TileWidget(
                            letter: letter,
                            tileId: tileId,
                            onClickTile: (selectedLetter, tileId, isSelected) {
                              setState(() {
                                handleTileSelection(
                                    selectedLetter, tileId, isSelected);
                              });
                            },
                            isSelected: false,
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    "Selected Items:",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  HorizontalReorderableListView(
                    items: selectedTiles,
                    itemBuilder: (tile) {
                      return SelectedLetterTile(
                        letter: tile['letter']!,
                        onRemove: () {
                          setState(() {
                            selectedTiles.remove(tile);
                            orderedTiles.remove(int.parse(tile['tileId']!));
                          });
                        },
                      );
                    },
                    onReorderFinished: _handleReorderFinished,
                  ),
                ],
              ),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              setState(() {
                selectedTiles.clear();
                orderedTiles.clear();
              });
            },
            child: const Icon(Icons.clear),
            backgroundColor: Colors.red,
            heroTag: 'clear',
          ),
          const SizedBox(width: 10), // Use width for horizontal spacing
          FloatingActionButton(
            onPressed: orderedTiles.isNotEmpty
                ? _sendTileIds
                : null, // Disable if no tiles
            child: const Icon(Icons.send_rounded),
            backgroundColor:
                orderedTiles.isNotEmpty ? null : Colors.grey, // Change color
            heroTag: 'send',
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _flipNewTile,
            child: const Icon(Icons.refresh_rounded),
            backgroundColor: Colors.yellow,
            heroTag: 'flip',
          ),
        ],
      ),
    );
  }
}

String _buildWordHistoryTooltip(List<dynamic> wordHistory) {
  final buffer = StringBuffer();
  final formatter = DateFormat('yyyy-MM-dd HH:mm:ss'); // Format the timestamp

  for (var entry in wordHistory.reversed) {
    // Show history from latest to oldest
    final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp']);
    final formattedTime =
        formatter.format(timestamp.toLocal()); // Format the date and time
    buffer.writeln("Word: ${entry['word']}");
    buffer.writeln("Player: ${entry['playerId']}");
    buffer.writeln("Time: $formattedTime"); // Add the formatted timestamp
    buffer.writeln("-------------------");
  }
  return buffer.toString();
}

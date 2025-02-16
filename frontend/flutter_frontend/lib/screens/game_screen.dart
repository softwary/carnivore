import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/widgets/horizontal_reorderable_list_view.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  GameScreenState createState() => GameScreenState();
}

class SelectedLetterTile extends StatelessWidget {
  final String letter;

  const SelectedLetterTile({
    super.key,
    required this.letter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Text(
          letter,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontSize: 18,
              ),
        ),
      ),
    );
  }
}

class GameScreenState extends State<GameScreen> {
  late DatabaseReference gameRef;
  Map<String, dynamic>? gameData;
  List<Map<String, String>> selectedTiles =
      []; // List of Maps for showing which tiles are selected
  List<int> orderedTiles = []; // for submitting words

  void _handleReorderFinished(List<int> newTileIds) {
    setState(() {
      print("@@ Received reordered tileIds: $newTileIds");
      orderedTiles =
          newTileIds; // Update orderedTiles with the new order when tiles are rearranged
      print("@@ Updated orderedTiles: $orderedTiles");
    });
  }

  void handleTileSelection(String letter, String tileId, bool isSelected) {
    print(
        "handleTileSelection called with letter: $letter, tileId: $tileId, isSelected: $isSelected");
    setState(() {
      final tileData = {'letter': letter, 'tileId': tileId};
      if (isSelected) {
        if (!selectedTiles.any((tile) => tile['tileId'] == tileId)) {
          print(
              "This tile was not in here, adding this tile ($letter) to selectedTiles");
          selectedTiles.add(tileData);
        }
      } else {
        selectedTiles.removeWhere((tile) => tile['tileId'] == tileId);
      }
      if (selectedTiles.isNotEmpty) {
        _handleReorderFinished(
            selectedTiles.map((tile) => int.parse(tile['tileId']!)).toList());
      }
      print("My Tiles: $selectedTiles");
    });
  }

  @override
  void initState() {
    super.initState();
    fetchGameData();
  }

  void fetchGameData() {
    print('Fetching game data for gameId: ${widget.gameId}');
    gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');

    gameRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      print('Data received from Firebase = $data');
      if (data != null) {
        print('Data is not null, updating state');
        setState(() {
          gameData = Map<String, dynamic>.from(data);
          print("@@IN fetchGameData...Game Data: $gameData");
        });
      } else {
        print('Data is null');
      }
    }, onError: (error) {
      print('Error fetching data: $error');
    });
  }

  // Future<void> _sendTileIds() async {
  //   if (orderedTiles.isEmpty || orderedTiles.length < 3) {
  //     return;
  //   }
  //   final token = await FirebaseAuth.instance.currentUser!.getIdToken();
  //   final url = Uri.parse('http://192.168.1.218:4000/submit-word');
  //   print("Sending tileIds: $orderedTiles");
  //   final game_id_log = widget.gameId;
  //   print("Sending tileIds: $game_id_log");
  //   final Map<String, dynamic> payload = {
  //     'game_id': widget.gameId,
  //     'tile_ids': orderedTiles,
  //   };
  //   print("Payload: $payload");

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token'
  //       },
  //       body: jsonEncode(payload),
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseData = jsonDecode(response.body);
  //       setState(() {
  //         print("Response Data: $responseData");
  //       });
  //       selectedTiles.clear();
  //       orderedTiles.clear();
  //     } else {
  //       print(
  //           'Error sending tileIds: ${response.statusCode} - ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error sending tileIds: $e');
  //   }
  // }

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

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    print('Building GameScreen for gameId: ${widget.gameId}');
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          title: Text("Game ${widget.gameId}")),
      body: gameData == null
          ? const Center(
              child: CircularProgressIndicator()) // Show loading indicator
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player Ids
                  Text(
                    "Player IDs:",
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    gameData?['players']
                            ?.entries
                            .map((entry) =>
                                '${entry.key} (${entry.value['score'] ?? 0})')
                            .join(', ') ??
                        'No players',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  // const SizedBox(height: 10),
                  // Player Words
                  const SizedBox(height: 5),
                  //
                  Expanded(
                    // Words Display
                    child: gameData != null &&
                            gameData!['words'] is Map<dynamic, dynamic>
                        ? ListView.builder(
                            itemCount: (gameData!['words'] as Map).length,
                            itemBuilder: (context, index) {
                              final wordKey =
                                  ((gameData?['words'] ?? {}) as Map)
                                      .keys
                                      .toList()[index];
                              final wordEntry = (gameData!['words']
                                      as Map<dynamic, dynamic>?)?[wordKey]
                                  as Map<dynamic, dynamic>?;
                              final word = (wordEntry?['word'] ?? '') as String;
                              final currentOwnerUserId =
                                  (wordEntry?['current_owner_user_id'] ?? '')
                                      as String;
                              final tileIds =
                                  (wordEntry?['tileIds'] as List<dynamic>?) ??
                                      "";

                              final tiles = (tileIds as List<dynamic>)
                                  .map((tileId) {
                                    return (gameData!['tiles'] as List?)
                                        ?.firstWhere(
                                      (tile) => tile?['tileId'] == tileId,
                                      orElse: () => null,
                                    );
                                  })
                                  .where((tile) => tile != null)
                                  .toList();

                              // Sort tiles based on the order of tileIds
                              tiles.sort((a, b) {
                                final aTileId = a?['tileId'];
                                final bTileId = b?['tileId'];
                                return tileIds
                                    .indexOf(aTileId)
                                    .compareTo(tileIds.indexOf(bTileId));
                              });

                              // Normalize word history to be a list of maps
                              List<dynamic> wordHistory = [];
                              if (wordEntry?['word_history'] is Map) {
                                // Convert map to list
                                wordHistory =
                                    (wordEntry!['word_history'] as Map)
                                        .values
                                        .toList();
                              } else if (wordEntry?['word_history'] is List) {
                                // Use the list directly
                                wordHistory =
                                    wordEntry!['word_history'] as List;
                              }

                              return Card(
                                // Wrap each word in a Card for better visual separation
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                // Add margin
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  // Add padding
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(
                                          height: 8), // Increased spacing
                                      Row(
                                        children: tiles.map<Widget>((tile) {
                                          final letter =
                                              tile?['letter'] as String ?? "";
                                          final tileId =
                                              tile?['tileId']?.toString() ?? "";
                                          return TileWidget(
                                            letter: letter,
                                            tileId: tileId,
                                            onClickTile: handleTileSelection,
                                            isSelected: selectedTiles.any(
                                                (t) => t['tileId'] == tileId),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(
                                          height: 8), // Increased spacing

                                      if (wordHistory.isNotEmpty) ...[
                                        Tooltip(
                                          message: _buildWordHistoryTooltip(
                                              wordHistory),
                                          child: const Text(
                                            "Word History (hover to view)",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                      Text(
                                        "Submitted by: $currentOwnerUserId",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(child: Text("No words yet.")),
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
                      return SelectedLetterTile(letter: tile['letter']!);
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

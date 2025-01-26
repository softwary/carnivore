import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/widgets/horizontal_reorderable_list_view.dart';
import 'package:http/http.dart' as http;

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
      print('Data received from Firebase');
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
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

  Future<void> _sendTileIds() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final url = Uri.parse('http://192.168.1.218:4000/submit-word');
    print("Sending tileIds: $orderedTiles");
    final Map<String, dynamic> payload = {
      'gameId': widget.gameId,
      'tileIds': orderedTiles,
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
        });
        selectedTiles.clear();
        orderedTiles.clear();
      } else {
        print(
            'Error sending tileIds: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending tileIds: $e');
    }
  }

  Future<void> _flipNewTile() async {
    final url = Uri.parse('http://192.168.1.218:4000/flip-tile');
    final Map<String, String> payload = {
      'gameId': widget.gameId,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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
                    gameData?['players']?.entries
                      .map((entry) => '${entry.key} (${entry.value['score']})')
                      .join(', ') ??
                      'No players',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 10),
                  // Player Words
                  const SizedBox(height: 5),
                  Expanded(
                    child: ListView.builder(
                      itemCount: gameData?['words']?.length ?? 0,
                      itemBuilder: (context, index) {
                        final words = gameData?['words'] ?? [];

                        if (index >= words.length) {
                          return const SizedBox.shrink();
                        }
                        final wordEntry = words[index] as Map<dynamic, dynamic>?;
                        final tileIds = wordEntry?['tileIds'] as List<dynamic>? ?? [];
                        final tiles = tileIds.map((tileId) {
                          return gameData?['tiles']?.firstWhere((tile) => tile['tileId'] == tileId);
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0)
                              Text(
                                "Words:",
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            Row(
                              children: tiles.map((tile) {
                                final letter = tile?['letter'] as String? ?? "";
                                final tileId = tile?['tileId']?.toString() ?? "";
                                return TileWidget(
                                  letter: letter,
                                  tileId: tileId,
                                  onClickTile: handleTileSelection,
                                  isSelected: selectedTiles.any((t) => t['tileId'] == tileId),
                                );
                              }).toList(),
                            ),
                            Text(
                              "Submitted by: ${wordEntry?['user_id'] as String? ?? ""}",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                          ],
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
                        crossAxisCount: 4,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
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
                          padding: const EdgeInsets.all(4.0),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logic for flipping a new tile (call your Flask endpoint)
          // _flipNewTile();
          // TODO: Create flipTile logic
          _sendTileIds();
        },
        child: const Icon(Icons.send_rounded),
      ),
      backgroundColor: Colors.black,
    );
  }
}

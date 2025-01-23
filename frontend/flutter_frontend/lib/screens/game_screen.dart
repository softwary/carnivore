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
  List<Map<String, String>> selectedTiles = []; // List of Maps
  List<Map<String, String>> orderedTiles = []; // for submitting words

  void _handleReorderFinished(List<Map<String, String>> newOrder) {
    setState(() {
      orderedTiles = newOrder;
      print("New Order: $orderedTiles");
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
      print("Selected Tiles: $selectedTiles");
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
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    gameData?['players']?.keys.join(', ') ??
                        'No players', // Added comma separation
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
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
                                  tile['inMiddle'] == true &&
                                  (tile['letter'] as String?)?.isNotEmpty ==
                                      true)
                              .length ??
                          0,
                      itemBuilder: (context, index) {
                        final tiles = (gameData?['tiles'] as List?)
                            ?.where((tile) =>
                                tile != null &&
                                tile is Map &&
                                tile['inMiddle'] == true &&
                                (tile['letter'] as String?)?.isNotEmpty == true)
                            .toList();

                        if (tiles == null || index >= tiles.length) {
                          return const SizedBox.shrink();
                        }

                        final tile = tiles[index] as Map<dynamic, dynamic>?;
                        final letter = tile?['letter'] as String? ?? "";
                        final tileId = tile?['tileId']?.toString() ?? "";

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
                      return SelectedLetterTile(
                          letter: tile['letter']!); // Build your widget here
                    },
                    onReorderFinished: _handleReorderFinished,
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logic for flipping a new tile (call your Flask endpoint)
          _flipNewTile();
        },
        child: const Icon(Icons.refresh_rounded),
      ),
      backgroundColor: Colors.black,
    );
  }
}

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmat;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/widgets/selected_letter_tile.dart';
import 'package:flutter_frontend/widgets/game_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend/widgets/player_words.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/classes/tile.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String username;

  const GameScreen({super.key, required this.gameId, required this.username});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String? currentUserId;

  late DatabaseReference gameRef;
  String currentPlayerTurn = '';
  Map<String, dynamic>? gameData;
  List<Tile> allTiles = [];
  List<Tile> middleTiles = [];
  late int tilesLeftCount;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _blinkController;
  late Animation<double> _blinkOpacityAnimation;
  bool isCurrentUsersTurn = false;
  bool isFlipping = false;

  List<Tile> inputtedLetters = [];
  Set<String> officiallySelectedTileIds = <String>{};
  Set<String> usedTileIds =
      {}; // Track used tile IDs to avoid duplicate assignment
  Set<String> potentiallySelectedTileIds =
      {}; // Set of tileIds that should be semi-transparent

  List<Map<String, dynamic>> playerWords = [];
  List<String> potentialMatches = []; // Possible tiles that match typed input
  Map<String, Color> playerColorMap = {}; // Store player colors
  Map<String, String> playerIdToUsernameMap = {};
  List<Color> playerColors = [
    Color(0xFF1449A2),
    Color(0xFF67bcaf),
    Color(0xFFbe9fc1),
    Color(0xFF2d6164),
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    fetchGameData();

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => isFlipping = false);
      }
    });

    FocusManager.instance.primaryFocus?.unfocus();

    _blinkController = AnimationController(
      vsync: this, // Requires TickerProviderStateMixin
      duration: const Duration(milliseconds: 800), // Speed of one blink cycle
    );

    _blinkOpacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _blinkController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (isCurrentUsersTurn) {
      _blinkController.repeat(reverse: true);
    }
  }

  void _updateTurnState(bool newTurnState) {
    if (!mounted) return;
    setState(() {
      isCurrentUsersTurn = newTurnState;
      if (isCurrentUsersTurn) {
        if (!_blinkController.isAnimating) {
          _blinkController.repeat(reverse: true);
        }
      } else {
        if (_blinkController.isAnimating) {
          _blinkController.stop();
          // Optionally reset opacity to a non-blinking state, e.g., full opacity or invisible
          _blinkController.value = _blinkController
              .upperBound; // Reset to full opacity if needed when stopped
        }
      }
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void clearInput() {
    setState(() {
      inputtedLetters.clear();
      potentiallySelectedTileIds.clear();
      potentialMatches.clear();
      officiallySelectedTileIds.clear();
      usedTileIds.clear();
    });
  }

  void fetchGameData() {
    gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
    gameRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data is LinkedHashMap) {
        setState(() {
          gameData = jsonDecode(jsonEncode(data));
          allTiles = List<Tile>.from(
            (gameData!['tiles'] as List<dynamic>).map((item) {
              return Tile.fromMap(item as Map<String, dynamic>);
            }),
          );
          currentPlayerTurn = gameData?['currentPlayerTurn'] ?? '';
          middleTiles =
              allTiles.where((tile) => tile.location == 'middle').toList();

          tilesLeftCount =
              allTiles.where((tile) => (tile.letter?.isEmpty ?? true)).length;

          // Initialize playerColorMap
          final players = gameData!['players'] as Map<String, dynamic>;
          int colorIndex = 0;
          players.forEach((playerId, playerData) {
            playerColorMap[playerId] =
                playerColors[colorIndex % playerColors.length];
            // print the username
            playerIdToUsernameMap[playerId] = playerData['username'];
            colorIndex++;
          });

          // Ensure gameData contains 'players', 'words', and 'tiles' keys and they are not null
          if (gameData!.containsKey('players') &&
              gameData!['players'] != null &&
              gameData!.containsKey('words') &&
              gameData!['words'] != null &&
              gameData!.containsKey('tiles') &&
              gameData!['tiles'] != null) {
            // Process player words
            playerWords = processPlayerWords(
              Map<String, dynamic>.from(gameData!['players']),
              List<Map<String, dynamic>>.from((gameData!['words'] as List)
                  .map((item) => Map<String, dynamic>.from(item))),
            );

            // Sort playerWords to ensure current player's words are at the bottom
            final String? userId = FirebaseAuth.instance.currentUser?.uid;
            playerWords.sort((a, b) {
              if (a['playerId'] == userId) return 1;
              if (b['playerId'] == userId) return -1;
              return 0;
            });

            // Ensure the current player's words are at the bottom
            playerWords = playerWords
                .where((word) => word['playerId'] != userId)
                .toList()
              ..addAll(playerWords.where((word) => word['playerId'] == userId));

            // Process tiles
            try {
              gameData!['tiles'] = List<Tile>.from(
                (gameData!['tiles'] as List<dynamic>).map((item) {
                  return Tile.fromMap(item as Map<String, dynamic>);
                }),
              );
            } catch (e) {
              print("Error converting tiles: $e");
              gameData!['tiles'] =
                  <Tile>[]; // Initialize as empty list in case of error
            }
          } else {
            // Handle the case where 'players', 'words', or 'tiles' is null
            playerWords = [];
            gameData ??= {}; // Ensure gameData is not null
            gameData!['tiles'] = <Tile>[];
          }
          // Determine the new turn state and update the blink controller
          if (currentUserId != null) {
            _updateTurnState(currentUserId == currentPlayerTurn);
          }

        });
      } else {
        print(
            "Data is not a LinkedHashMap: $data"); // Log if data is not a LinkedHashMap
      }
    });
  }

  List<Map<String, dynamic>> processPlayerWords(
      Map<String, dynamic> players, List<Map<String, dynamic>> words) {
    List<Map<String, dynamic>> playerWords = [];
    players.forEach((playerId, playerData) {
      List<Map<String, dynamic>> playerWordList =
          words.where((word) => word['user_id'] == playerId).toList();
      if (playerWordList.isNotEmpty) {
        playerWords.add({
          'playerId': playerId,
          'username': playerData['username'], // Add username here
          'words': playerWordList,
        });
      }
    });
    return playerWords;
  }

  /// Helper function to find tile location
  String _findTileLocation(dynamic tileId) {
    return allTiles
            .firstWhere(
              (t) => t.tileId == tileId,
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            )
            .location ??
        '';
  }

  Future<void> _sendTileIds() async {
    // Assign locations based on `tileId`
    for (var tile in inputtedLetters) {
      // print type of inputtedLetters tileId
      tile.location = _findTileLocation(tile.tileId);
    }

    print(
        "💚💚💚 Sending tileIds... officiallySelectedTileIds: $officiallySelectedTileIds, inputtedLetters: ${inputtedLetters.map((tile) => {
              'letter': tile.letter,
              'location': tile.location,
              'tileId': tile.tileId
            }).toList()}");

    // Exit early if not enough letters
    if (inputtedLetters.length < 3) return;

    // Convert `tileId` from String to int if needed
    for (var tile in inputtedLetters) {
      if (tile.tileId is String) {
        tile.tileId = int.tryParse(tile.tileId as String) ?? 'invalid';
      }
    }

    // Ensure all tiles come from the same location or include 'middle'
    final distinctLocations =
        inputtedLetters.map((tile) => tile.location).toSet();
    print("Distinct locations of tileIds to submit: $distinctLocations");

    if (distinctLocations.length > 1 && !distinctLocations.contains('middle')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You can't use letters from multiple words")),
      );
      return;
      // if the distinct location from a word is using the ENTIRE word, then throw error
    } else if (distinctLocations.length > 1) {
      // Get the length of the word from the non "middle" location
      final wordId = distinctLocations.firstWhere(
        (location) => location != 'middle' && location != '',
        orElse: () => '',
      );
      print("This is the wordId trying to be stolen/taken: $wordId");
      // get this word out of gameData
      final wordData = (gameData?['words'] as List).firstWhere(
        (word) => word['wordId'] == wordId,
        orElse: () => null,
      );
      final wordLength = wordData['tileIds'].length;
      // if the amount of letters in inputtedLetters with their location = this wordId, does not equal the wordLength, then throw error
      final inputtedLettersFromWord =
          inputtedLetters.where((tile) => tile.location == wordId).toList();
      if (inputtedLettersFromWord.length != wordLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("You must use the entire word or none of it")),
        );
        return;
      }
    }

    // Retrieve user token
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      print('Error: Token is null');
      return;
    }

    try {
      final response =
          await _apiService.sendTileIds(widget.gameId, token, inputtedLetters);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final submissionType = responseData['submission_type'];
        final submittedWord = responseData['word'];

        print("💞 Response Data: $responseData");
        print("💞 Submission Type: $submissionType");

        // Clear input by default
        setState(clearInput);

        // Handle specific response cases
        final errorMessages = {
          "INVALID_LENGTH": "$submittedWord was too short",
          "INVALID_NO_MIDDLE":
              "$submittedWord did not use a letter from the middle",
          "INVALID_WORD_NOT_IN_DICTIONARY":
              "$submittedWord is not in the dictionary"
        };

        if (errorMessages.containsKey(submissionType)) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessages[submissionType]!)));
        }
      } else {
        print(
            'Error sending tileIds: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('HTTP ${response.statusCode} - ${response.body} Error')),
        );
        setState(clearInput);
      }
    } catch (e) {
      print('💞 Error sending tileIds: $e');
    }

    // Ensure UI is updated after processing
    setState(clearInput);
  }

  Future<void> _flipNewTile() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    if (token != null) {
      await _apiService.flipNewTile(widget.gameId, token);
      // set state to update the UI
      setState(() {});
    } else {
      print('Error: Token is null');
    }
  }

  void _syncTileIdsWithInputtedLetters() {
    // 🔄 Create a temporary set to track unique tile assignments
    Set<String> assignedTileIds = {};

    setState(() {
      officiallySelectedTileIds.clear();

      for (var tile in inputtedLetters) {
        if (tile.tileId != 'TBD' && tile.tileId != 'invalid') {
          // Ensure no duplicate assignments for letters appearing multiple times
          if (!assignedTileIds.contains(tile.tileId)) {
            assignedTileIds.add(tile.tileId);
            officiallySelectedTileIds.add(tile.tileId);
          } else {
            // Find an alternative tile ID for this duplicate letter
            final availableTile = allTiles.firstWhere(
              (t) =>
                  t.letter == tile.letter &&
                  !assignedTileIds.contains(t.tileId.toString()),
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );

            if (availableTile.tileId != '') {
              tile.tileId = availableTile.tileId.toString();
              assignedTileIds.add(tile.tileId);
              officiallySelectedTileIds.add(tile.tileId);
            } else {
              print(
                  "❌ No available tile found for duplicate letter: ${tile.letter}");
            }
          }
        }
      }
    });

    print(
        "🔄🔄✅🔄🔄 Inputted Letters (after sync): ${inputtedLetters.map((t) => '${t.letter}: ${t.tileId}').toList()}");

    print(
        "🔄🔄🔄 Fixed Sync: officiallySelectedTileIds = $officiallySelectedTileIds");
  }

  void _handleBackspace() {
    if (inputtedLetters.isNotEmpty) {
      final lastTile = inputtedLetters.removeLast();

      if (lastTile.tileId == "TBD") {
        // 🔹 If the tile was typed, find one matching tile to unhighlight
        final String backspacedLetter = lastTile.letter!;

        setState(() {
          // 🔹 Find the first occurrence of this letter in potentiallySelectedTileIds and remove it
          final highlightedTileIdsList = potentiallySelectedTileIds.toList();
          for (int i = 0; i < highlightedTileIdsList.length;) {
            final tileId = highlightedTileIdsList[i];

            final tile = allTiles.firstWhere(
              (t) =>
                  t.letter == backspacedLetter && t.tileId.toString() == tileId,
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );

            potentiallySelectedTileIds
                .remove(tile.tileId); // ✅ Remove only one occurrence
            break; // ✅ Stop after removing one
          }
        });
      } else {
        // 🔹 If the tile was selected, unselect it
        final tileId = lastTile.tileId!;
        setState(() {
          officiallySelectedTileIds.remove(tileId);
          potentiallySelectedTileIds.remove(tileId);
        });
      }
    }

    setState(() {}); // Force UI refresh
  }

  void handleTileSelection(Tile tile, bool isSelected) {
    print(
        "in handleTileSelection: letter: ${tile.letter}, tileId: ${tile.tileId}, isSelected: $isSelected");
    setState(() {
      if (isSelected) {
        // If the tile is not already selected, add it to the selected tiles
        if (!inputtedLetters
            .any((inputtedTile) => inputtedTile.tileId == tile.tileId)) {
          print("in handleTileSelection: adding tile to inputtedLetters...");
          print("inputtedLetters before: $inputtedLetters");
          print("officiallySelectedTileIds before: $officiallySelectedTileIds");
          officiallySelectedTileIds.add(tile.tileId.toString());

          inputtedLetters.add(tile);
          print("inputtedLetters AFTER: $inputtedLetters");
          print("officiallySelectedTileIds AFTER: $officiallySelectedTileIds");
        }
      } else {
        officiallySelectedTileIds
            .remove(tile.tileId.toString()); // Unmark the tile as selected
        inputtedLetters
            .removeWhere((inputtedTile) => inputtedTile.tileId == tile.tileId);
      }
    });
  }

  List<Tile> _findAvailableTilesWithThisLetter(String letter) {
    // Find all tiles that match this letter that are not already in inputtedLetters and not
    // already in officiallySelectedTileIds or in usedTileIds
    final availableTiles = allTiles.where((tile) {
      return tile.letter == letter &&
          !inputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tile.tileId) &&
          !officiallySelectedTileIds.contains(tile.tileId) &&
          !usedTileIds.contains(tile.tileId);
    }).toList();
    return availableTiles;
  }

  void _assignLetterToThisTileId(letter, tileId) {
    setState(() {
      if (tileId != "TBD" || tileId != "invalid") {
        print(
            "✅ _assignLetterToThisTileId officiallySelectedTileIds before: $officiallySelectedTileIds");
        print("✅ _assignLetterToThisTileId usedTileIds before: $usedTileIds");
        print(
            "✅ _assignLetterToThisTileId inputtedLetters before: ${inputtedLetters.map((tile) => {
                  'letter': tile.letter,
                  'tileId': tile.tileId
                }).toList()}");

        officiallySelectedTileIds.add(tileId);
        print(
            "✅ _assignLetterToThisTileId() (only one option) Assigned tileId $tileId to letter $letter");
        inputtedLetters.removeLast();
        final newTileLocation = allTiles
            .firstWhere(
              (t) => t.tileId.toString() == tileId,
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            )
            .location;
        final newTile =
            Tile(letter: letter, tileId: tileId, location: newTileLocation);
        inputtedLetters.add(newTile);
        // potentiallySelectedTileIds.add(tileId);
        officiallySelectedTileIds.add(tileId);
      } else {
        if (tileId == "invalid") {
          print(
              "❌ _assignLetterToThisTileId() Assigned tileId <$tileId> to letter $letter");
          inputtedLetters.removeLast();
          inputtedLetters
              .add(Tile(letter: letter, tileId: tileId, location: ''));
        }
      }
    });
  }

  void _handleLetterTyped(String letter) {
    print("##################################################################");
    print("######################Typed letter: $letter ######################");
    print("##################################################################");
    setState(() {
      inputtedLetters.add(Tile(letter: letter, tileId: 'TBD', location: ''));
    });

    // Find all tiles that match this letter that are not already in inputtedLetters and not
    // already in officiallySelectedTileIds or in usedTileIds
    final tilesWithThisLetter = _findAvailableTilesWithThisLetter(letter);
    print(
        "Tiles with this letter (found everywhere except inputtedLetters/officiallySelected/usedTileIds):");
    for (var tile in tilesWithThisLetter) {
      print("Tile (${tile.letter}): id: ${tile.tileId} - ${tile.location}");
    }
    // If no tiles match this typed letter
    if (tilesWithThisLetter.isEmpty) {
      print("❌ No tiles found for letter: $letter");
      _assignLetterToThisTileId(letter, "invalid");
      return;
    }
    // if there is only one tile with this letter, assign it to the selected tile
    if (tilesWithThisLetter.length == 1) {
      // tileId has to be tilesWithThisLetter that is not in inputtedLetters
      // and not in officiallySelectedTileIds or usedTileIds
      var tileId = tilesWithThisLetter
          .firstWhere(
            (tile) =>
                !inputtedLetters.any(
                    (inputtedTile) => inputtedTile.tileId == tile.tileId) &&
                !officiallySelectedTileIds.contains(tile.tileId) &&
                !usedTileIds.contains(tile.tileId),
            orElse: () => Tile(letter: '', tileId: 'invalid', location: ''),
          )
          .tileId
          .toString();
      print(
          "🌿✅✅✅✅ Only one tile found for letter $letter:...assignLetterToThisTileId --> tileId = $tileId");
      // print(
      //     "🌿🌿🌿 if there is only one letter option, and it is already in the officiallySelectedTile or inputtedLetters, etc, then it cannot be assigned! must be 'invalid'");
      // If the tileId is already in inputtedLetters or officiallySelectedTileIds, then it cannot be assigned
      if (officiallySelectedTileIds.contains(tileId) ||
          inputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tileId)) {
        tileId = "invalid";
      }
      // final tileId = tilesWithThisLetter.first.tileId.toString();
      _assignLetterToThisTileId(letter, tileId);
    } else {
      // Try to assign tileId since there are multiple options
      _assignTileId(letter, tilesWithThisLetter);
    }
    setState(() {
      potentialMatches =
          tilesWithThisLetter.map((tile) => tile.tileId.toString()).toList();
      // If only one letter has been typed so far
      if (inputtedLetters.length > 1) {
        potentiallySelectedTileIds.addAll(potentialMatches);
        // More than two letters → Start refining
        print(
            "potentiallySelected[highlighted] tile IDs for after typing $letter: $potentiallySelectedTileIds");
        print("More than one letter typed, refining potential matches...");
        _refinePotentialMatches();
      }
    });
  }

  void _assignTileId(String letter, List<Tile> tilesWithThisLetter) {
    for (var tile in tilesWithThisLetter) {
      print(
          "in _assignTileId function: letter = $letter, tilesWithThisLetterTile (${tile.letter}): id: ${tile.tileId} - ${tile.location}");
    }
    // If there is only one tile with this letter, assign it to the selected tile
    if (tilesWithThisLetter.length == 1) {
      final tileId = tilesWithThisLetter.first.tileId.toString();
      setState(() {
        inputtedLetters.removeLast();
        inputtedLetters.add(Tile(letter: letter, tileId: tileId, location: ''));
        potentiallySelectedTileIds.add(tileId);
        officiallySelectedTileIds.add(tileId);
        print("✅ (only one option) Assigned tileId $tileId to letter $letter");
      });
      return;
    }
    // print("in _assignTileId, What are the existing inputtedLetters?: ")
    // 🔍 Collect used tile IDs from selected tiles
    final Set<String> usedTileIds = inputtedLetters
        .where((tile) => tile.tileId != 'TBD')
        .map((tile) => tile.tileId.toString())
        .toSet();

    for (var selectedTile in inputtedLetters) {
      if (selectedTile.tileId == 'TBD' && selectedTile.letter == letter) {
        // 🔍 Prioritize middle tiles that have not been used yet
        final tile = tilesWithThisLetter.firstWhere(
          (tile) =>
              tile.location == 'middle' &&
              !usedTileIds.contains(tile.tileId.toString()),
          orElse: () => Tile(letter: '', tileId: '', location: ''),
        );

        final tileId = tile.tileId?.toString();
        if (tileId != null && tileId != '') {
          setState(() {
            selectedTile.tileId = tileId;
            final location = tile.location;
            usedTileIds.add(tileId);
            officiallySelectedTileIds.add(tileId);
            print(
                "✅ Assigned tileId $tileId from location ($location) to letter $letter");
          });
        } else {
          // If no middle tile is found, assign any available tile that has not been used yet
          final fallbackTile = tilesWithThisLetter.firstWhere(
            (tile) => !usedTileIds.contains(tile.tileId.toString()),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );

          final fallbackTileId = fallbackTile.tileId?.toString();
          if (fallbackTileId != null && fallbackTileId != '') {
            setState(() {
              selectedTile.tileId = fallbackTileId;
              final location = fallbackTile.location;
              usedTileIds.add(fallbackTileId);
              officiallySelectedTileIds.add(fallbackTileId);
              print(
                  "✅ Assigned fallback tileId $fallbackTileId from location ($location) to letter $letter");
            });
          } else {
            print("❌ No available tileId found for letter $letter");
            // Mark this as invalid
            setState(() {
              selectedTile.tileId = 'invalid';
            });
          }
        }
      }
    }
    // get the tile locations of inputtedLetters from allTiles and print the inputtedLetters as tiles
    // print the allTiles where the tileId matches inputtedLetters
    final matchingTiles = allTiles.where((tile) {
      return inputtedLetters.any((inputtedTile) =>
          inputtedTile.tileId.toString() == tile.tileId.toString());
    }).toList();
    print(
        "🔚 End of _assignTileId function, inputtedLetters=: ${matchingTiles.map((tile) => {
              'letter': tile.letter,
              'tileId': tile.tileId,
              'location': tile.location
            }).toList()}");
  }

  void _reassignTilesToMiddle() {
    // Needs to look through the inputtedLetters and find ones that are either invalid or from non-middle locations
    // Then, it should find a matching middle tile and assign it to the selectedTile
    // Needs to make sure that middle tile has not already been assigned (ie its tileId is not in inputtedLetters)
    print("🔍🔍🔍 Start of _reassignTilesToMiddle function");
    final List<Tile> allMiddleTiles =
        allTiles.where((tile) => tile.location == 'middle').toList();
    // print all middleTiles
    print("🔍 All selected tiles: ${inputtedLetters.map((tile) => {
          'letter': tile.letter,
          'tileId': tile.tileId
        }).toList()}");
    // if all the letters are already assigned to middle tiles, return
    // check every single tileId from inputtedLetters and see if the location of that tileId = middle
    if (inputtedLetters.every((tile) {
      final tileId = tile.tileId;
      if (tileId != 'TBD') {
        final tile = allTiles.firstWhere(
          (t) => t.tileId.toString() == tileId,
          orElse: () => Tile(letter: '', tileId: '', location: ''),
        );
        return tile.tileId != '' && tile.location == 'middle';
      }
      return false; // If tileId is TBD, return false
    })) {
      print("🔍☑ All selected tiles are already assigned to middle tiles");
      return;
    }
    setState(() {
      for (var selectedTile in inputtedLetters) {
        print(
            "🔍 Checking selected tile to see if it needs reassignment to a middle tile:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
        // Check each individual selectedTile to see if it is from a non-middle location.
        // If it is, assign it to the middle tile that matches the letter, that hasn't already
        // been assigned to another selectedTile
        if (selectedTile.tileId != 'TBD') {
          // Check if the tile is from a non-middle location and should be replaced
          final assignedTile = allTiles.firstWhere(
            (tile) => tile.tileId.toString() == selectedTile.tileId,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          // if the tile is already from the middle, skip
          if (assignedTile.tileId != '' && assignedTile.location == 'middle') {
            continue;
          }

          print(
              "🔍✅🔍 This tile needs to be reassigned to a middle tile: letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");

          if (assignedTile.tileId != '' && assignedTile.location != 'middle') {
            // Find a middle tile that matches the letter, that is not already in inputtedLetters
            final matchingMiddleTile = allMiddleTiles.firstWhere(
              (middleTile) =>
                  middleTile.letter == selectedTile.letter &&
                  !inputtedLetters.any(
                      (tile) => tile.tileId == middleTile.tileId.toString()),
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );

            print(
                "🔍 Matching middle tile it can be reassigned to: ${matchingMiddleTile.letter}, tileId: ${matchingMiddleTile.tileId}");

            if (matchingMiddleTile.tileId != '') {
              // final tileId = matchingMiddleTile.tileId.toString();
              // _assignLetterToThisTileId(selectedTile.letter, tileId);
              // remove tileId from officiallySelectedTileIds
              officiallySelectedTileIds.remove(selectedTile.tileId);
              selectedTile.tileId = matchingMiddleTile.tileId.toString();
              officiallySelectedTileIds
                  .add(matchingMiddleTile.tileId.toString());
              print(
                  "!!! 💞✅💞 Reassigned tile to be:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
            }
          }
        }
      }
    });

    print(
        "🔚🔚 End of _reassignTilesToMiddle function: ${inputtedLetters.map((tile) => {
              'letter': tile.letter,
              'tileId': tile.tileId
            }).toList()}");
  }

  getWordData(String wordId) {
    // This function should retrieve the word from the gameData based on the wordId
    // Assuming gameData['words'] is a list of words with their respective IDs
    final word = (gameData?['words'] as List).firstWhere(
      (word) => word['wordId'] == wordId,
      orElse: () => null,
    );
    return word;
  }

  void _refinePotentialMatches() {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    print("💼💼💼 Start of _refinePotentialMatches function");

    final String typedWord = inputtedLetters.map((tile) => tile.letter).join();
    final List<String> typedWordLetters =
        typedWord.split(''); // Convert to list for flexible checking

    print("💼 Current typed word: $typedWord");

    final Map<String, List<String>> letterToTileIds = {};

    for (var tile in allTiles) {
      // Ensure the letter is not null or empty before adding
      if (tile.letter != null && tile.letter!.isNotEmpty) {
        letterToTileIds.putIfAbsent(tile.letter!, () => []);
        letterToTileIds[tile.letter!]!.add(tile.tileId.toString());
      }
    }

    debugPrint("🔍 Possible tile matches for each letter: $letterToTileIds");

    final bool allSelectedLettersHaveMiddleMatch =
        inputtedLetters.every((tile) {
      final letter = tile.letter;
      if (letter != null) {
        return allTiles
            .where((t) => t.letter == letter && t.location == 'middle')
            .isNotEmpty;
      }
      return false;
    });

    if (allSelectedLettersHaveMiddleMatch) {
      debugPrint(
          "✅ All selected letters have at least one potential match from the middle");
      _reassignTilesToMiddle();
    } else if (!allSelectedLettersHaveMiddleMatch) {
      print("❌ Not all selected letters have a middle match");

      final matchingWords = (gameData?['words'] as List).where((word) {
        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();

        final String wordString = wordTileIds.map((tileId) {
          return allTiles
              .firstWhere((t) => t.tileId.toString() == tileId,
                  orElse: () => Tile(letter: '', tileId: '', location: ''))
              .letter;
        }).join();

        print("🔍 Checking word: $wordString with tileIds: $wordTileIds");

        // ✅ Check if every letter of the word exists in typedWordLetters (typed letters)
        final bool isContained = wordString
            .split('')
            .every((letter) => typedWordLetters.contains(letter));

        if (!isContained) {
          print("❌ $wordString is NOT contained in $typedWord");
        } else {
          print("✅ $wordString is contained in $typedWord");
        }

        return isContained;
      }).toList();

      print("💀 Found contained matching words: $matchingWords");

      if (matchingWords.isEmpty) {
        print(
            "✅ No full word matches found, and letters are not all from middle tiles");
        // _reassignTilesToMiddle();
      } else {
        print(
            "There are exact matching words. Proceeding to reassign tiles to the longest matching word that does not belong to this user...");
        // If not all selected letters have a middle match, reassign tiles to middle
        // check if there are any full words that can be formed with the current inputted letters
        print("💀 all the words that match: $matchingWords");
        // Sort by the length of the word, longest first
        matchingWords.sort((a, b) => b.length.compareTo(a.length));

        // Find first word that is not owned by this user, and assign its tileIds to the selected tiles
        final matchingWordToUse = matchingWords.firstWhere(
            (word) => word['current_owner_user_id'] != userId,
            orElse: () => matchingWords.first);
        print(
            "💀 matchingWordToUse (the word to steal/take): $matchingWordToUse");
        // Assign the tileIds of the matching word to the selected tiles
        final tileIdsToReassignInputtedLettersToFromMatchingWord =
            matchingWordToUse['tileIds'] as List<dynamic>;
        print("if you make it here...interesting (790)");
        print(
            "💀 tileIds to reassign inputted letters to: $tileIdsToReassignInputtedLettersToFromMatchingWord");
        print("💀 tileIds from matchingWord = ${matchingWordToUse['tileIds']}");
        // create Tile objects from those tileIds
        final matchingTiles =
            tileIdsToReassignInputtedLettersToFromMatchingWord.map((tileId) {
          final tile = allTiles.firstWhere(
            (t) => t.tileId.toString() == tileId.toString(),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          return tile;
        }).toList();

        // reassign the tileIds of the inputtedLetters to those tileIds
        print(
            "💀 calling _reassignTilesToWord with wordId = ${matchingWordToUse['wordId']}");
        _reassignTilesToWord(matchingWordToUse['wordId']);
        print("just called _reassignTilesToWord");
        // for each tileId in tileIdsToReassignInputtedLettersToFromMatchingWord, find the corresponding tile in allTiles
        // and reassign the tileId of the inputtedLetters to that tileId
      }
      _syncTileIdsWithInputtedLetters();
    }

    print("🔚🔚🔚 End of refine function, 🩵 officiallySelectedTileIds = ");
    officiallySelectedTileIds.forEach((tileId) {
      final tile = allTiles.firstWhere(
        (t) => t.tileId.toString() == tileId.toString(),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );
      print(
          "🩵🩵 officiallySelectedTiles tile: ${tile.letter} - ${tile.tileId} - ${tile.location}");
    });
  }

  _reassignTilesToWord(String wordId) {
    print("💀💀💀 Start of _reassignTilesToWord function, wordId = $wordId");
    // This function should reassign the tileIds of the inputtedLetters to the tileIds of the word with the given wordId
    final word = getWordData(wordId);
    if (word == null) {
      print("❌ Word not found for wordId: $wordId");
      return;
    }
    print("💀 Word data for wordId $wordId: $word");
    final List<String> tileIds = (word['tileIds'] as List<dynamic>)
        .map((tileId) => tileId.toString())
        .toList();
    print("maybe this is the problem (str int problem ?)837");
    print("💀 tileIds from word = $tileIds");

    setState(() {
      for (var selectedTile in inputtedLetters) {
        print(
            "🔍_reassignTilesToWord Checking selected tile to see if it needs reassignment to a word tile:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
        if (selectedTile.tileId != 'TBD') {
          final assignedTile = allTiles.firstWhere(
            (tile) => tile.tileId.toString() == selectedTile.tileId,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          if (assignedTile.tileId != '' &&
              tileIds.contains(assignedTile.tileId.toString())) {
            continue;
          }

          print(
              "💀💀💀_reassignTilesToWord This tile needs to be reassigned to a word tile: letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");

          final matchingWordTile = allTiles.firstWhere(
            (tile) =>
                tileIds.contains(tile.tileId.toString()) &&
                tile.letter == selectedTile.letter &&
                !inputtedLetters.any((inputtedTile) =>
                    inputtedTile.tileId == tile.tileId.toString()),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );

          print(
              "💀💀💀_reassignTilesToWord Matching word tile it can be reassigned to: ${matchingWordTile.letter}, tileId: ${matchingWordTile.tileId}");

          if (matchingWordTile.tileId != '') {
            officiallySelectedTileIds.remove(selectedTile.tileId);
            selectedTile.tileId = matchingWordTile.tileId.toString();
            officiallySelectedTileIds.add(matchingWordTile.tileId.toString());
            print(
                "!!! 💀💀💀_reassignTilesToWord Reassigned tile to be:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
          }
        }
      }
    });

    print(
        "💀💀💀 End of _reassignTilesToWord function: ${inputtedLetters.map((tile) => {
              'letter': tile.letter,
              'tileId': tile.tileId
            }).toList()}");
    print(
        "💀🔄💀 Reassigned tileIds of inputtedLetters to those of the word with wordId $wordId: ${inputtedLetters.map((tile) => {
              'letter': tile.letter,
              'tileId': tile.tileId
            }).toList()}");
    _syncTileIdsWithInputtedLetters();
  }

  TextSpan _keyStyle(String key) {
    return TextSpan(
      text: " $key ",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        backgroundColor: Colors.black,
        color: Colors.white,
        fontSize: 20,
        letterSpacing: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    final double tileSize = screenSize.width > 600 ? 40 : 25;
    final isCurrentUsersTurn =
        currentUserId != null && currentUserId == currentPlayerTurn;

    final preRotatedText = Transform.rotate(
      angle: -math.pi / 4,
      child: Text(
        'FLIP',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
    Color getBackgroundColor(Tile tile) {
      switch (tile.tileId) {
        case 'invalid':
          return Colors.red;
        case 'TBD':
          return Colors.yellow;
        case 'valid':
          return const Color(0xFF4A148C);
        default:
          return const Color(0xFF4A148C); // Default color
      }
    }

    return Focus(
      autofocus: true,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          final key = event.logicalKey;
          final isLetter = key.keyLabel.length == 1 &&
              RegExp(r'^[a-zA-Z]$').hasMatch(key.keyLabel);

          if (isLetter && inputtedLetters.length < 16) {
            _handleLetterTyped(key.keyLabel.toUpperCase());
          } else if (key == LogicalKeyboardKey.backspace) {
            _handleBackspace();
          } else if (key == LogicalKeyboardKey.enter) {
            if (inputtedLetters.isNotEmpty) {
              print(
                  "❤️ Submitting selected tiles: inputtedletters = ${inputtedLetters.map((tile) => {
                        'letter': tile.letter,
                        'tileId': tile.tileId
                      }).toList()}");
              _sendTileIds();
            } else {
              _flipNewTile();
            }
          } else if (key == LogicalKeyboardKey.escape) {
            setState(() {
              clearInput();
            });
          }
        }
        return KeyEventResult.handled;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Game ${widget.gameId}"),
          actions: [
            if (MediaQuery.of(context).size.width > 600)
              IconButton(
                icon: Icon(Icons.help_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Game Instructions"),
                        content: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context)
                                .style
                                .copyWith(fontSize: 20, color: Colors.white),
                            children: [
                              TextSpan(text: "Press "),
                              _keyStyle("ESC"),
                              TextSpan(text: " to deselect tiles\nPress "),
                              _keyStyle("Enter"),
                              TextSpan(text: " to submit tiles\nPress "),
                              _keyStyle("Spacebar"),
                              TextSpan(
                                  text:
                                      " to flip a tile\nClick a word to select all its tiles"),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
          ],
        ),
        body: gameData == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Player Words PlayerWords
                      Expanded(
                        child: ListView.builder(
                          itemCount: playerWords.length,
                          itemBuilder: (context, index) {
                            final playerWordData = playerWords[index];
                            final isCurrentPlayerTurn =
                                playerWordData['playerId'] == currentPlayerTurn;
                            final score = gameData?['players']
                                    [playerWordData['playerId']]['score'] ??
                                0;
                            final maxScoreToWin =
                                gameData!['max_score_to_win_per_player'] as int;

                            return PlayerWords(
                              username: playerWordData['username'],
                              playerId: playerWordData['playerId'],
                              words: playerWordData['words'],
                              playerColors: playerColorMap,
                              onClickTile: handleTileSelection,
                              officiallySelectedTileIds:
                                  officiallySelectedTileIds,
                              potentiallySelectedTileIds:
                                  potentiallySelectedTileIds,
                              onClearSelection: () {},
                              allTiles: allTiles,
                              tileSize: tileSize,
                              isCurrentPlayerTurn: isCurrentPlayerTurn,
                              score: score,
                              maxScoreToWin: maxScoreToWin,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tiles & Game Log Row
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gameData?['tiles'] != null
                                        ? 'Tiles ($tilesLeftCount Left):'
                                        : '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  middleTiles.isEmpty
                                      ? Expanded(
                                          child: Text(
                                            "Flip a tile to begin – it's ${playerIdToUsernameMap[currentPlayerTurn]}'s turn to flip a tile!",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white),
                                          ),
                                        )
                                      :

                                      // Tile Grid
                                      Expanded(
                                          child: GridView.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  constraints.maxWidth > 600
                                                      ? 12
                                                      : 8,
                                              childAspectRatio: 1.0,
                                              crossAxisSpacing: 1.0,
                                              mainAxisSpacing: 1.0,
                                            ),
                                            itemCount: middleTiles.length,
                                            itemBuilder: (context, index) {
                                              if (index >= middleTiles.length) {
                                                return Center(
                                                  child: Text(
                                                    "Flip a tile to begin – ${currentPlayerTurn}'s needs to flip a tile!",
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white),
                                                  ),
                                                );
                                              }
                                              final tile = middleTiles[index];
                                              final isSelected =
                                                  officiallySelectedTileIds
                                                      .contains(tile.tileId
                                                          .toString());
                                              final isHighlighted =
                                                  potentiallySelectedTileIds
                                                      .contains(tile.tileId);
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 1.0),
                                                child: TileWidget(
                                                  tile: tile,
                                                  tileSize: tileSize,
                                                  onClickTile:
                                                      (tile, isSelected) {
                                                    setState(() {
                                                      handleTileSelection(
                                                          tile, isSelected);
                                                    });
                                                  },
                                                  isSelected: isSelected,
                                                  backgroundColor: isSelected
                                                      ? Color(0xFF4A148C)
                                                      : isHighlighted
                                                          ? Colors.purple
                                                              .withOpacity(0.25)
                                                          : Colors.purple,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),

                            // Game Log (Only on larger screens)
                            if (constraints.maxWidth > 600)
                              const SizedBox(width: 10),
                            if (constraints.maxWidth > 600)
                              Expanded(
                                flex: 1,
                                child: GameLog(
                                    gameId: widget.gameId,
                                    gameData: gameData!,
                                    playerIdToUsernameMap:
                                        playerIdToUsernameMap,
                                    tileSize: tileSize),
                              ),
                          ],
                        ),
                      ),

                      // Selected Tiles
                      const SizedBox(height: 10),
                      Text(
                        "Selected Tiles:",
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      Wrap(
                        spacing: 4.0,
                        children: inputtedLetters.map((tile) {
                          return SelectedLetterTile(
                            tile: tile,
                            tileSize: tileSize,
                            backgroundColor: getBackgroundColor(tile),
                            onRemove: () {
                              setState(() {
                                _handleBackspace();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  inputtedLetters.clear();

                  usedTileIds.clear();
                  potentiallySelectedTileIds.clear();
                  officiallySelectedTileIds.clear();
                });
              },
              child: const Icon(Icons.clear),
              backgroundColor: Colors.red,
              heroTag: 'clear',
            ),
            const SizedBox(width: 10),
            FloatingActionButton(
              onPressed:
                  inputtedLetters.isNotEmpty || inputtedLetters.length < 3
                      ? _sendTileIds
                      : null,
              child: const Icon(Icons.send_rounded),
              backgroundColor:
                  inputtedLetters.isNotEmpty || inputtedLetters.length < 3
                      ? null
                      : Colors.grey,
              heroTag: 'send',
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _flipAnimation,
              child: preRotatedText,
              builder: (context, animatedChild) {
                final animationValue = _flipAnimation.value;
                final angle =
                    -animationValue * math.pi; // Flips from 0 to -180 degrees
                final isBack = angle.abs() > (math.pi / 2);

                final axis = vmat.Vector3(1, -1, 0).normalized();

                final transformMatrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotate(axis, angle); // Main rotation for the flip

                final Matrix4 unmirrorTransform;
                if (isBack) {
                  // Counter-rotate the child to appear correctly from the "back"
                  unmirrorTransform = Matrix4.identity()..rotate(axis, math.pi);
                } else {
                  unmirrorTransform = Matrix4.identity();
                }

                Color borderColor =
                     const Color.fromARGB(255, 255, 0, 251); // Default active border color
                double borderWidth = 5.0;

                if (isCurrentUsersTurn && _blinkController.isAnimating) {
                  borderColor =
                      borderColor.withOpacity(_blinkOpacityAnimation.value);
                } else if (isCurrentUsersTurn &&
                    !_blinkController.isAnimating) {
                  borderColor = const Color.fromARGB(255, 255, 0, 251);
                }

                return Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: FloatingActionButton(
                    onPressed: isCurrentUsersTurn && !isFlipping
                        ? () {
                            _flipController.forward(from: 0);
                            _flipNewTile();
                          }
                        : null,
                    backgroundColor: isCurrentUsersTurn
                        ? Colors.yellow
                        : Colors.grey.shade400,
                    foregroundColor: Colors.black,
                    heroTag: 'flip',
                    shape: isCurrentUsersTurn
                        ? RoundedRectangleBorder(
                            side: BorderSide(
                              color: borderColor,
                              width: borderWidth,
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                          )
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: unmirrorTransform,
                      child: animatedChild,
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

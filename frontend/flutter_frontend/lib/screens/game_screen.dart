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

class GameScreen extends StatefulWidget {
  final String gameId;
  final String username;

  const GameScreen({super.key, required this.gameId, required this.username});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  final ApiService _apiService = ApiService();
  late DatabaseReference gameRef;
  Map<String, dynamic>? gameData;

  List<Map<String, String>> inputtedLetters = [];
  Set<String> officiallySelectedTileIds = {};
  Set<String> usedTileIds =
      {}; // Track used tile IDs to avoid duplicate assignment
  Set<String> potentiallySelectedTileIds =
      {}; // Set of tileIds that should be semi-transparent

  List<Map<String, dynamic>> playerWords = [];
  List<String> potentialMatches = []; // Possible tiles that match typed input
  Map<String, Color> playerColorMap = {}; // Store player colors
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
    fetchGameData();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  void fetchGameData() {
    gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
    gameRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is LinkedHashMap) {
        setState(() {
          gameData = jsonDecode(jsonEncode(
              data)); // Convert LinkedHashMap to Map<String, dynamic>

          // Ensure gameData contains 'players' and 'words' keys and they are not null
          if (gameData!.containsKey('players') &&
              gameData!['players'] != null &&
              gameData!.containsKey('words') &&
              gameData!['words'] != null) {
            // Initialize playerColorMap
            final players = gameData!['players'] as Map<String, dynamic>;
            int colorIndex = 0;
            players.forEach((playerId, playerData) {
              playerColorMap[playerId] =
                  playerColors[colorIndex % playerColors.length];
              colorIndex++;
            });
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
          } else {
            // Handle the case where 'players' or 'words' is null
            playerWords = [];
          }
        });
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

  Future<void> _sendTileIds() async {
    print(
        "_sendTileIds...the officiallySelectedTileIds and the inputtedLetters should be equal. They are: $officiallySelectedTileIds and $inputtedLetters");

    if (inputtedLetters.isEmpty || inputtedLetters.length < 3) {
      return;
    }
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    if (token != null) {
      try {
        final response = await _apiService.sendTileIds(
            widget.gameId, token, inputtedLetters);
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          setState(() {
            print("Response Data: $responseData");
            final submissionType = responseData['submission_type'];
            final submittedWord = responseData['word'];
            print("Submission Type: $submissionType");
            // by default clear everything
            inputtedLetters.clear();

            usedTileIds.clear();
            potentiallySelectedTileIds.clear();
            officiallySelectedTileIds.clear();

            switch (submissionType) {
              case "INVALID_LENGTH":
                // Put a snackbar that says it is an invalid length (too short or too long)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$submittedWord was too short'),
                  ),
                );
                break;
              case "INVALID_UNKNOWN_WHY":
                break;
              case "INVALID_NO_MIDDLE":
                // Put a snackbar that says it is an invalid length (too short or too long)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '$submittedWord did not use a letter from the middle'),
                  ),
                );
                break;
              case "INVALID_LETTERS_USED":
                break;
              case "INVALID_WORD_NOT_IN_DICTIONARY":
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$submittedWord is not in the dictionary'),
                  ),
                );
                break;
              case "MIDDLE_WORD":
                break;
              case "OWN_WORD_IMPROVEMENT":
                break;
              case "STEAL_WORD":
                break;
              default:
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('HTTP ${response.statusCode} - ${response.body} Error'),
            ),
          );
          inputtedLetters.clear();

          usedTileIds.clear();
          potentiallySelectedTileIds.clear();
          print(
              'Error sending tileIds: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error sending tileIds: $e');
      }
    } else {
      print('Error: Token is null');
    }

    // Clear selected tiles and update UI
    setState(() {
      inputtedLetters.clear();
      potentiallySelectedTileIds.clear();
      potentialMatches.clear();
    });
  }

  Future<void> _flipNewTile() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    if (token != null) {
      await _apiService.flipNewTile(widget.gameId, token);
    } else {
      print('Error: Token is null');
    }
  }

  // This is broken in that if you backspace the highlight doesn't go away
  void _handleBackspace() {
    if (inputtedLetters.isNotEmpty) {
      final lastTile = inputtedLetters.removeLast();

      if (lastTile['tileId'] == "TBD") {
        // 🔹 If the tile was typed, find one matching tile to unhighlight
        final String backspacedLetter = lastTile['letter']!;

        setState(() {
          // 🔹 Find the first occurrence of this letter in potentiallySelectedTileIds and remove it
          final highlightedTileIdsList = potentiallySelectedTileIds.toList();
          for (int i = 0; i < highlightedTileIdsList.length; i++) {
            final tileId = highlightedTileIdsList[i];

            final tile = (gameData?['tiles'] as List).firstWhere(
              (t) => t['tileId'].toString() == tileId,
              orElse: () => {},
            );

            potentiallySelectedTileIds
                .remove(tileId); // ✅ Remove only one occurrence
            break; // ✅ Stop after removing one
          }
        });
      } else {
        // 🔹 If the tile was selected, unselect it
        final tileId = lastTile['tileId']!;
        setState(() {
          officiallySelectedTileIds.remove(tileId);
          potentiallySelectedTileIds.remove(tileId);
        });
      }
    }

    setState(() {}); // Force UI refresh
  }

  void handleTileSelection(String letter, String tileId, bool isSelected) {
    setState(() {
      final tileData = {'letter': letter, 'tileId': tileId};
      if (isSelected) {
        if (!inputtedLetters.any((tile) => tile['tileId'] == tileId)) {
          officiallySelectedTileIds.add(tileId);
          inputtedLetters.add(tileData);
        }
      } else {
        officiallySelectedTileIds.remove(tileId); // Unmark the tile as selected
        inputtedLetters.removeWhere((tile) => tile['tileId'] == tileId);
      }
    });
  }

  void _handleLetterTyped(String letter) {
    print("##################################################################");
    print("######################Typed letter: $letter ######################");
    print("##################################################################");
    setState(() {
      inputtedLetters.add({'letter': letter, 'tileId': 'TBD'});
    });

    // Find all tiles that match this letter that are not already in inputtedLetters and not
    // already in officiallySelectedTileIds or in usedTileIds
    final tilesWithThisLetter = (gameData?['tiles'] as List)
        .where((tile) => tile['letter'] == letter)
        .where((tile) => !inputtedLetters
            .any((inputtedTile) => inputtedTile['tileId'] == tile['tileId']))
        .where((tile) => !officiallySelectedTileIds.contains(tile['tileId']))
        .where((tile) => !usedTileIds.contains(tile['tileId']))
        .toList();
    print(
        "Tiles with this letter (found everywhere except inputtedLetters/officiallySelected/usedTileIds): $tilesWithThisLetter");

    // Assign tileId if possible
    _assignTileId(letter, tilesWithThisLetter);

    // If there are no words in the game yet, just choose the first tile that matches the letter
    if (gameData == null ||
        gameData?['words'] == null ||
        gameData?['words'].isEmpty) {
      final tileId = tilesWithThisLetter.first['tileId'].toString();
      setState(() {
        inputtedLetters.removeLast();
        inputtedLetters.add({'letter': letter, 'tileId': tileId});
        potentiallySelectedTileIds.add(tileId);
        print("Marked last tile as valid: $inputtedLetters");
      });
    }

    // If no tiles match this typed letter
    if (tilesWithThisLetter.isEmpty) {
      print("❌ No tiles found for letter: $letter");

      if (inputtedLetters.isNotEmpty) {
        final lastTile = inputtedLetters.last;
        if (lastTile['tileId'] != 'invalid') {
          setState(() {
            inputtedLetters.removeLast();
            inputtedLetters.add({'letter': letter, 'tileId': 'invalid'});
            print("Marked last tile as invalid: $inputtedLetters");
          });
        }
      }
    }

    setState(() {
      // If only one letter has been typed so far
      if (inputtedLetters.length == 1) {
        // First letter: Highlight all matching tiles
        potentialMatches = tilesWithThisLetter
            .map((tile) => tile['tileId'].toString())
            .toList();
        potentiallySelectedTileIds.addAll(potentialMatches);
        print("First letter typed, potential matches: $potentialMatches");
        print(
            "potentiallySelected[highlighted] tile IDs: $potentiallySelectedTileIds");
      } else {
        potentialMatches = tilesWithThisLetter
            .map((tile) => tile['tileId'].toString())
            .toList();
        potentiallySelectedTileIds.addAll(potentialMatches);
        // More than two letters → Start refining
        print("More than one letter typed, refining potential matches...");
        _refinePotentialMatches();
      }
    });
    if (potentialMatches.length > 1) {
      print("_handleLetterTyped potentialMatches: $potentialMatches");
    }
    if (potentiallySelectedTileIds.length > 1) {
      print(
          "Letters that should be potentiallySelected[highlighted]: $potentiallySelectedTileIds");
    }
  }

  void _assignTileId(String letter, List<dynamic> tilesWithThisLetter) {
    // If there is only one tile with this letter, assign it to the selected tile
    if (tilesWithThisLetter.length == 1) {
      final tileId = tilesWithThisLetter.first['tileId'].toString();
      setState(() {
        inputtedLetters.removeLast();
        inputtedLetters.add({'letter': letter, 'tileId': tileId});
        potentiallySelectedTileIds.add(tileId);
        officiallySelectedTileIds.add(tileId);
        print("✅ (only one option) Assigned tileId $tileId to letter $letter");
      });
      return;
    }
    // 🔍 Collect used tile IDs from selected tiles
    final Set<String> usedTileIds = inputtedLetters
        .where((tile) => tile['tileId'] != 'TBD')
        .map((tile) => tile['tileId'].toString())
        .toSet();

    for (var selectedTile in inputtedLetters) {
      if (selectedTile['tileId'] == 'TBD' && selectedTile['letter'] == letter) {
        // 🔍 Prioritize tiles that have not been used yet
        final tile = tilesWithThisLetter.firstWhere(
          (tile) => !usedTileIds.contains(tile['tileId'].toString()),
          orElse: () => {},
        );

        final tileId = tile['tileId']?.toString();
        if (tileId != null) {
          setState(() {
            selectedTile['tileId'] = tileId;
            final location = tile['location'];
            usedTileIds.add(tileId);
            // officiallySelectedTileIds.add(tileId);
            print(
                "✅ Assigned tileId $tileId from location ($location) to letter $letter");
          });
        } else {
          print("❌ No available tileId found for letter $letter");
          // Mark this as invalid
          setState(() {
            selectedTile['tileId'] = 'invalid';
          });
        }
      }
    }
    print("🔚 End of _assignTileId function: $inputtedLetters");
  }

  void _reassignTilesToMiddle() {
    // Needs to look through the inputtedLetters and find ones that are either invalid or from non-middle locations
    // Then, it should find a matching middle tile and assign it to the selectedTile
    // Needs to make sure that middle tile has not already been assigned (ie its tileId is not in inputtedLetters)
    final List<Map<String, dynamic>> allMiddleTiles =
        (gameData?['tiles'] as List)
            .where((tile) => tile['location'] == 'middle')
            .map((tile) => tile as Map<String, dynamic>)
            .toList();
    print("🔍🔍 All middle tiles: $allMiddleTiles");
    print("🔍 All selected tiles: $inputtedLetters");
    // if all the letters are already assigned to middle tiles, return
    // check every single tileId from inputtedLetters and see if the location of that tileId = middle
    if (inputtedLetters.every((tile) {
      final tileId = tile['tileId'];
      if (tileId != 'TBD') {
        final tile = (gameData?['tiles'] as List).firstWhere(
          (t) => t['tileId'].toString() == tileId,
          orElse: () => {},
        );
        return tile.isNotEmpty && tile['location'] == 'middle';
      }
      return false; // If tileId is TBD, return false
    })) {
      print("🔍☑ All selected tiles are already assigned to middle tiles");
      return;
    }
    setState(() {
      for (var selectedTile in inputtedLetters) {
        print(
            "🔍 Checking selected tile to see if it needs reassignment to a middle tile: $selectedTile");
        // Check each individual selectedTile to see if it is from a non-middle location.
        // If it is, assign it to the middle tile that matches the letter, that hasn't already
        // been assigned to another selectedTile
        if (selectedTile['tileId'] != 'TBD') {
          // Check if the tile is from a non-middle location and should be replaced
          final assignedTile = (gameData?['tiles'] as List).firstWhere(
            (tile) => tile['tileId'].toString() == selectedTile['tileId'],
            orElse: () => {},
          );
          // if the tile is already from the middle, skip
          if (assignedTile.isNotEmpty && assignedTile['location'] == 'middle') {
            continue;
          }

          print(
              "🔍✅🔍 This tile needs to be reassigned to a middle tile: $selectedTile");

          if (assignedTile.isNotEmpty && assignedTile['location'] != 'middle') {
            // Find a middle tile that matches the letter, that is not already in inputtedLetters
            final matchingMiddleTile = allMiddleTiles.firstWhere(
              (middleTile) =>
                  middleTile['letter'] == selectedTile['letter'] &&
                  !inputtedLetters.any((tile) =>
                      tile['tileId'] == middleTile['tileId'].toString()),
              orElse: () => {},
            );

            print(
                "🔍 Matching middle tile it can be reassigned to: $matchingMiddleTile");

            if (matchingMiddleTile.isNotEmpty) {
              selectedTile['tileId'] = matchingMiddleTile['tileId'].toString();
              print("!!! 💞✅💞 Reassigned tile to be: $selectedTile");
            }
          }
        }
      }
    });

    print("🔚🔚 End of _reassignTilesToMiddle function: $inputtedLetters");
  }

  void _refinePotentialMatches() {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    // 0. Check if any inputtedLetters have tileId set to 'TBD'
    if (!inputtedLetters.any((tile) => tile['tileId'] == 'TBD')) {
      debugPrint(
          "🔚 there are no TBD tiles? refine function: $inputtedLetters");
      print("💼 No TBD tiles to refine.");
    }

    final String currentTypedWord =
        inputtedLetters.map((tile) => tile['letter']).join();
    print("💼 Current typed word: $currentTypedWord");

    final Map<String, List<String>> letterToTileIds = {};

    for (var tile in inputtedLetters) {
      final letter = tile['letter'];
      if (letter != null) {
        final matchingTiles = (gameData?['tiles'] as List)
            .where((t) => t['letter'] == letter)
            .map((t) => t['tileId'].toString())
            .toList();
        letterToTileIds[letter] = matchingTiles;
      }
    }

    debugPrint("🔍 Possible tile matches for each letter: $letterToTileIds");

    // 1. Check if every selected letter has at least one potential match from the middle
    final bool allSelectedLettersHaveMiddleMatch =
        inputtedLetters.every((tile) {
      final letter = tile['letter'];
      if (letter != null) {
        final middleMatchingTiles = (gameData?['tiles'] as List)
            .where((t) => t['letter'] == letter && t['location'] == 'middle')
            .toList();
        return middleMatchingTiles.isNotEmpty;
      }
      return false; // If letter is null, return false
    });

    if (allSelectedLettersHaveMiddleMatch) {
      debugPrint(
          "✅ All selected letters have at least one potential match from the middle");

      // Find full-word matches within the potential tile matches
      final matchingWords = (gameData?['words'] as List).where((word) {
        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
        final String wordString = wordTileIds.map((tileId) {
          return (gameData?['tiles'] as List).firstWhere(
              (t) => t['tileId'].toString() == tileId,
              orElse: () => {'letter': ''})['letter'];
        }).join();

        bool wordIsFullyContained = wordString.split('').every((letter) {
          return letterToTileIds.containsKey(letter) &&
              letterToTileIds[letter]!.isNotEmpty;
        });

        debugPrint(
            "allSelectedLettersHaveMiddleMatch 🔚🔚🔚 End of refine function, inputtedLetters: $inputtedLetters");
        return wordIsFullyContained;
      }).toList();
      // if matchingWords.isEmpty AND the letters are not all already assigned tileIds from the middle
      if (matchingWords.isEmpty) {
        print("✅ No full word matches found, assigning from middle tiles");
        _reassignTilesToMiddle();
      } else {
        matchingWords.forEach((word) {
          print(
              "✅✅ Matching word: ${word['word']} with tileIds: ${word['tileIds']}");
        });

        final Set<String> matchingWordTileIds = matchingWords
            .expand((word) =>
                (word['tileIds'] as List<dynamic>).map((id) => id.toString()))
            .toSet();

        setState(() {
          potentiallySelectedTileIds
              .retainWhere((tileId) => matchingWordTileIds.contains(tileId));

          for (var selectedTile in inputtedLetters) {
            // If the tileId is still 'TBD', or it is not assigned a tileId with the wordId of the matchingWord,
            // then assign it to the first tileId that matches the letter from that word, if it is not already
            // assigned to another selectedTile (ie its tileId is not in inputtedLetters)
            if (selectedTile['tileId'] == 'TBD' ||
                !matchingWordTileIds.contains(selectedTile['tileId'])) {
              final matchingTileId = matchingWordTileIds.firstWhere(
                (tileId) {
                  final tile = (gameData?['tiles'] as List).firstWhere(
                    (t) => t['tileId'].toString() == tileId,
                    orElse: () => {},
                  );
                  return tile['letter'] == selectedTile['letter'];
                },
                orElse: () => 'TBD',
              );
              if (matchingTileId != 'TBD') {
                print("Matching tileId found: $matchingTileId");
                selectedTile['tileId'] = matchingTileId;
                potentiallySelectedTileIds.remove(matchingTileId);
              } else if (matchingTileId == 'TBD') {
                // Look through middle tiles to assign this tile to
                final matchingMiddleTile =
                    (gameData?['tiles'] as List).firstWhere(
                  (t) =>
                      t['location'] == 'middle' &&
                      t['letter'] == selectedTile['letter'],
                  orElse: () => {},
                );
                if (matchingMiddleTile.isNotEmpty) {
                  selectedTile['tileId'] =
                      matchingMiddleTile['tileId'].toString();
                  potentiallySelectedTileIds
                      .remove(matchingMiddleTile['tileId'].toString());
                  print(
                      "Assigned middle tileId ${matchingMiddleTile['tileId']} to selectedTile: $selectedTile");
                } else {
                  print("No middle tile found for selectedTile: $selectedTile");
                  // Set the tileId to TBD? Or just leave it as is?
                }
              }
            }
          }
        });

        print("✅ Full-word matches found and processed.");
      }
    } else {
      // 2. Find full-word matches within the potential tile matches
      final matchingWords = (gameData?['words'] as List).where((word) {
        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
        final String wordString = wordTileIds.map((tileId) {
          return (gameData?['tiles'] as List).firstWhere(
              (t) => t['tileId'].toString() == tileId,
              orElse: () => {'letter': ''})['letter'];
        }).join();

        bool wordIsFullyContained = wordString.split('').every((letter) {
          return letterToTileIds.containsKey(letter) &&
              letterToTileIds[letter]!.isNotEmpty;
        });

        debugPrint("🔚 End of refine function: $inputtedLetters");
        return wordIsFullyContained;
      }).toList();
      // If there are matching words from the user's input
      if (matchingWords.isNotEmpty) {
        matchingWords.forEach((word) {
          print(
              "✅✅ Matching word: ${word['word']} with tileIds: ${word['tileIds']}");
        });
        // If there is a matching word, assign the inputtedLetters to the first matching
        // word that is owned by another player
        // Else any word will work
        final matchingWord = matchingWords.firstWhere(
          (word) => word['current_owner_user_id'] != userId,
          orElse: () => matchingWords.first,
        );

        if (matchingWord.isNotEmpty) {
          final matchingWordTileIds = (matchingWord['tileIds'] as List<dynamic>)
              .map((id) => id.toString())
              .toSet();

          print("🔍 Matching word tile IDs: $matchingWordTileIds");
          // Only keep potentiallySelected[highlighted] the tiles that are part of the matching word
          setState(() {
            potentiallySelectedTileIds
                .retainWhere((tileId) => matchingWordTileIds.contains(tileId));
            print(
                "🔍 potentiallySelected[highlighted] tile IDs after retain: $potentiallySelectedTileIds");

            // Make sure each letter in the typed out word is assigned to a tileId from the matching word
            for (var selectedTile in inputtedLetters) {
              // initialize a list of tiles that are assigned so if a duplicate letter comes up we do not reuse the same tileid
              List<String> assignedTiles = [];
              // Assign the tileId from the matching word to the selectedTile
              print("🔍 Processing selected tile: $selectedTile");
              // get location of that tileId and make sure it matches the matchingWord's wordId
              final selectedTileId = selectedTile['tileId'];
              final selectedTileData = (gameData?['tiles'] as List).firstWhere(
                (t) => t['tileId'].toString() == selectedTileId,
                orElse: () => {},
              );
              final selectedTileLocation = selectedTileData['location'];
              final matchingWordWordId = matchingWord['wordId'];
              if (selectedTileLocation == matchingWordWordId) {
                print(
                    "✅ Selected tile is from the matching word, no need to reassign: $selectedTile");
                if (selectedTileId != null) {
                  assignedTiles.add(selectedTileId);
                }
                continue;
              }
              // Find the first tileId in the matching word that matches the letter of the selectedTile
              // That is not also in the assignedTiles list
              final matchingTileIdInMatchingWord =
                  matchingWordTileIds.firstWhere(
                (tileId) {
                  final tile = (gameData?['tiles'] as List).firstWhere(
                    (t) => t['tileId'].toString() == tileId,
                    orElse: () => {},
                  );
                  return tile['letter'] == selectedTile['letter'] &&
                      !officiallySelectedTileIds.contains(tileId);
                },
                orElse: () => 'TBD',
              );
              // If a matching tileId is found, assign it to the selectedTile
              if (matchingTileIdInMatchingWord != 'TBD' &&
                  !assignedTiles.contains(matchingTileIdInMatchingWord)) {
                selectedTile['tileId'] = matchingTileIdInMatchingWord;
                assignedTiles.add(matchingTileIdInMatchingWord);
                potentiallySelectedTileIds.remove(matchingTileIdInMatchingWord);
                officiallySelectedTileIds.add(matchingTileIdInMatchingWord);
                print(
                    "🔄 Assigned matching tileId $matchingTileIdInMatchingWord to selectedTile: $selectedTile");
              } else {
                // if assignedTiles is empty yet the entire word before this tile is a match, then we add all those tileIds to assignedTiles
                if (assignedTiles.isEmpty) {
                  assignedTiles.addAll(matchingWordTileIds);
                }
                print("🔍🔍🔍 Already assigned tiles: $assignedTiles");
                print(
                    "🔍 Matching tileId in matching word: $matchingTileIdInMatchingWord");

                print(
                    "❌ No matching tileId found for selectedTile: $selectedTile, need to check the middle tiles to assign from there!");
                // Look through middle tiles to assign this tile to
                final matchingMiddleTile =
                    (gameData?['tiles'] as List).firstWhere(
                  (t) =>
                      t['location'] == 'middle' &&
                      t['letter'] == selectedTile['letter'],
                  orElse: () => {},
                );
                if (matchingMiddleTile.isNotEmpty) {
                  selectedTile['tileId'] =
                      matchingMiddleTile['tileId'].toString();
                  potentiallySelectedTileIds
                      .remove(matchingMiddleTile['tileId'].toString());
                  officiallySelectedTileIds
                      .add(matchingMiddleTile['tileId'].toString());
                  print(
                      "729 Assigned middle tileId ${matchingMiddleTile['tileId']} to selectedTile: $selectedTile");
                } else {
                  print("No middle tile found for selectedTile: $selectedTile");
                  // Set the tileId to TBD? Or just leave it as is?
                }
              }
            }
          });
          print("✅ Full-word matches found and processed.");
        } else {
          print("❌ No full-word matches found within the potential tiles.");
        }
        print("✅ Full-word matches found and processed.");
      } else {
        print("❌ No full-word matches found within the potential tiles.");
      }
    }
    debugPrint("🔚🔚🔚🔚🔚 End of refine function: $inputtedLetters");
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
    Color getBackgroundColor(tile) {
      switch (tile['tileId']) {
        case 'invalid':
          return Colors.red;
        case 'TBD':
          return Colors.yellow; // Or your desired determining color
        case 'valid':
          return const Color(0xFF4A148C);
        default:
          return const Color(0xFF4A148C); // Default color
      }
    }

    final allTiles = gameData?['tiles'] is List<dynamic>
        ? List<Map<String, dynamic>>.from(
            gameData!['tiles'].whereType<Map>().toList(),
          )
        : [];
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
              print("Submitting selected tiles: $inputtedLetters");
              _sendTileIds();
            } else {
              _flipNewTile();
            }
          } else if (key == LogicalKeyboardKey.escape) {
            setState(() {
              inputtedLetters.clear();

              usedTileIds.clear();
              potentiallySelectedTileIds.clear();
              officiallySelectedTileIds.clear();
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
                                playerWordData['playerId'] ==
                                    gameData?['currentPlayerTurn'];
                            final score = gameData?['players']
                                    [playerWordData['playerId']]['score'] ??
                                0;
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
                              allTiles:
                                  List<Map<String, dynamic>>.from(allTiles),
                              tileSize: tileSize,
                              isCurrentPlayerTurn: isCurrentPlayerTurn,
                              score: score,
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
                                    gameData?['tiles'] != null ? "Tiles:" : "",
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                  const SizedBox(height: 5),

                                  // Tile Grid
                                  Expanded(
                                    child: GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            constraints.maxWidth > 600 ? 12 : 8,
                                        childAspectRatio: 1.0,
                                        crossAxisSpacing: 1.0,
                                        mainAxisSpacing: 1.0,
                                      ),
                                      itemCount: (gameData?['tiles'] as List?)
                                              ?.where((tile) =>
                                                  tile != null &&
                                                  tile is Map &&
                                                  tile['location'] ==
                                                      'middle' &&
                                                  (tile['letter'] as String?)
                                                          ?.isNotEmpty ==
                                                      true)
                                              .length ??
                                          0,
                                      itemBuilder: (context, index) {
                                        final tiles = (gameData?['tiles']
                                                as List?)
                                            ?.where((tile) =>
                                                tile != null &&
                                                tile is Map &&
                                                tile['location'] == 'middle' &&
                                                (tile['letter'] as String?)
                                                        ?.isNotEmpty ==
                                                    true)
                                            .toList();

                                        if (tiles == null ||
                                            index >= tiles.length) {
                                          return const SizedBox.shrink();
                                        }

                                        final tile = tiles[index]
                                            as Map<dynamic, dynamic>?;
                                        final letter =
                                            tile?['letter'] as String? ?? "";
                                        final tileId =
                                            tile?['tileId']?.toString() ?? "";

                                        final isSelected =
                                            officiallySelectedTileIds
                                                .contains(tileId);
                                        final isHighlighted =
                                            potentiallySelectedTileIds
                                                .contains(tileId);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 1.0),
                                          child: TileWidget(
                                            letter: letter,
                                            tileId: tileId,
                                            tileSize: tileSize,
                                            onClickTile: (selectedLetter,
                                                tileId, isSelected) {
                                              setState(() {
                                                handleTileSelection(
                                                    selectedLetter,
                                                    tileId,
                                                    isSelected);
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
                                    gameId: widget.gameId, tileSize: tileSize),
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
                            letter: tile['letter']!,
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
            FloatingActionButton(
              onPressed: _flipNewTile,
              child: const Icon(Icons.refresh_rounded),
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              heroTag: 'flip',
            ),
          ],
        ),
      ),
    );
  }
}

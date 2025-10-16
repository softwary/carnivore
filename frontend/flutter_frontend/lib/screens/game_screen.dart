import 'dart:async';
import 'dart:math';
import 'package:flutter_frontend/services/overlay_notification_service.dart';
import 'package:flutter_frontend/widgets/dialogs/update_username_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/widgets/mobile_game_log_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_frontend/widgets/game_actions_fab.dart';
import 'package:flutter_frontend/widgets/game_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend/widgets/player_words.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/classes/game_data_provider.dart';
import 'package:flutter_frontend/animations/steal_animation.dart';
import 'package:flutter_frontend/widgets/middle_tiles_grid_widget.dart';
import 'package:flutter_frontend/widgets/dialogs/game_instructions_dialog_content.dart';
import 'package:flutter_frontend/widgets/dialogs/login_signup_dialog.dart';
import 'package:flutter_frontend/widgets/selected_tiles_display.dart';
import 'package:flutter_frontend/controllers/game_auth_controller.dart';
import 'package:flutter_frontend/controllers/game_controller.dart';
import 'package:flutter_frontend/widgets/territory_bar.dart';
import 'package:flutter_frontend/widgets/mobile_keyboard.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String? username;

  const GameScreen({super.key, required this.gameId, required this.username});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin, StealAnimationMixin {
  final currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _previousGameData;
  final Map<String, GlobalKey> tileGlobalKeys = {};
  final Map<String, Offset> previousTileGlobalPositions = {};
  final Map<String, Size> previousTileSizes = {};

  final Set<String> sourceWordIdsForAnimation = {};
  final Set<String> destinationWordIdsForAnimation = {};
  final Set<String> animatingWordIds = {};

  String? currentUserId;
  String _currentPlayerUsername = "Loading...";
  bool _hasRequestedJoin = false;

  String? _mobileLogMessage;
  bool _isKeyboardVisible = false;

  String currentPlayerTurn = '';
  List<Tile> allTiles = [];
  List<Tile> middleTiles = [];
  late int tilesLeftCount;

  bool isCurrentUsersTurn = false;
  bool isFlipping = false;

  List<Map<String, dynamic>> playerWords = [];
  List<String> potentialMatches = []; // Possible tiles that match typed input
  Map<String, Color> playerColorMap = {}; // Store player colors
  Map<String, String> playerIdToUsernameMap = {};
  List<Color> playerColors = [
    Color.fromARGB(255, 195, 92, 204),
    Color(0xFF67bcaf),
    Color(0xFF1449A2),
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
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _updateTurnState(bool newTurnState) {
    if (!mounted) return;
    setState(() {
      isCurrentUsersTurn = newTurnState;
    });
  }

  List<Map<String, dynamic>> processPlayerWords(
      Map<String, dynamic> players, List<Map<String, dynamic>> words) {
    List<Map<String, dynamic>> processedPlayerWords = [];

    players.forEach((playerId, playerData) {
      // Ensure playerData is a map before trying to access its properties
      if (playerData is Map<String, dynamic>) {
        processedPlayerWords.add({
          'playerId': playerId, // Make sure playerId is included
          'username': playerData['username'] as String? ??
              'Unknown', // Safely access username
          'words': <Map<String, dynamic>>[],
        });
      }
    });

    // Create a map for quick lookup of player index
    final playerIndexMap = <String, int>{};
    for (int i = 0; i < processedPlayerWords.length; i++) {
      playerIndexMap[processedPlayerWords[i]['playerId']] = i;
    }

    // Add destination words (as placeholders) from current data
    for (var currentWord in words) {
      final wordId = currentWord['wordId'] as String;
      final ownerId = currentWord['current_owner_user_id'] as String;
      final status = (currentWord['status'] as String? ?? '').toLowerCase();

      if (!status.contains("valid")) continue;

      if (destinationWordIdsForAnimation.contains(wordId)) {
        final playerEntry = processedPlayerWords
            .firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
        if (playerEntry.isNotEmpty) {
          final placeholderWord = Map<String, dynamic>.from(currentWord);
          placeholderWord['isAnimatingDestinationPlaceholder'] = true;
          (playerEntry['words'] as List<Map<String, dynamic>>)
              .add(placeholderWord);
        }
      } else if (!sourceWordIdsForAnimation.contains(wordId)) {
        // If it's not a destination and not a source (which are handled from prevData),
        // then it's a normal current word.
        final playerEntry = processedPlayerWords
            .firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
        if (playerEntry.isNotEmpty) {
          (playerEntry['words'] as List<Map<String, dynamic>>).add(currentWord);
        }
      }
    }

    // Add source words from previous data
    if (_previousGameData != null) {
      final prevWordsList =
          (_previousGameData!['words'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      for (var prevWord in prevWordsList) {
        final prevWordId = prevWord['wordId'] as String;
        final prevOwnerId = prevWord['current_owner_user_id'] as String;
        final prevStatus = (prevWord['status'] as String? ?? '').toLowerCase();

        if (!prevStatus.contains("valid")) continue;

        if (sourceWordIdsForAnimation.contains(prevWordId)) {
          final playerEntry = processedPlayerWords.firstWhere(
              (p) => p['playerId'] == prevOwnerId,
              orElse: () => {});
          if (playerEntry.isNotEmpty) {
            (playerEntry['words'] as List<Map<String, dynamic>>).add(prevWord);
          }
        }
      }
    }
    return processedPlayerWords;
  }

  // Helper to generate messages for the mobile overlay
  String _getLogMessageForOverlay(Map<String, dynamic> log) {
    final username = playerIdToUsernameMap[log['playerId']] ?? 'Someone';
    final String actionType = log['type'] as String? ?? "Unknown Type";
    final String? word = log['word'] as String?; // Word string from the action
    final String? tileLetter = log['tileLetter'] as String?; // For flip_tile
    print("💚originalWordString: ${log['originalWordString']}");
    switch (actionType) {
      case 'flip_tile':
        String article = "a";
        if (['A', 'E', 'F', 'H', 'I', 'L', 'M', 'N', 'O', 'R', 'S', 'X']
            .contains(tileLetter?.toUpperCase())) {
          article = "an";
        }
        return "$username flipped $article ${tileLetter ?? 'tile'}";
      case 'MIDDLE_WORD':
        return "$username created '${word ?? 'a word'}' from the middle!";
      case 'OWN_WORD_IMPROVEMENT':
        final originalWord = log['originalWordString'] as String?;
        return "$username improved '${originalWord ?? 'their word'}' to '${word ?? 'a new word'}'!";
      case 'STEAL_WORD':
        final robbedId = log['robbedUserId'] as String;
        final robbedName = playerIdToUsernameMap[robbedId] ?? robbedId;
        final stolenWord = log['originalWordString'] as String?;
        return "$username stole '${stolenWord ?? 'a word'}' from $robbedName!";
      default: // Covers all INVALID types and unknown
        return "$username: '${word ?? 'Word'}' invalid ($actionType)";
    }
  }

  String _findTileLocation(dynamic tileId) {
    if (tileId == null) return '';
    try {
      return allTiles
              .firstWhere((t) => t.tileId.toString() == tileId.toString())
              .location ??
          '';
    } catch (e) {
      return '';
    }
  }

  Future<void> _submitWord(Map<String, dynamic> gameData) async {
    final gameController =
        ref.read(gameControllerProvider(widget.gameId).notifier);
    final gameControllerState = ref.read(gameControllerProvider(widget.gameId));

    // Client-side length check
    if (gameControllerState.inputtedLetters.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Word must be at least 3 letters long.")),
      );
      return;
    }

    // Client-side validation for tile locations
    // This uses _findTileLocation which relies on `allTiles` processed in GameScreenState
    final distinctLocations = gameControllerState.inputtedLetters
        .map((tile) => _findTileLocation(tile.tileId))
        .toSet();

    if (distinctLocations.length > 1 && !distinctLocations.contains('middle')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "You can only steal from one player at a time, and you must use at least one tile from the middle."),
        ),
      );
      return;
    } else if (distinctLocations.length > 1) {
      // This logic assumes one of the locations is a wordId from an existing word.
      final wordIdLocation = distinctLocations.firstWhere(
        (loc) => loc != 'middle' && loc.isNotEmpty,
        orElse: () => '', // Default to empty string if no such location found
      );

      if (wordIdLocation.isNotEmpty) {
        // Find the word data from gameData
        final wordsList = gameData['words'] as List<dynamic>?;
        final wordDataMap = wordsList?.firstWhere(
          (word) => word is Map && word['wordId'] == wordIdLocation,
          orElse: () => null, // Return null if not found
        ) as Map<String, dynamic>?;

        if (wordDataMap != null) {
          final wordTileIds = wordDataMap['tileIds'] as List<dynamic>? ?? [];
          final wordLength = wordTileIds.length;

          final inputtedLettersFromWord = gameControllerState.inputtedLetters
              .where((tile) => _findTileLocation(tile.tileId) == wordIdLocation)
              .length;

          if (inputtedLettersFromWord != wordLength) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "You must use the entire word or none of it when stealing.")),
            );
            return;
          }
        } else {
          // This case means a location was found that isn't 'middle' but doesn't match a wordId.
          // This could be an error or an edge case not fully handled.
          // For now, we'll let it pass to the controller, which might have more robust validation.
        }
      }
    }

    // Call the controller to handle the submission
    try {
      final result = await gameController.submitCurrentWord();

      if (result['success'] == true) {
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                result['message'] as String? ?? 'Failed to submit word.')));
      }
    } catch (e) {
      // Catch any unexpected errors from the controller call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: ${e.toString()}')),
      );
    }
  }

  Future<void> _flipNewTile() async {
    // This is called when Enter is pressed with no selected tiles
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    if (token != null) {
      final result = await ApiService().flipNewTile(widget.gameId, token);

      // Check for no tiles left condition
      if (result['success'] == false && result['reason'] == 'no_tiles_left') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No more tiles left in the game! Try stealing words from other players.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      setState(() {
        isFlipping = false;
      });
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    final asyncGameData = ref.watch(gameDataProvider(widget.gameId));
    final authState = ref.watch(gameAuthControllerProvider);

    final gameControllerState =
        ref.watch(gameControllerProvider(widget.gameId));
    final gameController =
        ref.read(gameControllerProvider(widget.gameId).notifier);
    if (authState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (authState.showAuthDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.username != null && widget.username!.isNotEmpty) {
          await ref
              .read(gameAuthControllerProvider.notifier)
              .updateUsername(widget.username!);
        } else {
          final user = FirebaseAuth.instance.currentUser;
          String? newName;
          if (user == null) {
            newName = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (_) => LoginSignUpDialog(gameId: widget.gameId),
            );
          } else {
            newName = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (_) => UpdateUsernameDialog(currentUser: user),
            );
          }
          if (newName != null && newName.isNotEmpty) {
            await ref
                .read(gameAuthControllerProvider.notifier)
                .updateUsername(newName);
          }
        }
      });
      return const SizedBox();
    }
    if (!authState.isJoined) {
      if (authState.username != null && !_hasRequestedJoin) {
        _hasRequestedJoin = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(gameAuthControllerProvider.notifier).joinGame(widget.gameId);
        });
      }
      return const Center(child: CircularProgressIndicator());
    }
    return asyncGameData.when(
      data: (gameDataOrNull) {
        if (gameDataOrNull == null) {
          return const Center(
              child:
                  CircularProgressIndicator(key: Key("gameDataNullIndicator")));
        }

        final Map<String, dynamic> currentGameData = gameDataOrNull;
        final players = currentGameData['players'] as Map<dynamic, dynamic>?;
        final bool isCurrentUserAPlayer =
            players?.containsKey(currentUserId) ?? false;

        if (isCurrentUserAPlayer &&
            players != null &&
            players[currentUserId]?['username'] != null &&
            _currentPlayerUsername != players[currentUserId]?['username']) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentPlayerUsername = players[currentUserId]!.username;
              });
            }
          });
        }
        // Capture metrics from the PREVIOUS state before processing current data
        if (_previousGameData != null) {
          _capturePreviousTileMetrics();
        }

        // Process current game data (assign to allTiles, playerWords, etc.)
        // this.currentPlayerTurn =
        //     currentGameData['currentPlayerTurn'] as String? ?? '';
        // 1) turn flat JSON into Tile objects
        final rawTiles = currentGameData['tiles'] as List<dynamic>?;
        final tilesJson = rawTiles ?? <dynamic>[];

        allTiles = tilesJson.cast<Map<String, dynamic>>().map((item) {
          final tile = Tile.fromMap(item);
          tileGlobalKeys.putIfAbsent(tile.tileId.toString(), () => GlobalKey());
          return tile;
        }).toList();
        final rawWords = currentGameData['words'] as List<dynamic>?;
        final wordsList =
            (rawWords ?? <dynamic>[]).cast<Map<String, dynamic>>();
        // 2) derive the counts
        final tilesLeftCount =
            allTiles.where((t) => t.letter == null || t.letter!.isEmpty).length;
        // 3) isolate the “middle” tiles and sort them
        middleTiles = allTiles.where((t) => t.location == 'middle').toList();
        middleTiles.sort((a, b) {
          final aTimestamp = a.flippedTimestamp ?? 0;
          final bTimestamp = b.flippedTimestamp ?? 0;
          return aTimestamp.compareTo(bTimestamp);
        });

        // Identify the newest tile
        final String? newestTileId =
            middleTiles.isNotEmpty ? middleTiles.last.tileId.toString() : null;

        // 4) figure out whose turn it is
        final currentPlayerTurn =
            currentGameData['currentPlayerTurn'] as String? ?? '';
        _updateTurnState(currentUserId == currentPlayerTurn);
        // 5) build player → username map and color map
        final playersData =
            currentGameData['players'] as Map<dynamic, dynamic>?;
        final playersMap =
            (playersData ?? <String, dynamic>{}).cast<String, dynamic>();
        final playerIdToUsername = <String, String>{};
        playerColorMap.clear(); // Clear previous values
        var colorIdx = 0;

        // Filter out non-player entries like 'max_score_to_win_per_player'
        final playerEntries =
            playersMap.entries.where((entry) => entry.value is Map);

        for (final entry in playerEntries) {
          final playerData = entry.value as Map<String, dynamic>;
          playerIdToUsername[entry.key] =
              playerData['username'] as String? ?? '';
          playerColorMap[entry.key] =
              playerColors[colorIdx++ % playerColors.length];
        }

        // Prepare player scores for the TerritoryBar
        final List<Map<String, dynamic>> playerScoresForTerritoryBar =
            playerEntries
                .map((entry) => {
                      'playerId': entry.key,
                      'score': (entry.value as Map)['score'] as int,
                    })
                .toList();

        // Assign to class member 'playerIdToUsernameMap'
        playerIdToUsernameMap = playerIdToUsername;
        // 6) build & sort playerWords

        if (_previousGameData != null && mounted) {
          _checkForWordTransformations(_previousGameData!, currentGameData);
        }

        // Use a map containing only the filtered player entries
        final filteredPlayersMap = Map.fromEntries(playerEntries);

        List<Map<String, dynamic>> playerWordsPreProcessed;
        // Before processing the current player words, check if it's a stealing event
        if (sourceWordIdsForAnimation.isNotEmpty && _previousGameData != null) {
          // Find the source word ID and the losing player ID from sourceWordIdsForAnimation
          // String stolenWordId = sourceWordIdsForAnimation.first;
          // String losingPlayerId = _previousGameData!['words'].firstWhere(
          //         (word) => word['wordId'] == stolenWordId,
          //         orElse: () => {})['current_owner_user_id'] as String? ?? '';

          // Get the previous words with a placeholder for the stolen word
          // List<Map<String, dynamic>> prevWordsWithPlaceholder = _getPreviousWordsWithPlaceholders(_previousGameData!, losingPlayerId, stolenWordId);

          // Process player words using the previous state with placeholders
          playerWordsPreProcessed =
              processPlayerWords(filteredPlayersMap, wordsList);
        } else {
          // Normal processing of player words if no stealing occurred
          playerWordsPreProcessed =
              processPlayerWords(filteredPlayersMap, wordsList);
        }

        playerWords = playerWordsPreProcessed;
        final me = FirebaseAuth.instance.currentUser?.uid;

        playerWords.sort((a, b) {
          if (a['playerId'] == me) return 1;
          if (b['playerId'] == me) return -1;
          return 0;
        });
        _previousGameData = Map<String, dynamic>.from(currentGameData);

        var screenSize = MediaQuery.of(context).size;
        final double tileSize = screenSize.width > 600 ? 40 : 35;
        Color getBackgroundColor(Tile tile) {
          // If the tile is part of the currently selected input, use the selecting player's color.
          // Otherwise, use specific colors for 'invalid'/'TBD' or the default purple.
          if (gameControllerState.officiallySelectedTileIds
              .contains(tile.tileId.toString())) {
            return playerColorMap[currentUserId] ??
                const Color(0xFF4A148C); // Use player's color
          } else if (tile.tileId == 'invalid') {
            return Colors.red;
          } else if (tile.tileId == 'TBD') {
            return Colors.yellow;
          }
          return const Color(0xFF4A148C); // Default for unselected tiles
        }

        return Focus(
            autofocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              if (HardwareKeyboard.instance.isMetaPressed ||
                  HardwareKeyboard.instance.isControlPressed) {
                if (event.logicalKey == LogicalKeyboardKey.keyR || // Refresh
                        event.logicalKey ==
                            LogicalKeyboardKey.keyL || // Focus address bar
                        event.logicalKey == LogicalKeyboardKey.keyT // New Tab
                    ) {
                  // If it's a KeyDownEvent, let the browser handle it.
                  if (event is KeyDownEvent) {
                    return KeyEventResult
                        .ignored; // Crucial: let browser handle it
                  }
                }
              }

              // Only handle key events if the mobile keyboard is not visible
              if (!_isKeyboardVisible && event is KeyDownEvent) {
                final key = event.logicalKey;
                final isLetter = key.keyLabel.length == 1 &&
                    RegExp(r'^[a-zA-Z]$').hasMatch(key.keyLabel);

                if (isLetter &&
                    gameControllerState.inputtedLetters.length < 16) {
                  gameController.handleLetterTyped(key.keyLabel.toUpperCase());
                } else if (key == LogicalKeyboardKey.backspace) {
                  gameController.handleBackspace();
                } else if (key == LogicalKeyboardKey.enter) {
                  if (gameControllerState.inputtedLetters.isNotEmpty) {
                    _submitWord(currentGameData);
                  } else {
                    _flipNewTile();
                  }
                } else if (key == LogicalKeyboardKey.escape) {
                  gameController.clearInput();
                }
              }
              return KeyEventResult.handled;
            },
            child: Column(
              children: [
                Expanded(
                  child: Scaffold(
                    // Main Scaffold for the GameScreen
                    appBar: AppBar(
                      // On smaller screens (mobile), hide the back button to save space.
                      automaticallyImplyLeading:
                          MediaQuery.of(context).size.width > 600,
                      title: Row(
                        // Use a Row for flexible layout in the title
                        children: [
                          Text(
                            "Game ${widget.gameId}", // Game ID on the left
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),

                          const SizedBox(width: 16), // Spacing
                          Expanded(
                            // Territory Bar in the middle, taking available space
                            child: TerritoryBar(
                              playerScores: playerScoresForTerritoryBar,
                              playerColors: playerColorMap,
                              playerUsernames:
                                  playerIdToUsername, // Pass the usernames map
                            ),
                          ),
                          const SizedBox(width: 16), // Spacing
                          if (MediaQuery.of(context).size.width < 600)
                            IconButton(
                              icon: Icon(_isKeyboardVisible
                                  ? Icons.keyboard_hide
                                  : Icons.keyboard),
                              onPressed: () {
                                setState(() {
                                  _isKeyboardVisible = !_isKeyboardVisible;
                                });
                              },
                            ),
                          IconButton(
                            // Game Instructions button on the right
                            icon: const Icon(Icons.help_outline),
                            onPressed: () {
                              final isMobile =
                                  MediaQuery.of(context).size.width < 600;
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Game Instructions"),
                                    content: GameInstructionsDialogContent(
                                        isMobile: isMobile),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      // No separate actions needed as they are now part of the title row
                      actions: [],
                    ),

                    body: Stack(
                      children: [
                        const SparkleBackground(),
                        LayoutBuilder(// LayoutBuilder for responsive UI
                            builder: (context, constraints) {
                          return Padding(
                            // Padding for the main content area
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              // Main column for game content
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Player Words section (remains the same)
                                Expanded(
                                  flex: 3,
                                  child: ListView.builder(
                                    itemCount: playerWords.length,
                                    itemBuilder: (context, index) {
                                      final playerWordData = playerWords[index];
                                      final isCurrentPlayerTurn =
                                          playerWordData['playerId'] ==
                                              currentPlayerTurn;
                                      final score = currentGameData['players']
                                                  [playerWordData['playerId']]
                                              ['score'] ??
                                          0;
                                      final maxScoreToWin = currentGameData[
                                          'max_score_to_win_per_player'] as int;

                                      final playerIndex = index;
                                      final playerCount = playerWords.length;
                                      return PlayerWords(
                                        // Pass the animation flag down if PlayerWords/TileWidget needs to know
                                        // For now, PlayerWords will receive words already processed,
                                        // some of which might have 'isAnimatingDestinationPlaceholder'.
                                        // TileWidget within PlayerWords should handle this flag for opacity.
                                        // This is handled by the PlayerWords widget internally by checking the word data.
                                        key: ValueKey(
                                            playerWordData['playerId']),
                                        username: playerWordData['username'],
                                        selectingPlayerId: currentUserId,
                                        playerId: playerWordData['playerId'],
                                        words: playerWordData['words'],
                                        playerColors: playerColorMap,
                                        playerIndex: playerIndex,
                                        playerCount: playerCount,
                                        // onClickTile: handleTileSelection,
                                        isKeyboardMode: _isKeyboardVisible,
                                        onClickTile: _isKeyboardVisible
                                            ? (tile, isSelected) {}
                                            : gameController
                                                .handleTileSelection,
                                        officiallySelectedTileIds:
                                            gameControllerState
                                                .officiallySelectedTileIds,
                                        potentiallySelectedTileIds:
                                            gameControllerState
                                                .potentiallySelectedTileIds,
                                        onClearSelection:
                                            gameController.clearInput,
                                        allTiles: allTiles,
                                        tileGlobalKeys: tileGlobalKeys,
                                        tileSize: tileSize,
                                        isCurrentPlayerTurn:
                                            isCurrentPlayerTurn,
                                        score: score,
                                        maxScoreToWin: maxScoreToWin,
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Tiles & Game Log Row
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 5),
                                            Text(
                                              'Tiles ($tilesLeftCount Left):',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                            Expanded(
                                              child: MiddleTilesGridWidget(
                                                middleTiles: middleTiles,
                                                newestTileId: newestTileId,
                                                officiallySelectedTileIds:
                                                    gameControllerState
                                                        .officiallySelectedTileIds,
                                                potentiallySelectedTileIds:
                                                    gameControllerState
                                                        .potentiallySelectedTileIds,
                                                tileGlobalKeys: tileGlobalKeys,
                                                tileSize: tileSize,
                                                onTileSelected: _isKeyboardVisible
                                                    ? (tile, isSelected) {}
                                                    : gameController
                                                            .handleTileSelection
                                                        as void Function(
                                                            Tile, bool),
                                                playerColors: playerColorMap,
                                                selectingPlayerId:
                                                    currentUserId,
                                                currentPlayerTurnUsername:
                                                    playerIdToUsernameMap[
                                                            currentPlayerTurn] ??
                                                        'Someone',
                                                crossAxisCount:
                                                    constraints.maxWidth > 600
                                                        ? 12
                                                        : 8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (MediaQuery.of(context).size.width <
                                              600 &&
                                          _mobileLogMessage != null)
                                        Expanded(
                                          flex: 1,
                                          child: MobileGameLogOverlay(
                                            message: _mobileLogMessage!,
                                            onComplete: () {
                                              if (mounted) {
                                                setState(() {
                                                  _mobileLogMessage = null;
                                                });
                                              }
                                            },
                                            playerColors: playerColorMap,
                                            playerIdToUsernameMap:
                                                playerIdToUsernameMap,
                                          ),
                                        ),
                                      if (constraints.maxWidth > 600)
                                        Expanded(
                                          flex: 1,
                                          child: GameLog(
                                              gameId: widget.gameId,
                                              gameData: currentGameData,
                                              playerIdToUsernameMap:
                                                  playerIdToUsernameMap,
                                              tileSize: tileSize,
                                              playerColors: playerColorMap),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  "Selected Tiles:",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: SelectedTilesDisplay(
                                      inputtedLetters:
                                          gameControllerState.inputtedLetters,
                                      tileSize: tileSize,
                                      getTileBackgroundColor:
                                          getBackgroundColor,
                                      onRemoveTile: () {
                                        gameController.handleBackspace();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    // Show this only if screen is wider than 600px
                    // This is the FAB for actions like flipping a new tile, clearing input, etc.

                    floatingActionButton:
                        MediaQuery.of(context).size.width > 600 ||
                                (MediaQuery.of(context).size.width < 600 &&
                                    !_isKeyboardVisible)
                            ? GameActionsFab(
                                isFlipping: isFlipping,
                                isCurrentUsersTurn: isCurrentUsersTurn,
                                onClear: gameController.clearInput,
                                onFlip: _flipNewTile,
                                onSend: () => _submitWord(currentGameData),
                              )
                            : null,
                  ),
                ),
                if (_isKeyboardVisible)
                  MobileKeyboard(
                    isCurrentUsersTurn: isCurrentUsersTurn,
                    playerColor: playerColorMap[currentUserId],
                    onLetterPressed: (letter) {
                      gameController.handleLetterTyped(letter.toUpperCase());
                    },
                    onDeletePressed: () {
                      gameController.handleBackspace();
                    },
                    onEnterPressed: () {
                      if (gameControllerState.inputtedLetters.isNotEmpty) {
                        _submitWord(currentGameData);
                      } else {
                        _flipNewTile();
                      }
                    },
                  ),
              ],
            ));
      },
      loading: () {
        return const Center(
            child: CircularProgressIndicator(key: Key("loadingIndicator")));
      },
      error: (error, stackTrace) {
        return Center(child: Text('Error loading game: $error'));
      },
    );
  }

  void _capturePreviousTileMetrics() {
    if (!mounted) return;
    previousTileGlobalPositions.clear();
    previousTileSizes.clear();

    final overlayContext = Overlay.of(context).context;

    final RenderObject? overlayRenderObject = overlayContext.findRenderObject();
    if (overlayRenderObject == null) {
      return;
    }

    tileGlobalKeys.forEach((tileId, key) {
      if (key.currentContext != null && key.currentContext!.mounted) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
        // Detailed log before attempting to use renderBox
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          try {
            previousTileGlobalPositions[tileId] = renderBox
                .localToGlobal(Offset.zero, ancestor: overlayRenderObject);
            previousTileSizes[tileId] = renderBox.size;
          } catch (e) {}
        }
      }
    });
  }

  void _checkForWordTransformations(
      Map<String, dynamic> prevData, Map<String, dynamic> currentData) {
    bool animationScheduledThisCheck = false;

    if (!mounted) {
      return;
    }

    final prevActions = prevData['actions'] as Map<String, dynamic>? ?? {};
    final currentActions =
        currentData['actions'] as Map<String, dynamic>? ?? {};

    final prevWordsList = (prevData['words'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (prevWordsList.isEmpty &&
        prevActions.isNotEmpty &&
        currentActions.length > prevActions.length) {}

    for (var actionId in currentActions.keys) {
      if (!prevActions.containsKey(actionId)) {
        // This is a new action
        final action = currentActions[actionId] as Map<String, dynamic>;
        final actionType = action['type'] as String?;

        if (actionType == 'STEAL_WORD' ||
            actionType == 'OWN_WORD_IMPROVEMENT') {
          final originalWordId = action['originalWordId'] as String?;
          final newWordId = action['wordId'] as String?;
          final transformingPlayerId = action['playerId'] as String?;

          if (originalWordId == null ||
              newWordId == null ||
              transformingPlayerId == null) {
            continue;
          }

          Map<String, dynamic>? originalWordData;
          try {
            originalWordData = prevWordsList.firstWhere(
              (w) => w['wordId'] == originalWordId,
            );
          } catch (e) {
            originalWordData = null;
          }

          if (originalWordData == null) {
            continue;
          }

          final fromPlayerId =
              originalWordData['current_owner_user_id'] as String?;

          // Get ALL tile IDs for the new word directly from the action.
          // ASSUMPTION: action['tileIds'] contains all tiles of the new word.
          final allNewWordTileIdsDynamic =
              action['tileIds'] as List<dynamic>? ?? [];
          final List<String> allNewWordTileIds =
              allNewWordTileIdsDynamic.map((id) => id.toString()).toList();

          if (allNewWordTileIds.isEmpty) {
            continue;
          }

          // Get tile IDs from the original word to differentiate.
          final originalWordTileIdsDynamic =
              originalWordData['tileIds'] as List<dynamic>? ?? [];
          final List<String> originalWordTileIds =
              originalWordTileIdsDynamic.map((id) => id.toString()).toList();

          if (fromPlayerId == null) {
            continue;
          }
          if (originalWordTileIds.isEmpty) {
            // This condition checks if the original word had any tiles.
            // It's okay if it's empty if allNewWordTileIds is populated (e.g., an improvement using only middle tiles).
          }

          // Capture positions for any tiles in allNewWordTileIds that are NOT from originalWordTileIds (i.e., from middle for this action)
          Map<String, Offset> currentActionOverrideStartPositions = {};
          Map<String, Size> currentActionOverrideStartSizes = {};
          final overlayRenderObjectForCapture =
              Overlay.of(context).context.findRenderObject();

          if (overlayRenderObjectForCapture != null) {
            for (String tileIdToCapture in allNewWordTileIds) {
              if (!originalWordTileIds.contains(tileIdToCapture)) {
                // Tile is new (from middle) for this action
                final key = tileGlobalKeys[tileIdToCapture];
                if (key != null &&
                    key.currentContext != null &&
                    key.currentContext!.mounted) {
                  final box =
                      key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize && box.attached) {
                    try {
                      final pos = box.localToGlobal(Offset.zero,
                          ancestor: overlayRenderObjectForCapture);
                      final size = box.size;
                      currentActionOverrideStartPositions[tileIdToCapture] =
                          pos;
                      currentActionOverrideStartSizes[tileIdToCapture] = size;
                      if (currentUserId == transformingPlayerId) {
                        // Log specifically for the local player
                      }
                    } catch (e) {
                      if (currentUserId == transformingPlayerId) {
                      } else {}
                    }
                  } else {
                    if (currentUserId == transformingPlayerId) {}
                  }
                } else {
                  if (currentUserId == transformingPlayerId) {}
                }
              }
            }
          }
          if (!destinationWordIdsForAnimation.contains(newWordId)) {
            sourceWordIdsForAnimation.add(originalWordId);
            destinationWordIdsForAnimation.add(newWordId);

            // Trigger mobile log overlay for steal/improvement
            if (MediaQuery.of(context).size.width < 600) {
              Future.delayed(const Duration(milliseconds: 100), () {
                OverlayNotificationService.show(context,
                    message: _getLogMessageForOverlay(action),
                    playerId: action['playerId'] as String?,
                    playerColors: playerColorMap,
                    playerIdToUsernameMap: playerIdToUsernameMap);
              });
            }
            animationScheduledThisCheck = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                startStealAnimation(
                  originalWordId: originalWordId,
                  newWordId: newWordId,
                  tileIds:
                      allNewWordTileIds, // Animate ALL tiles of the new word
                  fromPlayerId: fromPlayerId,
                  toPlayerId: transformingPlayerId,
                  overrideStartPositions: currentActionOverrideStartPositions,
                  overrideStartSizes: currentActionOverrideStartSizes,
                );
              }
            });
          }
          continue; // Move to next action
        }

        if (actionType == 'MIDDLE_WORD') {
          final newWordId = action['wordId'] as String?;
          final playerId = action['playerId'] as String?;
          final tileIdsDynamic = action['tileIds'] as List<dynamic>? ?? [];
          final List<String> tileIds =
              tileIdsDynamic.map((id) => id.toString()).toList();

          if (newWordId == null || playerId == null || tileIds.isEmpty) {
            continue;
          }

          if (!destinationWordIdsForAnimation.contains(newWordId)) {
            // --- CAPTURE MIDDLE TILE POSITIONS NOW ---
            // These are the actual starting positions for tiles coming from the middle.
            Map<String, Offset> currentMiddleTileStartPositions = {};
            Map<String, Size> currentMiddleTileStartSizes = {};
            final overlayRenderObjectForCapture =
                Overlay.of(context).context.findRenderObject();

            if (overlayRenderObjectForCapture != null) {
              for (String tileIdToCapture in tileIds) {
                final key = tileGlobalKeys[tileIdToCapture];
                if (key != null &&
                    key.currentContext != null &&
                    key.currentContext!.mounted) {
                  final box =
                      key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize && box.attached) {
                    try {
                      currentMiddleTileStartPositions[tileIdToCapture] =
                          box.localToGlobal(Offset.zero,
                              ancestor: overlayRenderObjectForCapture);
                      currentMiddleTileStartSizes[tileIdToCapture] = box.size;
                    } catch (e) {}
                  }
                }
              }
            }
            // --- END CAPTURE ---

            destinationWordIdsForAnimation.add(newWordId);
            // Trigger mobile log overlay for middle word creation
            if (MediaQuery.of(context).size.width < 600) {
              Future.delayed(const Duration(milliseconds: 100), () {
                OverlayNotificationService.show(context,
                    message: _getLogMessageForOverlay(action),
                    playerId: action['playerId'] as String?,
                    playerColors: playerColorMap,
                    playerIdToUsernameMap: playerIdToUsernameMap);
              });
            }
            animationScheduledThisCheck = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                startStealAnimation(
                  originalWordId: null,
                  newWordId: newWordId,
                  tileIds: tileIds,
                  fromPlayerId: 'middle', // Special ID for middle
                  toPlayerId: playerId,
                  overrideStartPositions: currentMiddleTileStartPositions,
                  overrideStartSizes: currentMiddleTileStartSizes,
                );
              }
            });
          }
          continue; // Move to next action
        }
      }
    }

    if (animationScheduledThisCheck) {
      // This setState triggers a rebuild. In that rebuild:
      // 1. processPlayerWords uses the updated sourceWordIdsForAnimation and destinationWordIdsForAnimation.
      //    - Source words come from _previousGameData.
      //    - Destination words come from currentData but are marked as placeholders.
      // 2. PlayerWords renders placeholders for destination words, making their GlobalKeys available.
      // The startStealAnimation (post-frame) will then correctly find these keys.
      // _capturePreviousTileMetrics (called at the start of the build) will have captured metrics
      // from the state *before* this rebuild, which is what the animation needs for start positions.
      setState(() {});
    }
  }
}

class Sparkle {
  late Offset position;
  late double size;
  late double phase;
  late Color color;

  Sparkle(Size area) {
    final random = Random();
    position = Offset(
        random.nextDouble() * area.width, random.nextDouble() * area.height);
    size = random.nextDouble() * 2.0 + 1.0; // Sparkle size between 1.0 and 3.0
    phase =
        random.nextDouble() * 2 * pi; // Random phase for unique animation cycle
    color = Color.fromARGB(
      255,
      200 + random.nextInt(56), // Whiter shades
      200 + random.nextInt(56),
      200 + random.nextInt(56),
    );
  }
}

class SparkleBackground extends StatefulWidget {
  const SparkleBackground({super.key});

  @override
  _SparkleBackgroundState createState() => _SparkleBackgroundState();
}

class _SparkleBackgroundState extends State<SparkleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Sparkle> _sparkles = [];
  static const int _numberOfSparkles = 100;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize sparkles once we have the screen size
    if (_sparkles.isEmpty) {
      final size = MediaQuery.of(context).size;
      _sparkles = List.generate(_numberOfSparkles, (_) => Sparkle(size));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SparklePainter(_controller.value, _sparkles),
          child: Container(),
        );
      },
    );
  }
}

class SparklePainter extends CustomPainter {
  final double animationValue;
  final List<Sparkle> sparkles;

  SparklePainter(this.animationValue, this.sparkles);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a dark gradient background
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [Color(0xFF2c003e), Color(0xFF1a0025)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw each sparkle
    for (final sparkle in sparkles) {
      // Calculate opacity based on a sine wave to create a shimmer effect
      final wave = sin(animationValue * 2 * pi + sparkle.phase);
      final opacity = (wave + 1) / 2; // Normalize to 0.0 - 1.0

      final sparklePaint = Paint()
        ..color = sparkle.color.withOpacity(opacity * 0.7);

      // Draw a 4-pointed star for a "diamondy" look
      final path = Path();
      path.moveTo(
          sparkle.position.dx, sparkle.position.dy - sparkle.size); // Top
      path.lineTo(
          sparkle.position.dx + sparkle.size, sparkle.position.dy); // Right
      path.lineTo(
          sparkle.position.dx, sparkle.position.dy + sparkle.size); // Bottom
      path.lineTo(
          sparkle.position.dx - sparkle.size, sparkle.position.dy); // Left
      path.close();

      canvas.drawPath(path, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) {
    // Repaint whenever the animation value changes
    return animationValue != oldDelegate.animationValue;
  }
}

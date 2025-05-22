import 'dart:async';
import 'package:flutter_frontend/widgets/dialogs/update_username_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  final ApiService _apiService = ApiService();

  String? currentUserId;
  String _currentPlayerUsername = "Loading...";
  bool _hasRequestedJoin = false;

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
      processedPlayerWords.add({
        'playerId': playerId,
        'username': playerData['username'],
        'words': <Map<String, dynamic>>[],
      });
    });

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
    } else {
      // No previous data, just process normally
      for (var word in words) {
        final status = (word['status'] as String? ?? '').toLowerCase();
        if (status.contains("valid") &&
            !destinationWordIdsForAnimation.contains(word['wordId'])) {
          final ownerId = word['current_owner_user_id'];
          final playerEntry = processedPlayerWords
              .firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
          if (playerEntry.isNotEmpty) {
            (playerEntry['words'] as List<Map<String, dynamic>>).add(word);
          }
        }
      }
    }
    return processedPlayerWords;
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
                "You can't use letters from multiple words without using the middle.")),
      );
      return;
    } else if (distinctLocations.length > 1) {
      // This logic assumes one of the locations is a wordId from an existing word.
      final wordIdLocation = distinctLocations.firstWhere(
        (loc) => loc != 'middle' && loc != null && loc.isNotEmpty,
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
        final submissionType = result['submission_type'] as String?;
        final submittedWord = result['word'] as String?;
        String message = "$submittedWord submitted successfully!";
        if (submissionType != null && submissionType.isNotEmpty) {
          message += " ($submissionType)";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // The GameController's submitCurrentWord method is expected to call its own clearInput.
      } else {
        // Handle error SnackBar from controller's message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  result['message'] as String? ?? 'Failed to submit word.')),
        );
        // Depending on the error type, the controller might or might not clear input.
        // If it doesn't, the user can retry.
      }
    } catch (e) {
      // Catch any unexpected errors from the controller call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: ${e.toString()}')),
      );
      // Consider if input should be cleared on such an exception.
      // gameController.clearInput(); // Optionally
    }
  }

  Future<void> _flipNewTile() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    if (token != null) {
      final result = await _apiService.flipNewTile(widget.gameId, token);

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
        // 3) isolate the “middle” tiles
        middleTiles = allTiles.where((t) => t.location == 'middle').toList();
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
        for (final entry in playersMap.entries) {
          playerIdToUsername[entry.key] =
              entry.value['username'] as String? ?? '';
          playerColorMap[entry.key] =
              playerColors[colorIdx++ % playerColors.length];
        }
        // Assign to class member 'playerIdToUsernameMap'
        playerIdToUsernameMap = playerIdToUsername;
        // 6) build & sort playerWords

        if (_previousGameData != null && mounted) {
          _checkForWordTransformations(_previousGameData!, currentGameData);
        }
        playerWords = processPlayerWords(playersMap, wordsList);
        final me = FirebaseAuth.instance.currentUser?.uid;

        playerWords.sort((a, b) {
          if (a['playerId'] == me) return 1;
          if (b['playerId'] == me) return -1;
          return 0;
        });
        _previousGameData = Map<String, dynamic>.from(currentGameData);

        var screenSize = MediaQuery.of(context).size;
        final double tileSize = screenSize.width > 600 ? 40 : 25;
        Color getBackgroundColor(Tile tile) {
          switch (tile.tileId) {
            case 'invalid':
              return Colors.red;
            case 'TBD':
              return Colors.yellow;
            case 'valid':
              return const Color(0xFF4A148C);
            default:
              return const Color(0xFF4A148C);
          }
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

            if (event is KeyDownEvent) {
              final key = event.logicalKey;
              final isLetter = key.keyLabel.length == 1 &&
                  RegExp(r'^[a-zA-Z]$').hasMatch(key.keyLabel);

              if (isLetter && gameControllerState.inputtedLetters.length < 16) {
                // _handleLetterTyped(currentGameData, key.keyLabel.toUpperCase());
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
                // setState(() {
                //   clearInput();
                // });
                gameController.clearInput();
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
                            content: GameInstructionsDialogContent(),
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
            body: LayoutBuilder(builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player Words
                    Expanded(
                      child: ListView.builder(
                        itemCount: playerWords.length,
                        itemBuilder: (context, index) {
                          final playerWordData = playerWords[index];
                          final isCurrentPlayerTurn =
                              playerWordData['playerId'] == currentPlayerTurn;
                          final score = currentGameData['players']
                                  [playerWordData['playerId']]['score'] ??
                              0;
                          final maxScoreToWin =
                              currentGameData['max_score_to_win_per_player']
                                  as int;

                          return PlayerWords(
                            // Pass the animation flag down if PlayerWords/TileWidget needs to know
                            // For now, PlayerWords will receive words already processed,
                            // some of which might have 'isAnimatingDestinationPlaceholder'.
                            // TileWidget within PlayerWords should handle this flag for opacity.
                            // This is handled by the PlayerWords widget internally by checking the word data.
                            key: ValueKey(playerWordData['playerId']),
                            username: playerWordData['username'],
                            playerId: playerWordData['playerId'],
                            words: playerWordData['words'],
                            playerColors: playerColorMap,
                            // onClickTile: handleTileSelection,
                            // officiallySelectedTileIds:
                            //     officiallySelectedTileIds,
                            // potentiallySelectedTileIds:
                            //     potentiallySelectedTileIds,
                            // onClearSelection: () {},
                            onClickTile: gameController.handleTileSelection,
                            officiallySelectedTileIds:
                                gameControllerState.officiallySelectedTileIds,
                            potentiallySelectedTileIds:
                                gameControllerState.potentiallySelectedTileIds,
                            onClearSelection: gameController.clearInput,
                            allTiles: allTiles,
                            tileGlobalKeys: tileGlobalKeys,
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
                      flex: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(
                                  'Tiles ($tilesLeftCount Left):',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                MiddleTilesGridWidget(
                                  middleTiles: middleTiles,
                                  officiallySelectedTileIds: gameControllerState
                                      .officiallySelectedTileIds,
                                  potentiallySelectedTileIds:
                                      gameControllerState
                                          .potentiallySelectedTileIds,
                                  tileGlobalKeys: tileGlobalKeys,
                                  tileSize: tileSize,
                                  onTileSelected:
                                      gameController.handleTileSelection,
                                  currentPlayerTurnUsername:
                                      playerIdToUsernameMap[
                                              currentPlayerTurn] ??
                                          'Someone',
                                  crossAxisCount:
                                      constraints.maxWidth > 600 ? 12 : 8,
                                ),
                              ],
                            ),
                          ),
                          if (constraints.maxWidth > 600)
                            const SizedBox(width: 10),
                          if (constraints.maxWidth > 600)
                            Expanded(
                              flex: 1,
                              child: GameLog(
                                  gameId: widget.gameId,
                                  gameData: currentGameData,
                                  playerIdToUsernameMap: playerIdToUsernameMap,
                                  tileSize: tileSize),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "Selected Tiles:",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Expanded(
                      flex: 1,
                      child: SelectedTilesDisplay(
                        inputtedLetters: gameControllerState.inputtedLetters,
                        tileSize: tileSize,
                        getTileBackgroundColor: getBackgroundColor,
                        onRemoveTile: () {
                          gameController.handleBackspace();
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            floatingActionButton: GameActionsFab(
              onClear: () {
                gameController.clearInput();
              },
              onSend: gameControllerState.inputtedLetters.length >= 3
                  ? () => _submitWord(currentGameData)
                  : null,
              onFlip: isCurrentUsersTurn && !isFlipping
                  ? () {
                      // Set isFlipping to true immediately
                      if (mounted) {
                        setState(() {
                          isFlipping = true;
                        });
                      }
                      _flipNewTile();
                    }
                  : null,
              isCurrentUsersTurn: isCurrentUsersTurn,
              isFlipping: isFlipping,
            ),
          ),
        );
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

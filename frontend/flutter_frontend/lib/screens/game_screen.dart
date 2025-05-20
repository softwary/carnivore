import 'dart:async';
import 'package:flutter_frontend/utils/tile_helpers.dart';
import 'package:flutter_frontend/widgets/dialogs/update_username_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter_frontend/widgets/game_actions_fab.dart';
import 'package:flutter_frontend/widgets/dialogs/login_signup_dialog.dart';
import 'package:flutter_frontend/widgets/selected_letter_tile.dart';
import 'package:flutter_frontend/widgets/game_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend/widgets/player_words.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/classes/game_data_provider.dart';
import 'package:flutter_frontend/animations/steal_animation.dart';
import 'package:flutter_frontend/widgets/middle_tiles_grid_widget.dart';
import 'package:flutter_frontend/widgets/dialogs/game_instructions_dialog_content.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String? username;

  const GameScreen({super.key, required this.gameId, required this.username});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin, TileHelpersMixin, StealAnimationMixin {
  void _initializeUsernameAndGameContext() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentPlayerUsername = user.displayName ?? user.email ?? "Player";
      });
    } else {
      setState(() {
        _currentPlayerUsername = "Guest";
      });
    }
  }

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
  bool _isLoadingInitialData = true;
  bool _isAttemptingJoin = false;
  bool _usernamePromptDialogShown = false;
  bool _authDialogShown = false;
  final bool _dialogShown = false;

  String currentPlayerTurn = '';
  List<Tile> allTiles = [];
  List<Tile> middleTiles = [];
  late int tilesLeftCount;

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

    _initializeUsernameAndGameContext();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializeScreenLogic();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _showLoginSignUpDialogIfNeeded(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null &&
        !_authDialogShown &&
        mounted) {
      _authDialogShown = true;

      final String? newName = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LoginSignUpDialog(gameId: widget.gameId),
      );
      _authDialogShown = false;

      if (newName != null && newName.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser!;

        await user.updateDisplayName(newName);
        await user.reload();
        setState(() {
          _currentPlayerUsername = newName;
        });

        final token = await user.getIdToken();
        if (token != null) {
          await _attemptToJoinGame(token);
        }
      }
    }
  }

  Future<void> _initializeScreenLogic() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoadingInitialData = true);

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!_authDialogShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _showLoginSignUpDialogIfNeeded(context);
          if (mounted) _initializeScreenLogic();
        });
      } else {}
      if (FirebaseAuth.instance.currentUser == null && mounted) {
        setState(() => _isLoadingInitialData = false);
      }
      return;
    }

    // USER IS LOGGED IN
    currentUserId = user.uid;

    bool authDisplayNameIsSufficient =
        user.displayName != null && user.displayName!.trim().isNotEmpty;

    if (authDisplayNameIsSufficient) {
      _currentPlayerUsername = user.displayName!;
    } else {
      // Auth displayName is not sufficient, prompt with UpdateUsernameDialog
      if (!_usernamePromptDialogShown && mounted) {
        _usernamePromptDialogShown = true;
        final String? newUsernameFromUpdateDialog = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) =>
              UpdateUsernameDialog(currentUser: user),
        );
        _usernamePromptDialogShown = false;

        if (newUsernameFromUpdateDialog != null &&
            newUsernameFromUpdateDialog.isNotEmpty &&
            mounted) {
          _currentPlayerUsername = newUsernameFromUpdateDialog;
        } else if (mounted) {
          _currentPlayerUsername = "Guest (UpdateCancelled)";
          // Potentially show error or prevent further action
        }
      } else if (_usernamePromptDialogShown) {
        if (mounted) {
          setState(() =>
              _isLoadingInitialData = false); // Allow UI to reflect waiting
        }
        return; // Avoid re-triggering while dialog is up
      }
    }

    // Fallback if _currentPlayerUsername is still not set properly
    if (_currentPlayerUsername == "Loading..." && authDisplayNameIsSufficient) {
      _currentPlayerUsername =
          user.displayName!; // Ensure it's set if auth display name was good
    }

    if (mounted) {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _attemptToJoinGame(String token) async {
    if (mounted) setState(() => _isAttemptingJoin = true);
    try {
      await _apiService.joinGameApi(
        context,
        widget.gameId,
        token,
        username: _currentPlayerUsername,
        onGameNotFound: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game not found.')),
            );
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join game: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAttemptingJoin = false);
    }
  }

  void _updateTurnState(bool newTurnState) {
    if (!mounted) return;
    setState(() {
      isCurrentUsersTurn = newTurnState;
    });
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

  Future<void> _sendTileIds(Map<String, dynamic> gameData) async {
    // Assign locations based on `tileId`
    for (var tile in inputtedLetters) {
      tile.location = findTileLocation(tile.tileId);
    }

    if (inputtedLetters.length < 3) return;

    for (var tile in inputtedLetters) {
      if (tile.tileId is String) {
        tile.tileId = int.tryParse(tile.tileId as String) ?? 'invalid';
      }
    }

    // Ensure all tiles come from the same location or include 'middle'
    final distinctLocations =
        inputtedLetters.map((tile) => tile.location).toSet();

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
      // get this word out of gameData
      final wordData = (gameData['words'] as List).firstWhere(
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
      return;
    }

    try {
      final response =
          await _apiService.sendTileIds(widget.gameId, token, inputtedLetters);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final submissionType = responseData['submission_type'];
        final submittedWord = responseData['word'];

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('HTTP ${response.statusCode} - ${response.body} Error')),
        );
        setState(clearInput);
      }
    } catch (e) {}

    // Ensure UI is updated after processing
    setState(clearInput);
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

  void _handleBackspace() {
    if (inputtedLetters.isNotEmpty) {
      final lastTile = inputtedLetters.removeLast();

      if (lastTile.tileId == "TBD") {
        // If the tile was typed, find one matching tile to unhighlight
        final String backspacedLetter = lastTile.letter!;

        setState(() {
          // Find the first occurrence of this letter in potentiallySelectedTileIds and remove it
          final highlightedTileIdsList = potentiallySelectedTileIds.toList();
          for (int i = 0; i < highlightedTileIdsList.length;) {
            final tileId = highlightedTileIdsList[i];

            final tile = allTiles.firstWhere(
              (t) =>
                  t.letter == backspacedLetter && t.tileId.toString() == tileId,
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );

            potentiallySelectedTileIds.remove(tile.tileId);
            break;
          }
        });
      } else {
        // If the tile was selected, unselect it
        final tileId = lastTile.tileId!;
        setState(() {
          officiallySelectedTileIds.remove(tileId);
          potentiallySelectedTileIds.remove(tileId);
        });
      }
    }

    setState(() {});
  }

  void handleTileSelection(Tile tile, bool isSelected) {
    setState(() {
      if (isSelected) {
        // If the tile is not already selected, add it to the selected tiles
        if (!inputtedLetters
            .any((inputtedTile) => inputtedTile.tileId == tile.tileId)) {
          officiallySelectedTileIds.add(tile.tileId.toString());
          inputtedLetters.add(tile);
        }
      } else {
        officiallySelectedTileIds
            .remove(tile.tileId.toString()); // Unmark the tile as selected
        inputtedLetters
            .removeWhere((inputtedTile) => inputtedTile.tileId == tile.tileId);
      }
    });
  }

  void _handleLetterTyped(Map<String, dynamic> gameData, String letter) {
    setState(() {
      inputtedLetters.add(Tile(letter: letter, tileId: 'TBD', location: ''));
    });

    // Find all tiles that match this letter that are not already in inputtedLetters and not
    // already in officiallySelectedTileIds or in usedTileIds
    final tilesWithThisLetter = findAvailableTilesWithThisLetter(letter);
    // If no tiles match this typed letter
    if (tilesWithThisLetter.isEmpty) {
      assignLetterToThisTileId(letter, "invalid");
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
      // If the tileId is already in inputtedLetters or officiallySelectedTileIds, then it cannot be assigned
      if (officiallySelectedTileIds.contains(tileId) ||
          inputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tileId)) {
        tileId = "invalid";
      }
      // final tileId = tilesWithThisLetter.first.tileId.toString();
      assignLetterToThisTileId(letter, tileId);
    } else {
      // Try to assign tileId since there are multiple options
      assignTileId(letter, tilesWithThisLetter);
    }
    setState(() {
      potentialMatches =
          tilesWithThisLetter.map((tile) => tile.tileId.toString()).toList();
      // If only one letter has been typed so far
      if (inputtedLetters.length > 1) {
        potentiallySelectedTileIds.addAll(potentialMatches);
        // More than two letters → Start refining
        refinePotentialMatches(gameData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncGameData = ref.watch(gameDataProvider(widget.gameId));
    if (_isLoadingInitialData &&
        FirebaseAuth.instance.currentUser == null &&
        !_authDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initializeScreenLogic();
      });
    } else if (_isLoadingInitialData &&
        FirebaseAuth.instance.currentUser != null &&
        (FirebaseAuth.instance.currentUser!.displayName == null ||
            FirebaseAuth.instance.currentUser!.displayName!.isEmpty) &&
        !_usernamePromptDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initializeScreenLogic();
      });
    }
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null && !_dialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginSignUpDialogIfNeeded(context);
      });
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
        this.currentPlayerTurn =
            currentGameData['currentPlayerTurn'] as String? ?? '';
        // 1) turn flat JSON into Tile objects
        final rawTiles = currentGameData['tiles'] as List<dynamic>?;
        final tilesJson = rawTiles ?? <dynamic>[];

        allTiles = tilesJson.cast<Map<String, dynamic>>().map((item) {
          final tile = Tile.fromMap(item);
          tileGlobalKeys.putIfAbsent(tile.tileId.toString(), () => GlobalKey());
          return tile;
        }).toList();

        List<Tile> newAllTiles = [];
        for (var item in tilesJson.cast<Map<String, dynamic>>()) {
          final tile = Tile.fromMap(item);
          newAllTiles.add(tile);
        }
        allTiles = newAllTiles;

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

              if (isLetter && inputtedLetters.length < 16) {
                _handleLetterTyped(currentGameData, key.keyLabel.toUpperCase());
              } else if (key == LogicalKeyboardKey.backspace) {
                _handleBackspace();
              } else if (key == LogicalKeyboardKey.enter) {
                if (inputtedLetters.isNotEmpty) {
                  _sendTileIds(currentGameData);
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
              if (_isLoadingInitialData &&
                  !_authDialogShown &&
                  !_usernamePromptDialogShown) {
                // Show loader only if no dialog is active and we are genuinely in initial setup
                return const Center(
                    child: CircularProgressIndicator(
                        key: ValueKey("initial_setup_loader")));
              }

              if (currentUser == null) {
                // This state is hit if LoginSignUpDialog was cancelled or not yet shown.
                // _initializeScreenLogic will trigger the dialog.
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Please log in or sign up to join the game."),
                      SizedBox(height: 20),
                      CircularProgressIndicator(
                          key: ValueKey("login_prompt_loader_build")),
                    ],
                  ),
                );
              }
              // User is logged in (or just logged in), proceed with loading game data.
              if (_currentPlayerUsername == "Loading..." ||
                  (_currentPlayerUsername.startsWith("Guest") &&
                      !_usernamePromptDialogShown)) {
                // This case implies username setup is pending or failed.
                // _initializeScreenLogic should handle showing the UpdateUsernameDialog if needed.
                // If it's already been shown and cancelled, this state persists.
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("A username is required."),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (mounted) {
                            _initializeScreenLogic(); // Re-trigger logic to show dialog
                          }
                        },
                        child: const Text("Set Username"),
                      ),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(
                          key: ValueKey("username_pending_loader")),
                    ],
                  ),
                );
              }

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
                            onClickTile: handleTileSelection,
                            officiallySelectedTileIds:
                                officiallySelectedTileIds,
                            potentiallySelectedTileIds:
                                potentiallySelectedTileIds,
                            onClearSelection: () {},
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
                                  officiallySelectedTileIds:
                                      officiallySelectedTileIds,
                                  potentiallySelectedTileIds:
                                      potentiallySelectedTileIds,
                                  tileGlobalKeys: tileGlobalKeys,
                                  tileSize: tileSize,
                                  onTileSelected: (tile, isSelected) {
                                    setState(() {
                                      handleTileSelection(tile, isSelected);
                                    });
                                  },
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
            floatingActionButton: GameActionsFab(
              onClear: () {
                setState(() {
                  inputtedLetters.clear();
                  usedTileIds.clear();
                  potentiallySelectedTileIds.clear();
                  officiallySelectedTileIds.clear();
                });
              },
              onSend: inputtedLetters.length >= 3
                  ? () => _sendTileIds(currentGameData)
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

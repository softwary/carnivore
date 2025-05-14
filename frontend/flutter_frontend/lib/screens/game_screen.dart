import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmat;
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/widgets/selected_letter_tile.dart';
import 'package:flutter_frontend/widgets/game_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend/widgets/player_words.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/classes/game_data_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String username;

  const GameScreen({super.key, required this.gameId, required this.username});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _previousGameData;
  final Map<String, GlobalKey> _tileGlobalKeys = {};
  final Map<String, Offset> _previousTileGlobalPositions = {};
  final Map<String, Size> _previousTileSizes = {};
  
  Set<String> _sourceWordIdsForAnimation = {};
  Set<String> _destinationWordIdsForAnimation = {};
  final Set<String> _animatingWordIds = {};

  final ApiService _apiService = ApiService();
  String? currentUserId;

  late DatabaseReference gameRef;
  String currentPlayerTurn = '';
  // Map<String, dynamic>? gameData;
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
    // fetchGameData();

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

  void _startStealAnimation({
    required String? originalWordId,
    required String newWordId,
    required List<String> tileIds,
    required String fromPlayerId,
    required String toPlayerId,
    Map<String, Offset>? overrideStartPositions,
    Map<String, Size>? overrideStartSizes,
  }) async {
    print(
        "🚀 Starting steal animation for word $newWordId with ${tileIds.length} tiles");

    if (!mounted) return;
    if (_animatingWordIds.contains(newWordId)) {
      print("Animation for $newWordId already in progress");
      return;
    }

    _animatingWordIds.add(newWordId);

    // Controllers & entries to track for cleanup
    List<AnimationController> controllers = [];
    List<OverlayEntry> entries = [];
    List<Timer> delayTimers = [];
    bool isAnimationCancelled = false;

    // Capture scroll position at animation start
    List<ScrollPosition> trackingScrollPositions = [];
    List<Offset> initialScrollOffsets = [];

    // Find all scroll positions that might affect our tiles
    void captureScrollPositions() {
      trackingScrollPositions.clear();
      initialScrollOffsets.clear();

      // Find scrollable ancestors that could affect our tiles
      ScrollableState? findScrollableAncestor(BuildContext? context) {
        if (context == null) return null;
        return Scrollable.of(context);
      }

      // Check both "from" and "to" contexts for scrollables
      for (var tileId in tileIds) {
        // Check source
        final sourceKey = _tileGlobalKeys[tileId];
        if (sourceKey?.currentContext != null) {
          final scrollable = findScrollableAncestor(sourceKey!.currentContext);
          if (scrollable != null &&
              !trackingScrollPositions.contains(scrollable.position)) {
            trackingScrollPositions.add(scrollable.position);
            initialScrollOffsets.add(Offset(
                scrollable.position.pixels,
                scrollable.axisDirection == AxisDirection.down ||
                        scrollable.axisDirection == AxisDirection.up
                    ? scrollable.position.pixels
                    : 0.0));
          }
        }

        // Check destination
        final destKey = _tileGlobalKeys[tileId];
        if (destKey?.currentContext != null) {
          final scrollable = findScrollableAncestor(destKey!.currentContext);
          if (scrollable != null &&
              !trackingScrollPositions.contains(scrollable.position)) {
            trackingScrollPositions.add(scrollable.position);
            initialScrollOffsets.add(Offset(
                scrollable.position.pixels,
                scrollable.axisDirection == AxisDirection.down ||
                        scrollable.axisDirection == AxisDirection.up
                    ? scrollable.position.pixels
                    : 0.0));
          }
        }
      }

      print(
          "🔍 Tracking ${trackingScrollPositions.length} scroll positions for animation");
    }

    // Calculates scroll delta from when animation started
    Offset getScrollDelta(int index) {
      if (index >= trackingScrollPositions.length) return Offset.zero;

      final scrollPosition = trackingScrollPositions[index];
      final initialOffset = index < initialScrollOffsets.length
          ? initialScrollOffsets[index]
          : Offset.zero;

      final double dx = scrollPosition.axis == Axis.horizontal
          ? scrollPosition.pixels - initialOffset.dx
          : 0.0;

      final double dy = scrollPosition.axis == Axis.vertical
          ? scrollPosition.pixels - initialOffset.dy
          : 0.0;

      return Offset(dx, dy);
    }

    // Make sure we have the latest positions captured
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _animatingWordIds.remove(newWordId);
      return;
    }

    captureScrollPositions();

    final overlay = Overlay.of(context);
    if (overlay == null) {
      _animatingWordIds.remove(newWordId);
      return;
    }

    final overlayContext = overlay.context;
    final overlayRenderObject = overlayContext.findRenderObject();
    if (overlayRenderObject == null) {
      print("Error: Overlay RenderObject is null");
      _animatingWordIds.remove(newWordId);
      return;
    }

    void cleanupAnimations() {
      if (isAnimationCancelled) return;
      isAnimationCancelled = true;

      for (var timer in delayTimers) {
        timer.cancel();
      }

      for (var entry in entries) {
        try {
          if (entry.mounted) entry.remove();
        } catch (e) {
          print("Error removing overlay entry: $e");
        }
      }

      for (var controller in controllers) {
        try {
          if (controller.isAnimating) controller.stop();
          controller.dispose();
        } catch (e) {
          print("Error disposing controller: $e");
        }
      }

      _animatingWordIds.remove(newWordId);

      // After animation completes, update state to show words normally
      setState(() {
        _destinationWordIdsForAnimation.remove(newWordId);
        if (originalWordId != null) _sourceWordIdsForAnimation.remove(originalWordId);
      });

      print("✅ Animation completed for word $newWordId");
    }

    for (int i = 0; i < tileIds.length; i++) {
      final tileId = tileIds[i];

      // Find the tile in allTiles
      final tileData = allTiles.firstWhere((t) => t.tileId.toString() == tileId,
          orElse: () => Tile(letter: '', tileId: '', location: ''));

      if (tileData.tileId == '') {
        print("Tile data not found for $tileId");
        continue;
      }

      // Get start position
      Offset? startPosition;
      Size? startSize;

      // Prioritize overrideStartPositions if available for this specific tile.
      // This covers tiles explicitly captured as "newly added from middle" during _checkForWordTransformations
      // or tiles from a 'MIDDLE_WORD' action.
      if (overrideStartPositions != null && overrideStartPositions.containsKey(tileId)) {
        startPosition = overrideStartPositions[tileId];
        startSize = (overrideStartSizes != null) ? overrideStartSizes[tileId] : null;
        if (startPosition != null && currentUserId == toPlayerId) { // Log for local player if override is used
          // print("🚀 LOCAL ANIM ($newWordId): Using OVERRIDE start pos for tile $tileId: $startPosition");
        }
      }
      
      // Fallback to previously captured metrics if override was not available or didn't provide a complete set of metrics.
      if (startPosition == null || startSize == null) { // Check if either is null to ensure we try the fallback
          startPosition ??= _previousTileGlobalPositions[tileId];
          startSize ??= _previousTileSizes[tileId];
          // if (startPosition != null && currentUserId == toPlayerId) print("🚀 LOCAL ANIM ($newWordId): Using PREVIOUS start pos for tile $tileId: $startPosition");
      }

      if (startPosition == null || startSize == null) {
        print("⚠️ Missing start metrics for tile $tileId (Letter: ${tileData.letter}, FromPlayer: $fromPlayerId, ToPlayer: $toPlayerId, OriginalWord: $originalWordId, NewWord: $newWordId). Animation for this tile will be skipped.");
        continue;
      }

      // Get the end position (destination tile)
      final endKey = _tileGlobalKeys[tileId];
      if (endKey == null || endKey.currentContext == null) {
        print("Missing end key/context for tile $tileId");
        continue;
      }

      // Growth controller
      final growController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      controllers.add(growController);

      // Growth animation
      final growAnimation = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.5), weight: 50),
        TweenSequenceItem(
            tween: Tween<double>(begin: 1.5, end: 1.0), weight: 50),
      ]).animate(
          CurvedAnimation(parent: growController, curve: Curves.easeInOut));

      // Movement controller
      final moveController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      controllers.add(moveController);

      // Create the overlay that will track position changes
      OverlayEntry overlayEntry = OverlayEntry(
        builder: (context) {
          // Get latest end position, accounting for scrolling
          Offset getUpdatedEndPosition() {
            if (endKey.currentContext == null ||
                !mounted ||
                isAnimationCancelled) {
              return startPosition ?? Offset.zero; // Fall back to start position if we can't get end
            }

            final RenderBox? endBox =
                endKey.currentContext!.findRenderObject() as RenderBox?;
            if (endBox == null || !endBox.hasSize || !endBox.attached) {
              return startPosition ?? Offset.zero;
            }

            try {
              return endBox.localToGlobal(Offset.zero,
                  ancestor: overlayRenderObject);
            } catch (e) {
              print("Error getting updated end position: $e");
              return startPosition ?? Offset.zero;
            }
          }

          // Adjust for scroll movement in original position
          Offset adjustForScroll(Offset basePosition) {
            Offset scrollAdjustment = Offset.zero;

            // Combine all scroll changes
            for (int i = 0; i < trackingScrollPositions.length; i++) {
              final delta = getScrollDelta(i);
              scrollAdjustment = Offset(scrollAdjustment.dx - delta.dx,
                  scrollAdjustment.dy - delta.dy);
            }

            return Offset(basePosition.dx + scrollAdjustment.dx,
                basePosition.dy + scrollAdjustment.dy);
          }

          // Current start and end positions, adjusted for scrolling
          final adjustedStartPosition = adjustForScroll(startPosition ?? Offset.zero);
          final currentEndPosition = getUpdatedEndPosition();

          // Create movement animation based on current positions
          final moveAnimation = Tween<Offset>(
            begin: adjustedStartPosition,
            end: currentEndPosition,
          ).animate(CurvedAnimation(
              parent: moveController, curve: Curves.easeInOutCubic));

          return Stack(
            children: [
              // GROWTH PHASE - stays at start position, adjusts for scrolling
              AnimatedBuilder(
                animation: growAnimation,
                builder: (context, child) {
                  if (moveController.value > 0.0) return SizedBox.shrink();

                  return Positioned(
                    left: adjustForScroll(startPosition ?? Offset.zero).dx,
                    top: adjustForScroll(startPosition ?? Offset.zero).dy,
                    child: Transform.scale(
                      scale: growAnimation.value,
                      child: Material(
                        type: MaterialType.transparency,
                        child: TileWidget(
                          tile: tileData,
                          tileSize: startSize?.width ?? 0,
                          onClickTile: (_, __) {},
                          isSelected: false,
                          backgroundColor:
                              playerColorMap[fromPlayerId] ?? Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // MOVEMENT PHASE - dynamically updates with current positions
              AnimatedBuilder(
                animation: moveAnimation,
                builder: (context, child) {
                  if (moveController.value == 0.0) return SizedBox.shrink();

                  final scale = 1.0 +
                      (0.2 * (1 - (moveController.value - 0.5).abs() * 2));

                  return Positioned(
                    left: moveAnimation.value.dx,
                    top: moveAnimation.value.dy,
                    child: Transform.scale(
                      scale: scale,
                      child: Material(
                        type: MaterialType.transparency,
                        child: TileWidget(
                          tile: tileData,
                          tileSize: startSize?.width ?? 0,
                          onClickTile: (_, __) {},
                          isSelected: false,
                          backgroundColor: Color.lerp(
                                  playerColorMap[fromPlayerId] ?? Colors.grey,
                                  playerColorMap[toPlayerId] ?? Colors.purple,
                                  moveController.value) ??
                              Colors.purple,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );

      entries.add(overlayEntry);
      overlay.insert(overlayEntry);

      // Stagger animations with delay
      final timer = Timer(Duration(milliseconds: i * 200), () {
        if (isAnimationCancelled || !mounted) return;

        growController.forward().then((_) {
          if (isAnimationCancelled || !mounted) return;

          moveController.forward().then((_) {
            if (i == tileIds.length - 1) {
              Timer(Duration(milliseconds: 200), () {
                if (mounted) cleanupAnimations();
              });
            }
          });
        });
      });

      delayTimers.add(timer);
    }

    // Safety cleanup
    Timer(Duration(seconds: 5), () {
      if (!isAnimationCancelled && mounted) {
        print("⚠️ Safety cleanup triggered for animation of word $newWordId");
        cleanupAnimations();
      }
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

      if (_destinationWordIdsForAnimation.contains(wordId)) {
        final playerEntry = processedPlayerWords.firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
        if (playerEntry.isNotEmpty) {
          final placeholderWord = Map<String, dynamic>.from(currentWord);
          placeholderWord['isAnimatingDestinationPlaceholder'] = true;
          (playerEntry['words'] as List<Map<String, dynamic>>).add(placeholderWord);
        }
      } else if (!_sourceWordIdsForAnimation.contains(wordId)) {
        // If it's not a destination and not a source (which are handled from prevData),
        // then it's a normal current word.
        final playerEntry = processedPlayerWords.firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
        if (playerEntry.isNotEmpty) {
          (playerEntry['words'] as List<Map<String, dynamic>>).add(currentWord);
        }
      }
    }

    // Add source words from previous data
    if (_previousGameData != null) {
      final prevWordsList = (_previousGameData!['words'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (var prevWord in prevWordsList) {
        final prevWordId = prevWord['wordId'] as String;
        final prevOwnerId = prevWord['current_owner_user_id'] as String;
        final prevStatus = (prevWord['status'] as String? ?? '').toLowerCase();

        if (!prevStatus.contains("valid")) continue;

        if (_sourceWordIdsForAnimation.contains(prevWordId)) {
          final playerEntry = processedPlayerWords.firstWhere((p) => p['playerId'] == prevOwnerId, orElse: () => {});
          if (playerEntry.isNotEmpty) {
            (playerEntry['words'] as List<Map<String, dynamic>>).add(prevWord);
          }
        }
      }
    } else {
      // No previous data, just process normally
      words.forEach((word) {
        final status = (word['status'] as String? ?? '').toLowerCase();
        if (status.contains("valid") && !_destinationWordIdsForAnimation.contains(word['wordId'])) {
          final ownerId = word['current_owner_user_id'];
          final playerEntry = processedPlayerWords.firstWhere((p) => p['playerId'] == ownerId, orElse: () => {});
          if (playerEntry.isNotEmpty) {
            (playerEntry['words'] as List<Map<String, dynamic>>).add(word);
          }
        }
      });
    }
    return processedPlayerWords;
  }

  String _findTileLocation(List<Tile> allTiles, dynamic tileId) {
    return allTiles
            .firstWhere((t) => t.tileId == tileId,
                orElse: () => Tile(letter: '', tileId: '', location: ''))
            .location ??
        '';
  }

  Future<void> _sendTileIds(Map<String, dynamic> gameData) async {
    // Assign locations based on `tileId`
    for (var tile in inputtedLetters) {
      tile.location = _findTileLocation(allTiles, tile.tileId);
    }

    // print(
    //     "💚💚💚 Sending tileIds... officiallySelectedTileIds: $officiallySelectedTileIds, inputtedLetters: ${inputtedLetters.map((tile) => {
    //           'letter': tile.letter,
    //           'location': tile.location,
    //           'tileId': tile.tileId
    //         }).toList()}");

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

    // print(
    //     "🔄🔄✅🔄🔄 Inputted Letters (after sync): ${inputtedLetters.map((t) => '${t.letter}: ${t.tileId}').toList()}");

    // print(
    //     "🔄🔄🔄 Fixed Sync: officiallySelectedTileIds = $officiallySelectedTileIds");
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
    // print(
    //     "in handleTileSelection: letter: ${tile.letter}, tileId: ${tile.tileId}, isSelected: $isSelected");
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
        // print(
        //     "✅ _assignLetterToThisTileId officiallySelectedTileIds before: $officiallySelectedTileIds");
        // print("✅ _assignLetterToThisTileId usedTileIds before: $usedTileIds");
        // print(
        //     "✅ _assignLetterToThisTileId inputtedLetters before: ${inputtedLetters.map((tile) => {
        //           'letter': tile.letter,
        //           'tileId': tile.tileId
        //         }).toList()}");

        officiallySelectedTileIds.add(tileId);
        // print(
        // "✅ _assignLetterToThisTileId() (only one option) Assigned tileId $tileId to letter $letter");
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

  void _handleLetterTyped(Map<String, dynamic> gameData, String letter) {
    // print("##################################################################");
    // print("######################Typed letter: $letter ######################");
    // print("##################################################################");
    setState(() {
      inputtedLetters.add(Tile(letter: letter, tileId: 'TBD', location: ''));
    });

    // Find all tiles that match this letter that are not already in inputtedLetters and not
    // already in officiallySelectedTileIds or in usedTileIds
    final tilesWithThisLetter = _findAvailableTilesWithThisLetter(letter);
    // print(
    //     "Tiles with this letter (found everywhere except inputtedLetters/officiallySelected/usedTileIds):");
    for (var tile in tilesWithThisLetter) {
      // print("Tile (${tile.letter}): id: ${tile.tileId} - ${tile.location}");
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
      // print(
      //     "🌿✅✅✅✅ Only one tile found for letter $letter:...assignLetterToThisTileId --> tileId = $tileId");
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
        // print(
        //     "potentiallySelected[highlighted] tile IDs for after typing $letter: $potentiallySelectedTileIds");
        // print("More than one letter typed, refining potential matches...");
        _refinePotentialMatches(gameData);
      }
    });
  }

  void _assignTileId(String letter, List<Tile> tilesWithThisLetter) {
    for (var tile in tilesWithThisLetter) {
      // print(
      //     "in _assignTileId function: letter = $letter, tilesWithThisLetterTile (${tile.letter}): id: ${tile.tileId} - ${tile.location}");
    }
    // If there is only one tile with this letter, assign it to the selected tile
    if (tilesWithThisLetter.length == 1) {
      final tileId = tilesWithThisLetter.first.tileId.toString();
      setState(() {
        inputtedLetters.removeLast();
        inputtedLetters.add(Tile(letter: letter, tileId: tileId, location: ''));
        potentiallySelectedTileIds.add(tileId);
        officiallySelectedTileIds.add(tileId);
        // print("✅ (only one option) Assigned tileId $tileId to letter $letter");
      });
      return;
    }
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
            // print(
            //     "✅ Assigned tileId $tileId from location ($location) to letter $letter");
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
              // print(
              //     "✅ Assigned fallback tileId $fallbackTileId from location ($location) to letter $letter");
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
    // print(
    //     "🔚 End of _assignTileId function, inputtedLetters=: ${matchingTiles.map((tile) => {
    //           'letter': tile.letter,
    //           'tileId': tile.tileId,
    //           'location': tile.location
    //         }).toList()}");
  }

  void _reassignTilesToMiddle() {
    // Needs to look through the inputtedLetters and find ones that are either invalid or from non-middle locations
    // Then, it should find a matching middle tile and assign it to the selectedTile
    // Needs to make sure that middle tile has not already been assigned (ie its tileId is not in inputtedLetters)
    // print("🔍🔍🔍 Start of _reassignTilesToMiddle function");
    final List<Tile> allMiddleTiles =
        allTiles.where((tile) => tile.location == 'middle').toList();
    // print all middleTiles
    // print("🔍 All selected tiles: ${inputtedLetters.map((tile) => {
    //       'letter': tile.letter,
    //       'tileId': tile.tileId
    //     }).toList()}");
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
      // print("🔍☑ All selected tiles are already assigned to middle tiles");
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

  Map<String, dynamic> getWordData(
      Map<String, dynamic> gameData, String wordId) {
    final word = (gameData['words'] as List).firstWhere(
      (word) => word['wordId'] == wordId,
      orElse: () => null,
    );
    return word;
  }

  void _refinePotentialMatches(Map<String, dynamic> gameData) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    // print("💼💼💼 Start of _refinePotentialMatches function");

    final String typedWord = inputtedLetters.map((tile) => tile.letter).join();
    final List<String> typedWordLetters = typedWord.split('');

    // debugPrint("💼 Current typed word: $typedWord");

    final Map<String, List<String>> letterToTileIds = {};

    for (var tile in allTiles) {
      if (tile.letter != null && tile.letter!.isNotEmpty) {
        letterToTileIds.putIfAbsent(tile.letter!, () => []);
        letterToTileIds[tile.letter!]!.add(tile.tileId.toString());
      }
    }

    // debugPrint("🔍 Possible tile matches for each letter: $letterToTileIds");

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
      // debugPrint(
      //     "✅ All selected letters have at least one potential match from the middle");
      _reassignTilesToMiddle();
    } else {
      debugPrint("❌ Not all selected letters have a middle match");

      final matchingWords = (gameData['words'] as List).where((word) {
        // Ensure the word status is valid
        final String status = (word['status'] as String? ?? '').toLowerCase();
        if (!status.contains("valid")) {
          return false;
        }

        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();

        final String wordString = wordTileIds.map((tileId) {
          return allTiles
              .firstWhere((t) => t.tileId.toString() == tileId,
                  orElse: () => Tile(letter: '', tileId: '', location: ''))
              .letter;
        }).join();

        // debugPrint("🔍 Checking word: $wordString with tileIds: $wordTileIds");

        // Check if every letter of the word exists in typedWordLetters with correct frequency
        List<String> tempLetters = List.from(typedWordLetters);
        bool isContained = true;
        for (var letter in wordString.split('')) {
          if (tempLetters.contains(letter)) {
            tempLetters.remove(letter);
          } else {
            isContained = false;
            break;
          }
        }

        if (!isContained) {
          // debugPrint("❌ $wordString is NOT contained in $typedWord");
        } else {
          // debugPrint("✅ $wordString is contained in $typedWord");
        }

        return isContained;
      }).toList();

      // print("💀 Found contained matching words: $matchingWords");

      if (matchingWords.isEmpty) {
        // print(
        // "✅ No full word matches found, and letters are not all from middle tiles");
        // _reassignTilesToMiddle();
      } else {
        // print(
        // "There are exact matching words. Proceeding to reassign tiles to the longest matching word that does not belong to this user...");
        // If not all selected letters have a middle match, reassign tiles to middle
        // check if there are any full words that can be formed with the current inputted letters
        // print("💀 all the words that match: $matchingWords");
        // Sort by the length of the word, longest first
        matchingWords.sort((a, b) => b.length.compareTo(a.length));

        // Find first word that is not owned by this user, and assign its tileIds to the selected tiles
        final matchingWordToUse = matchingWords.firstWhere(
            (word) => word['current_owner_user_id'] != userId,
            orElse: () => matchingWords.first);
        // print(
        // "💀 matchingWordToUse (the word to steal/take): $matchingWordToUse");
        // Assign the tileIds of the matching word to the selected tiles
        final tileIdsToReassignInputtedLettersToFromMatchingWord =
            matchingWordToUse['tileIds'] as List<dynamic>;
        // print("if you make it here...interesting (790)");
        // print(
        // "💀 tileIds to reassign inputted letters to: $tileIdsToReassignInputtedLettersToFromMatchingWord");
        // print("💀 tileIds from matchingWord = ${matchingWordToUse['tileIds']}");
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
        // print(
        // "💀 calling _reassignTilesToWord with wordId = ${matchingWordToUse['wordId']}");
        _reassignTilesToWord(gameData, matchingWordToUse['wordId']);
        // print("just called _reassignTilesToWord");
        // for each tileId in tileIdsToReassignInputtedLettersToFromMatchingWord, find the corresponding tile in allTiles
        // and reassign the tileId of the inputtedLetters to that tileId
      }
      _syncTileIdsWithInputtedLetters();
    }

    // print("🔚🔚🔚 End of refine function, 🩵 officiallySelectedTileIds = ");
    officiallySelectedTileIds.forEach((tileId) {
      final tile = allTiles.firstWhere(
        (t) => t.tileId.toString() == tileId.toString(),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );
      // print(
      //     "🩵🩵 officiallySelectedTiles tile: ${tile.letter} - ${tile.tileId} - ${tile.location}");
    });
  }

  _reassignTilesToWord(Map<String, dynamic> gameData, String wordId) {
    // print("💀💀💀 Start of _reassignTilesToWord function, wordId = $wordId");
    // This function should reassign the tileIds of the inputtedLetters to the tileIds of the word with the given wordId
    final word = getWordData(gameData, wordId);
    if (word == null) {
      print("❌ Word not found for wordId: $wordId");
      return;
    }
    // print("💀 Word data for wordId $wordId: $word");
    final List<String> tileIds = (word['tileIds'] as List<dynamic>)
        .map((tileId) => tileId.toString())
        .toList();

    setState(() {
      for (var selectedTile in inputtedLetters) {
        // print(
        //     "🔍_reassignTilesToWord Checking selected tile to see if it needs reassignment to a word tile:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
        if (selectedTile.tileId != 'TBD') {
          final assignedTile = allTiles.firstWhere(
            (tile) => tile.tileId.toString() == selectedTile.tileId,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          if (assignedTile.tileId != '' &&
              tileIds.contains(assignedTile.tileId.toString())) {
            continue;
          }

          // print(
          //     "💀💀💀_reassignTilesToWord This tile needs to be reassigned to a word tile: letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");

          final matchingWordTile = allTiles.firstWhere(
            (tile) =>
                tileIds.contains(tile.tileId.toString()) &&
                tile.letter == selectedTile.letter &&
                !inputtedLetters.any((inputtedTile) =>
                    inputtedTile.tileId == tile.tileId.toString()),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );

          // print(
          //     "💀💀💀_reassignTilesToWord Matching word tile it can be reassigned to: ${matchingWordTile.letter}, tileId: ${matchingWordTile.tileId}");

          if (matchingWordTile.tileId != '') {
            officiallySelectedTileIds.remove(selectedTile.tileId);
            selectedTile.tileId = matchingWordTile.tileId.toString();
            officiallySelectedTileIds.add(matchingWordTile.tileId.toString());
            // print(
            //     "!!! 💀💀💀_reassignTilesToWord Reassigned tile to be:  letter: ${selectedTile.letter}, tileId: ${selectedTile.tileId}");
          }
        }
      }
    });

    // print(
    //     "💀💀💀 End of _reassignTilesToWord function: ${inputtedLetters.map((tile) => {
    //           'letter': tile.letter,
    //           'tileId': tile.tileId
    //         }).toList()}");
    // print(
    //     "💀🔄💀 Reassigned tileIds of inputtedLetters to those of the word with wordId $wordId: ${inputtedLetters.map((tile) => {
    //           'letter': tile.letter,
    //           'tileId': tile.tileId
    //         }).toList()}");
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
    final asyncGameData = ref.watch(gameDataProvider(widget.gameId));
    return asyncGameData.when(
      data: (gameDataOrNull) {
        if (gameDataOrNull == null) {
          print("❌ Game data from provider is null after loading.");
          return const Center(
              child:
                  CircularProgressIndicator(key: Key("gameDataNullIndicator")));
        }
        final Map<String, dynamic> currentGameData = gameDataOrNull;
        // print("💀💀💀 Current game data: $currentGameData");
        // Successfully got data
        //// Capture metrics from the PREVIOUS state before processing current data
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
          _tileGlobalKeys.putIfAbsent(
              tile.tileId.toString(), () => GlobalKey());
          return tile;
        }).toList();

        List<Tile> newAllTiles = [];
        for (var item in tilesJson.cast<Map<String, dynamic>>()) {
          final tile = Tile.fromMap(item);
          // Ensure a key exists for every tile ID that might be displayed
          // _tileGlobalKeys.putIfAbsent(
          //     tile.tileId.toString(), () => GlobalKey());
          newAllTiles.add(tile);
        }
        allTiles = newAllTiles;

        final rawWords = currentGameData['words'] as List<dynamic>?;
        final wordsList =
            (rawWords ?? <dynamic>[]).cast<Map<String, dynamic>>();
        // 2) derive the counts
        final tilesLeftCount = this
            .allTiles
            .where((t) => t.letter == null || t.letter!.isEmpty)
            .length;
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
          print(
              "🔄 Comparing previous and current game data for transformations.");
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
              return const Color(0xFF4A148C);
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
                _handleLetterTyped(currentGameData, key.keyLabel.toUpperCase());
              } else if (key == LogicalKeyboardKey.backspace) {
                _handleBackspace();
              } else if (key == LogicalKeyboardKey.enter) {
                if (inputtedLetters.isNotEmpty) {
                  print(
                      "❤️ Submitting selected tiles: inputtedletters = ${inputtedLetters.map((tile) => {
                            'letter': tile.letter,
                            'tileId': tile.tileId
                          }).toList()}");
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
                            content: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context)
                                    .style
                                    .copyWith(
                                        fontSize: 20, color: Colors.white),
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
                              playerWordData['playerId'] ==
                                  currentPlayerTurn;
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
                            tileGlobalKeys: _tileGlobalKeys,
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
                                  'Tiles ($tilesLeftCount Left):',
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
                                    : Expanded(
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
                                            if (index >=
                                                middleTiles.length) {
                                              return SizedBox.shrink();
                                            }
                                            final tile =
                                                middleTiles[index];
                                            final tileIdStr =
                                                tile.tileId.toString();
                                            // _tileGlobalKeys.putIfAbsent(
                                            //     tileIdStr, () => GlobalKey());

                                            final isSelected =
                                                officiallySelectedTileIds
                                                    .contains(
                                                        tile.tileId.toString());
                                            final isHighlighted =
                                                potentiallySelectedTileIds
                                                    .contains(
                                                        tile.tileId.toString());
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1.0),
                                                  child: TileWidget( // Ensure _tileGlobalKeys[tileIdStr] is THE key
                                                    key: _tileGlobalKeys[tileIdStr], // Use GlobalKey as the widget's key
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
                          if (constraints.maxWidth > 600)
                            const SizedBox(width: 10),
                          if (constraints.maxWidth > 600)
                            Expanded(
                              flex: 1,
                              child: GameLog(
                                  gameId: widget.gameId,
                                  gameData: currentGameData,
                                  playerIdToUsernameMap:
                                      playerIdToUsernameMap,
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
                  onPressed: (inputtedLetters.length >= 3)
                      ? () => _sendTileIds(currentGameData)
                      : null,
                  child: const Icon(Icons.send_rounded),
                  backgroundColor:
                      (inputtedLetters.length >= 3) ? null : Colors.grey,
                  heroTag: 'send',
                ),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _flipAnimation,
                  child: preRotatedText,
                  builder: (context, animatedChild) {
                    final animationValue = _flipAnimation.value;
                    final angle = -animationValue * math.pi;
                    final isBack = angle.abs() > (math.pi / 2);

                    final axis = vmat.Vector3(1, -1, 0).normalized();

                    final transformMatrix = Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotate(axis, angle);

                    final Matrix4 unmirrorTransform;
                    if (isBack) {
                      unmirrorTransform = Matrix4.identity()
                        ..rotate(axis, math.pi);
                    } else {
                      unmirrorTransform = Matrix4.identity();
                    }

                    Color borderColor = const Color.fromARGB(255, 255, 0, 251);
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
      },
      loading: () {
        print("🔄 Game data is loading...");

        return const Center(
            child: CircularProgressIndicator(key: Key("loadingIndicator")));
      },
      error: (error, stackTrace) {
        print("🔥 Error loading game data: $error\n$stackTrace");

        return Center(child: Text('Error loading game: $error'));
      },
    );
  }

  void _capturePreviousTileMetrics() {
    if (!mounted) return;
    _previousTileGlobalPositions.clear();
    _previousTileSizes.clear();

    final overlayContext = Overlay.of(context)?.context;
    if (overlayContext == null) {
      print("Error: Overlay context is null in _capturePreviousTileMetrics.");
      return;
    }

    final RenderObject? overlayRenderObject = overlayContext.findRenderObject();
    if (overlayRenderObject == null) {
      print(
          "Error: Overlay RenderObject is null in _capturePreviousTileMetrics.");
      return;
    }

    _tileGlobalKeys.forEach((tileId, key) {
      if (key.currentContext != null && key.currentContext!.mounted) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
        // Detailed log before attempting to use renderBox
        // print("Metrics Capture Attempt for $tileId: KeyContextMounted=${key.currentContext?.mounted}, RenderBoxNull=${renderBox == null}, HasSize=${renderBox?.hasSize}, Attached=${renderBox?.attached}");
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          try {
            _previousTileGlobalPositions[tileId] = renderBox
                .localToGlobal(Offset.zero, ancestor: overlayRenderObject);
            _previousTileSizes[tileId] = renderBox.size;
            // print("Metrics Captured for $tileId: Pos=${_previousTileGlobalPositions[tileId]}, Size=${_previousTileSizes[tileId]}");
          } catch (e) {
            print("Error in localToGlobal for tile $tileId: $e. RenderBox details: HasSize=${renderBox.hasSize}, Attached=${renderBox.attached}");
          }
        }
      }
    });
  }


void _checkForWordTransformations(
      Map<String, dynamic> prevData, Map<String, dynamic> currentData) {
    print("_checkForWordTransformations ");
    bool animationScheduledThisCheck = false;

    print("👀 _checkForWordTransformations called");
    if (!mounted) {
      print("👀 _checkForWordTransformations: not mounted, returning");
      return;
    }

    final prevActions = prevData['actions'] as Map<String, dynamic>? ?? {};
    final currentActions =
        currentData['actions'] as Map<String, dynamic>? ?? {};

    final prevWordsList = (prevData['words'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (prevWordsList.isEmpty &&
        prevActions.isNotEmpty &&
        currentActions.length > prevActions.length) {
      print(
          "ℹ️ _checkForWordTransformations: prevWordsList is empty, but new actions detected. This might be okay if actions don't involve existing words.");
    }

    for (var actionId in currentActions.keys) {
      if (!prevActions.containsKey(actionId)) {
        // This is a new action
        final action = currentActions[actionId] as Map<String, dynamic>;
        final actionType = action['type'] as String?;
        print("🆕 ");
        print("🆕 ");
        print("🆕 New action detected: $actionId, Type: $actionType");
        print("🆕 action = $action");
        print("🆕 ");
        print("🆕 ");

        if (actionType == 'STEAL_WORD' ||
            actionType == 'OWN_WORD_IMPROVEMENT') {
          print(
              "✅✅✅ TRANSFORMATION DETECTED by _checkForWordTransformations: $actionType for Action ID: $actionId.");

          final originalWordId = action['originalWordId'] as String?;
          final newWordId = action['wordId'] as String?;
          final transformingPlayerId = action['playerId'] as String?;

          if (originalWordId == null ||
              newWordId == null ||
              transformingPlayerId == null) {
            print(
                "⚠️ Transformation action $actionId ($actionType) missing key IDs (originalWordId, newWordId, or playerId). Action details: $action");
            continue;
          }

          Map<String, dynamic>? originalWordData;
          try {
            originalWordData = prevWordsList.firstWhere(
              (w) => w['wordId'] == originalWordId,
            );
          } catch (e) {
            originalWordData = null;
            print(
                "⚠️ Original word $originalWordId not found in prevData for action $actionId. Error: $e");
          }

          if (originalWordData == null) {
            print(
                "⚠️ Original word $originalWordId not found in prevData for action $actionId. Cannot animate.");
            continue;
          }

          final fromPlayerId =
              originalWordData['current_owner_user_id'] as String?;

          // Get ALL tile IDs for the new word directly from the action.
          // ASSUMPTION: action['tileIds'] contains all tiles of the new word.
          final allNewWordTileIdsDynamic = action['tileIds'] as List<dynamic>? ?? [];
          final List<String> allNewWordTileIds = allNewWordTileIdsDynamic.map((id) => id.toString()).toList();

          if (allNewWordTileIds.isEmpty) {
            print("⚠️ Action $actionId ($actionType) 'tileIds' field (for the new word) is missing or empty. Cannot animate.");
            continue;
          }

          // Get tile IDs from the original word to differentiate.
          final originalWordTileIdsDynamic = originalWordData['tileIds'] as List<dynamic>? ?? [];
          final List<String> originalWordTileIds = originalWordTileIdsDynamic.map((id) => id.toString()).toList();

          if (fromPlayerId == null) {
            print(
                "⚠️ Original word $originalWordId data missing 'current_owner_user_id'. Cannot determine fromPlayerId.");
            continue;
          }
          if (originalWordTileIds.isEmpty) {
            // This condition checks if the original word had any tiles.
            // It's okay if it's empty if allNewWordTileIds is populated (e.g., an improvement using only middle tiles).
            print("ℹ️ Original word $originalWordId had no tiles or 'tileIds' was empty. Animating based on action['tileIds'] for new word $newWordId.");
          }

          // Capture positions for any tiles in allNewWordTileIds that are NOT from originalWordTileIds (i.e., from middle for this action)
          Map<String, Offset> currentActionOverrideStartPositions = {};
          Map<String, Size> currentActionOverrideStartSizes = {};
          final overlayRenderObjectForCapture = Overlay.of(context)?.context.findRenderObject();

          if (overlayRenderObjectForCapture != null) {
            for (String tileIdToCapture in allNewWordTileIds) {
              if (!originalWordTileIds.contains(tileIdToCapture)) { // Tile is new (from middle) for this action
                final key = _tileGlobalKeys[tileIdToCapture];
                if (key != null && key.currentContext != null && key.currentContext!.mounted) {
                  final box = key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize && box.attached) {
                    try {
                      final pos = box.localToGlobal(Offset.zero, ancestor: overlayRenderObjectForCapture);
                      final size = box.size;
                      currentActionOverrideStartPositions[tileIdToCapture] = pos;
                      currentActionOverrideStartSizes[tileIdToCapture] = size;
                      if (currentUserId == transformingPlayerId) { // Log specifically for the local player
                        print("📸 LOCAL PLAYER ($actionType): Captured override for middle tile $tileIdToCapture: Pos=$pos, Size=$size. Key context: ${key.currentContext}");
                      }
                    } catch (e) { 
                      if (currentUserId == transformingPlayerId) {
                        print("📸 LOCAL PLAYER ($actionType): ERROR capturing override for $tileIdToCapture: $e");
                      } else {
                        print("Error capturing immediate middle pos for $tileIdToCapture during $actionType: $e");
                      }
                    }
                  } else {
                    if (currentUserId == transformingPlayerId) {
                        print("📸 LOCAL PLAYER ($actionType): RenderBox null/invalid for middle tile $tileIdToCapture. Key: $key, Context: ${key.currentContext}");
                    }
                  }
                } else {
                  if (currentUserId == transformingPlayerId) {
                      print("📸 LOCAL PLAYER ($actionType): GlobalKey or context null/unmounted for middle tile $tileIdToCapture.");
                  }
                }
              }
            }
          }
          if (!_destinationWordIdsForAnimation.contains(newWordId)) {
            print("Scheduling animation for $newWordId from $originalWordId");
            _sourceWordIdsForAnimation.add(originalWordId);
            _destinationWordIdsForAnimation.add(newWordId);
            animationScheduledThisCheck = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startStealAnimation(
                  originalWordId: originalWordId,
                  newWordId: newWordId,
                  tileIds: allNewWordTileIds, // Animate ALL tiles of the new word
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
          print(
              "✅✅✅ TRANSFORMATION DETECTED by _checkForWordTransformations: $actionType for Action ID: $actionId.");
              
          final newWordId = action['wordId'] as String?;
          final playerId = action['playerId'] as String?;
          final tileIdsDynamic = action['tileIds'] as List<dynamic>? ?? [];
          final List<String> tileIds =
              tileIdsDynamic.map((id) => id.toString()).toList();

          if (newWordId == null || playerId == null || tileIds.isEmpty) {
            print(
                "⚠️ Transformation action $actionId ($actionType) missing key IDs (newWordId, playerId, or tileIds). Action details: $action");
            continue;
          }
          
          if (!_destinationWordIdsForAnimation.contains(newWordId)) {
            print("Scheduling animation for new middle word $newWordId");
            
            // --- CAPTURE MIDDLE TILE POSITIONS NOW ---
            // These are the actual starting positions for tiles coming from the middle.
            Map<String, Offset> currentMiddleTileStartPositions = {};
            Map<String, Size> currentMiddleTileStartSizes = {};
            final overlayRenderObjectForCapture = Overlay.of(context)?.context.findRenderObject();

            if (overlayRenderObjectForCapture != null) {
              for (String tileIdToCapture in tileIds) {
                final key = _tileGlobalKeys[tileIdToCapture];
                if (key != null && key.currentContext != null && key.currentContext!.mounted) {
                  final box = key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize && box.attached) {
                    try {
                      currentMiddleTileStartPositions[tileIdToCapture] = box.localToGlobal(Offset.zero, ancestor: overlayRenderObjectForCapture);
                      currentMiddleTileStartSizes[tileIdToCapture] = box.size;
                      // print("📸 Captured immediate middle pos for $tileIdToCapture: ${currentMiddleTileStartPositions[tileIdToCapture]}");
                    } catch (e) { print("Error capturing immediate middle pos for $tileIdToCapture: $e");}
                  }
                }
              }
            }
            // --- END CAPTURE ---

            _destinationWordIdsForAnimation.add(newWordId);
            animationScheduledThisCheck = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startStealAnimation(
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
      // 1. processPlayerWords uses the updated _sourceWordIdsForAnimation and _destinationWordIdsForAnimation.
      //    - Source words come from _previousGameData.
      //    - Destination words come from currentData but are marked as placeholders.
      // 2. PlayerWords renders placeholders for destination words, making their GlobalKeys available.
      // The _startStealAnimation (post-frame) will then correctly find these keys.
      // _capturePreviousTileMetrics (called at the start of the build) will have captured metrics
      // from the state *before* this rebuild, which is what the animation needs for start positions.
      setState(() {});
    }
    print(
        "👀 Finished _checkForWordTransformations (formerly _checkForStolenWords)");
  }
}
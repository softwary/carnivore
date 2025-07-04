import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/classes/game_data_provider.dart';
import 'package:flutter_frontend/controllers/game_controller_state.dart';

final gameControllerProvider = StateNotifierProvider.autoDispose
    .family<GameController, GameControllerState, String>(
  (ref, gameId) => GameController(ref, gameId),
);

class GameController extends StateNotifier<GameControllerState> {
  final Ref _ref;
  final String _gameId;
  final ApiService _apiService;

  GameController(this._ref, this._gameId)
      : _apiService = ApiService(),
        super(GameControllerState());

  Map<String, dynamic>? get _gameData =>
      _ref.read(gameDataProvider(_gameId)).asData?.value;

  List<Tile> get _allTiles {
    final game = _gameData;
    if (game == null) return [];
    final rawTiles = game['tiles'] as List<dynamic>?;
    if (rawTiles == null) return [];
    return rawTiles
        .cast<Map<String, dynamic>>()
        .map((item) => Tile.fromMap(item))
        .toList();
  }

  void clearInput() {
    state = state.copyWith(
      inputtedLetters: [],
      officiallySelectedTileIds: {},
      potentiallySelectedTileIds: {},
    );
  }

  void handleBackspace() {
    if (state.inputtedLetters.isEmpty) return;

    var newInputtedLetters = List<Tile>.from(state.inputtedLetters);
    var newOfficialIds = Set<String>.from(state.officiallySelectedTileIds);
    var newPotentialIds = Set<String>.from(state.potentiallySelectedTileIds);
    // usedTileIds are generally not directly affected by backspace unless a tile becomes available again.
    // For simplicity, we are not re-adding to usedTileIds on backspace here.

    final lastTile = newInputtedLetters.removeLast();

    if (lastTile.tileId == "TBD") {
      final String backspacedLetter = lastTile.letter!;
      // Find the first occurrence of this letter in potentiallySelectedTileIds and remove it
      // This logic needs to be careful if multiple "TBD" for the same letter exist.
      // The original logic tried to find *a* tile to unhighlight.
      // A more robust way might be to track which potential tile was associated with which "TBD" input.
      // For now, let's replicate the simpler unhighlighting:
      final allTilesData = _allTiles; // Fetch once
      String? tileIdToRemoveFromPotential;
      for (final tileIdStr in newPotentialIds) {
        final tile = allTilesData.firstWhere(
          (t) =>
              t.tileId.toString() == tileIdStr && t.letter == backspacedLetter,
          orElse: () =>
              Tile(letter: '', tileId: '', location: ''), // Placeholder
        );
        if (tile.tileId.toString().isNotEmpty) {
          tileIdToRemoveFromPotential = tile.tileId.toString();
          break;
        }
      }
      if (tileIdToRemoveFromPotential != null) {
        newPotentialIds.remove(tileIdToRemoveFromPotential);
      }
    } else {
      newOfficialIds.remove(lastTile.tileId.toString());
      newPotentialIds.remove(lastTile.tileId.toString());
      // If a specific tile is unselected, it might become available again.
      // We could remove it from usedTileIds if it was added upon selection.
      // state.usedTileIds.remove(lastTile.tileId.toString()); // Consider this
    }

    state = state.copyWith(
      inputtedLetters: newInputtedLetters,
      officiallySelectedTileIds: newOfficialIds,
      potentiallySelectedTileIds: newPotentialIds,
    );
  }

  void handleTileSelection(Tile tile, bool isSelected) {
    var newInputtedLetters = List<Tile>.from(state.inputtedLetters);
    var newOfficialIds = Set<String>.from(state.officiallySelectedTileIds);

    if (isSelected) {
      if (!newInputtedLetters
          .any((inputtedTile) => inputtedTile.tileId == tile.tileId)) {
        newOfficialIds.add(tile.tileId.toString());
        newInputtedLetters.add(tile);
      }
    } else {
      newOfficialIds.remove(tile.tileId.toString());
      newInputtedLetters
          .removeWhere((inputtedTile) => inputtedTile.tileId == tile.tileId);
    }
    state = state.copyWith(
      inputtedLetters: newInputtedLetters,
      officiallySelectedTileIds: newOfficialIds,
    );
  }

  void handleLetterTyped(String letter) {
    var newInputtedLetters = List<Tile>.from(state.inputtedLetters);
    var newOfficialIds = Set<String>.from(state.officiallySelectedTileIds);
    var newPotentialIds = Set<String>.from(state.potentiallySelectedTileIds);
    final currentAllTiles = _allTiles; // Cache for multiple uses

    newInputtedLetters
        .add(Tile(letter: letter.toUpperCase(), tileId: 'TBD', location: ''));

    final tilesWithThisLetter = _findAvailableTilesWithThisLetter(
      letter.toUpperCase(),
      currentAllTiles,
      newInputtedLetters, // Pass current state of letters being built
      newOfficialIds,
    );

    if (tilesWithThisLetter.isEmpty) {
      _assignLetterToThisTileId(letter.toUpperCase(), "invalid",
          newInputtedLetters, newOfficialIds, newPotentialIds, currentAllTiles);
    } else if (tilesWithThisLetter.length == 1) {
      var tileId = tilesWithThisLetter
          .firstWhere(
            (tile) =>
                !newInputtedLetters.any(
                    (inputtedTile) => inputtedTile.tileId == tile.tileId) &&
                !newOfficialIds.contains(tile.tileId),
            orElse: () => Tile(letter: '', tileId: 'invalid', location: ''),
          )
          .tileId
          .toString();
      // Ensure it's not already "officially" part of the current word via another letter
      // or directly selected.
      if (newOfficialIds.contains(tileId.toString()) ||
          newInputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tileId)) {
        tileId = "invalid";
      }
      _assignLetterToThisTileId(letter.toUpperCase(), tileId,
          newInputtedLetters, newOfficialIds, newPotentialIds, currentAllTiles);
    } else {
      // Multiple options, try to assign intelligently
      _assignTileId(letter.toUpperCase(), tilesWithThisLetter,
          newInputtedLetters, newOfficialIds, newPotentialIds, currentAllTiles);
    }

    // This part models the old setState block for potentialMatches and potentiallySelectedTileIds
    final potentialMatchIds =
        tilesWithThisLetter.map((t) => t.tileId.toString()).toList();

    if (newInputtedLetters.length > 1) {
      // If more than one letter typed, all tiles matching the current letter are initially potential.
      newPotentialIds.addAll(potentialMatchIds);
      // Then, refine. _refinePotentialMatches will ultimately set newPotentialIds based on official assignments.
      _refinePotentialMatches(
        _gameData,
        newInputtedLetters,
        newOfficialIds,
        newPotentialIds,
        currentAllTiles,
      );
    }
    state = state.copyWith(
      inputtedLetters: newInputtedLetters,
      officiallySelectedTileIds: newOfficialIds,
      potentiallySelectedTileIds: newPotentialIds,
    );
  }

  Future<Map<String, dynamic>> submitCurrentWord() async {
    final currentInputtedLetters = List<Tile>.from(state.inputtedLetters);

    if (currentInputtedLetters.length < 3) {
      return {
        'success': false,
        'submission_type': 'INVALID_LENGTH_CLIENT',
        'message': 'Word must be at least 3 letters long.'
      };
    }

    List<Tile> tilesForSubmission = [];
    final currentAllTiles = _allTiles; // Cache

    for (var tile in currentInputtedLetters) {
      String location = _findTileLocation(tile.tileId, currentAllTiles);
      dynamic finalTileId = tile.tileId;

      if (tile.tileId == "TBD" || tile.tileId == "invalid") {
        return {
          'success': false,
          'submission_type': 'INVALID_TILE_STATE_CLIENT',
          'message': 'Invalid tile (TBD/invalid) in selection.'
        };
      }

      if (tile.tileId is String) {
        int? parsedId = int.tryParse(tile.tileId as String);
        if (parsedId != null) {
          finalTileId = parsedId;
        } else {
          return {
            'success': false,
            'submission_type': 'INVALID_TILE_ID_FORMAT_CLIENT',
            'message': 'Invalid tile ID format for submission: ${tile.tileId}.'
          };
        }
      } else if (tile.tileId is! int) {
        return {
          'success': false,
          'submission_type': 'UNEXPECTED_TILE_ID_TYPE_CLIENT',
          'message': 'Unexpected tile ID type: ${tile.tileId}.'
        };
      }
      tilesForSubmission.add(
          Tile(letter: tile.letter, location: location, tileId: finalTileId));
    }

    final game = _gameData;
    if (game == null) {
      return {
        'success': false,
        'submission_type': 'NO_GAME_DATA_CLIENT',
        'message': 'Game data not available for validation.'
      };
    }

    final distinctLocations =
        tilesForSubmission.map((tile) => tile.location).toSet();
    if (distinctLocations.length > 1 && !distinctLocations.contains('middle')) {
      return {
        'success': false,
        'submission_type': 'INVALID_MULTI_WORD_NO_MIDDLE_CLIENT',
        'message':
            "You can't use letters from multiple words without using the middle."
      };
    } else if (distinctLocations.length > 1) {
      final wordIdLocation = distinctLocations.firstWhere(
        (loc) => loc != 'middle' && loc != null && loc.isNotEmpty,
        orElse: () => '',
      );
      if (wordIdLocation?.isNotEmpty == true) {
        final wordDataList = game['words'] as List<dynamic>?;
        final wordData = wordDataList?.firstWhere(
          (w) => w is Map && w['wordId'] == wordIdLocation,
          orElse: () => null, // Corrected orElse
        );
        if (wordData != null && wordData is Map) {
          final wordTileIds = wordData['tileIds'] as List<dynamic>? ?? [];
          final wordLength = wordTileIds.length;
          final inputtedLettersFromWord = tilesForSubmission
              .where((t) => t.location == wordIdLocation)
              .length;
          if (inputtedLettersFromWord != wordLength) {
            return {
              'success': false,
              'submission_type': 'INVALID_PARTIAL_WORD_STEAL_CLIENT',
              'message':
                  "You must use the entire word or none of it when stealing."
            };
          }
        } else {
          // Could not find the word data for validation, might be an issue or a new word from middle.
          // If it's a new word from middle, this branch shouldn't be hit if distinctLocations.contains('middle')
        }
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return {
        'success': false,
        'submission_type': 'NO_AUTH_USER_CLIENT',
        'message': 'User not authenticated.'
      };
    final token = await user.getIdToken();
    if (token == null)
      return {
        'success': false,
        'submission_type': 'NO_AUTH_TOKEN_CLIENT',
        'message': 'Failed to get auth token.'
      };

    try {
      final response =
          await _apiService.sendTileIds(_gameId, token, tilesForSubmission);
      final responseData = jsonDecode(response.body);
      final submissionType = responseData['submission_type'] as String?;
      final submittedWord = responseData['word'] as String?;

      if (response.statusCode == 200) {
        clearInput(); // Clear controller's input state on successful processing by backend

        final validTypes = [
          "VALID_SUBMISSION",
          "STEAL_WORD",
          "MIDDLE_WORD",
          "OWN_WORD_IMPROVEMENT"
        ];
        if (submissionType != null && validTypes.contains(submissionType)) {
          return {
            'success': true,
            'submission_type': submissionType,
            'word': submittedWord
          };
        } else {
          String errorMessage = responseData['message'] as String? ??
              "Submission failed: $submissionType";
          // Use backend's specific error messages if available
          if (submissionType == "INVALID_LENGTH")
            errorMessage = "$submittedWord was too short";
          else if (submissionType == "INVALID_NO_MIDDLE")
            errorMessage =
                "$submittedWord did not use a letter from the middle";
          else if (submissionType == "INVALID_WORD_NOT_IN_DICTIONARY")
            errorMessage = "$submittedWord is not in the dictionary";

          return {
            'success': false,
            'submission_type': submissionType ?? 'UNKNOWN_ERROR_CLIENT',
            'word': submittedWord,
            'message': errorMessage
          };
        }
      } else {
        // Don't clear input if backend returns non-200, so user can retry/fix.
        return {
          'success': false,
          'submission_type': 'HTTP_ERROR_CLIENT',
          'message':
              'Error: ${response.statusCode} - ${responseData['message'] ?? response.body}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'submission_type': 'EXCEPTION_CLIENT',
        'message': 'Exception: ${e.toString()}'
      };
    }
  }

  List<Tile> _findAvailableTilesWithThisLetter(
    String letter,
    List<Tile> allTilesData,
    List<Tile> currentInputtedLetters,
    Set<String> currentOfficialIds,
  ) {
    return allTilesData.where((tile) {
      return tile.letter == letter &&
          !currentInputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tile.tileId) &&
          !currentOfficialIds.contains(tile.tileId);
    }).toList();
  }

  void _assignLetterToThisTileId(
    String letter,
    String tileId, // This is the ID of the tile from _allTiles to assign
    List<Tile> currentInputtedLetters, // Mutable list
    Set<String> currentOfficialIds, // Mutable set
    Set<String> currentPotentialIds, // Mutable set
    List<Tile> allTilesData,
  ) {
    // Find the last "TBD" tile for this letter and update it.
    // If no "TBD" tile, this function might have been called incorrectly,
    // or the logic needs to handle adding a new tile if one wasn't pre-added.
    // Assuming a "TBD" tile for `letter` was just added to `currentInputtedLetters`.

    int tbdIndex = currentInputtedLetters
        .lastIndexWhere((t) => t.tileId == 'TBD' && t.letter == letter);

    if (tileId != "TBD" && tileId != "invalid") {
      final tileData = allTilesData.firstWhere(
        (t) => t.tileId.toString() == tileId,
        orElse: () => Tile(
            letter: '',
            tileId: '',
            location: ''), // Should not happen if tileId is valid
      );
      // make sure we have a string ID before we check for emptiness
      final foundTileId = tileData.tileId?.toString() ?? '';
      if (foundTileId.isNotEmpty) {
        if (tbdIndex != -1) {
          currentInputtedLetters[tbdIndex] = Tile(
            letter: letter,
            tileId: foundTileId,
            location: tileData.location,
          );
        } else {
          // This case implies no TBD tile was found, which is unexpected if called after adding one.
          // For robustness, could add new if not found, but implies logic error elsewhere.
          currentInputtedLetters.add(Tile(
              letter: letter, tileId: tileId, location: tileData.location));
        }
        currentOfficialIds.add(tileId);
        currentPotentialIds.add(tileId); // Also mark as potential if assigned
      }
    } else if (tileId == "invalid") {
      if (tbdIndex != -1) {
        currentInputtedLetters[tbdIndex] =
            Tile(letter: letter, tileId: "invalid", location: '');
      } else {
        currentInputtedLetters
            .add(Tile(letter: letter, tileId: "invalid", location: ''));
      }
    }
  }

  void _assignTileId(
    String letter,
    List<Tile> tilesWithThisLetter, // Available tiles for this letter
    List<Tile> currentInputtedLetters, // Mutable
    Set<String> currentOfficialIds, // Mutable
    Set<String> currentPotentialIds, // Mutable
    List<Tile> allTilesData,
  ) {
    // This logic tries to find the "best" tile to assign if multiple are available.
    // Prefers middle tiles.

    // Find the "TBD" tile that was just added for `letter`.
    int tbdIndex = currentInputtedLetters
        .lastIndexWhere((t) => t.tileId == 'TBD' && t.letter == letter);
    if (tbdIndex == -1) return; // Should not happen

    Tile? tileToAssign;

    // Try to find a middle tile first
    tileToAssign = tilesWithThisLetter.firstWhere(
      (t) =>
          t.location == 'middle' &&
          !currentOfficialIds.contains(t.tileId.toString()),
      orElse: () => Tile(letter: '', tileId: '', location: ''),
    );

    // If no middle tile, find any other available tile
    if (tileToAssign.tileId.toString().isEmpty) {
      tileToAssign = tilesWithThisLetter.firstWhere(
        (t) => !currentOfficialIds.contains(t.tileId.toString()),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );
    }

    if (tileToAssign != null && tileToAssign.tileId.toString().isNotEmpty) {
      debugPrint(
          "🙊Assigning tile for letter $letter: tileId=${tileToAssign.tileId}, location=${tileToAssign.location}");
      currentInputtedLetters[tbdIndex] = Tile(
        letter: letter,
        tileId: tileToAssign.tileId,
        location: tileToAssign.location,
      );
      currentOfficialIds.add(tileToAssign.tileId.toString());
      currentPotentialIds.add(
          tileToAssign.tileId.toString()); // Also mark as potential initially
    } else {
      // No tile could be assigned (e.g., all are already used or official in current input)
      debugPrint("No assignable tile found for letter $letter");
      currentInputtedLetters[tbdIndex] =
          Tile(letter: letter, tileId: 'invalid', location: '');
    }
  }

  void _refinePotentialMatches(
    Map<String, dynamic>? gameData,
    List<Tile> currentInputtedLetters, // Mutable
    Set<String> currentOfficialIds, // Mutable
    Set<String> currentPotentialIds, // Mutable
    List<Tile> allTilesData,
  ) {
    if (gameData == null) return;
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    // final String typedWord = currentInputtedLetters.map((tile) => tile.letter).join();
    // final List<String> typedWordLetters = typedWord.split('');

    final bool allSelectedLettersHaveMiddleMatch = currentInputtedLetters
        .where((t) => t.tileId != 'TBD' && t.tileId != 'invalid')
        .every((tile) {
      final letter = tile.letter;
      if (letter != null) {
        return allTilesData.any((t) =>
            t.letter == letter &&
            t.location == 'middle' &&
            !currentOfficialIds.contains(t.tileId.toString()));
      }
      return false;
    });

    if (allSelectedLettersHaveMiddleMatch) {
      _reassignTilesToMiddle(
          currentInputtedLetters, currentOfficialIds, allTilesData);
    } else {
      final wordsList = (gameData['words'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final typedLettersCounts = <String, int>{};
      for (var tile in currentInputtedLetters) {
        if (tile.letter != null) {
          typedLettersCounts[tile.letter!] =
              (typedLettersCounts[tile.letter!] ?? 0) + 1;
        }
      }

      List<Map<String, dynamic>> matchingWords = [];
      for (var word in wordsList) {
        final String status = (word['status'] as String? ?? '').toLowerCase();
        if (!status.contains("valid")) continue;

        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
        final wordLettersCounts = <String, int>{};
        bool possible = true;
        for (var tileId in wordTileIds) {
          final tile = allTilesData.firstWhere(
              (t) => t.tileId.toString() == tileId,
              orElse: () => Tile(letter: null, tileId: '', location: ''));
          if (tile.letter == null) {
            possible = false;
            break;
          }
          wordLettersCounts[tile.letter!] =
              (wordLettersCounts[tile.letter!] ?? 0) + 1;
        }
        if (!possible) continue;

        bool isSubAnagram = true;
        for (var entry in wordLettersCounts.entries) {
          if ((typedLettersCounts[entry.key] ?? 0) < entry.value) {
            isSubAnagram = false;
            break;
          }
        }
        if (isSubAnagram) {
          matchingWords.add(word);
        }
      }

      if (matchingWords.isNotEmpty) {
        matchingWords.sort((a, b) {
          final aLength = (a['tileIds'] as List<dynamic>).length;
          final bLength = (b['tileIds'] as List<dynamic>).length;
          return bLength.compareTo(aLength); // Prefer longer words
        });

        final matchingWordToUse = matchingWords.firstWhere(
            (word) =>
                word['current_owner_user_id'] != userId, // Prefer stealing
            orElse: () => matchingWords.first); // Fallback to any match

        _reassignTilesToWord(matchingWordToUse['wordId'],
            currentInputtedLetters, currentOfficialIds, allTilesData, gameData);
      }
    }
    _syncTileIdsWithInputtedLetters(
        currentInputtedLetters, currentOfficialIds, allTilesData);
    // After reassignments, update potential IDs: they should be the official ones.
    currentPotentialIds.clear();
    currentPotentialIds.addAll(currentOfficialIds);
  }

  void _reassignTilesToMiddle(
    List<Tile> currentInputtedLetters, // Mutable
    Set<String> currentOfficialIds, // Mutable
    List<Tile> allTilesData,
  ) {
    final List<Tile> allMiddleTiles =
        allTilesData.where((tile) => tile.location == 'middle').toList();
    Set<String> usedMiddleTileIdsInThisReassignment = {};

    for (int i = 0; i < currentInputtedLetters.length; i++) {
      var selectedTile = currentInputtedLetters[i];
      if (selectedTile.tileId == 'TBD' || selectedTile.tileId == 'invalid')
        continue;

      final assignedTile = allTilesData.firstWhere(
        (tile) => tile.tileId.toString() == selectedTile.tileId.toString(),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );

      if (assignedTile.tileId.toString().isNotEmpty &&
          assignedTile.location == 'middle') {
        usedMiddleTileIdsInThisReassignment.add(assignedTile.tileId.toString());
        continue; // Already a middle tile, and it's now "taken" for this word
      }

      // If not a middle tile, or if it's a middle tile already used by another letter in this word
      final matchingMiddleTile = allMiddleTiles.firstWhere(
        (middleTile) =>
            middleTile.letter == selectedTile.letter &&
            !currentOfficialIds.contains(middleTile.tileId
                .toString()) && // Not already official for another input
            !usedMiddleTileIdsInThisReassignment.contains(middleTile.tileId
                .toString()), // Not used by *this* reassignment pass
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );

      if (matchingMiddleTile.tileId.toString().isNotEmpty) {
        currentOfficialIds
            .remove(selectedTile.tileId.toString()); // Remove old ID
        currentInputtedLetters[i] = Tile(
            letter: selectedTile.letter,
            tileId: matchingMiddleTile.tileId,
            location: 'middle');
        currentOfficialIds
            .add(matchingMiddleTile.tileId.toString()); // Add new ID
        usedMiddleTileIdsInThisReassignment
            .add(matchingMiddleTile.tileId.toString());
      }
    }
  }

  Map<String, dynamic>? _getWordDataFromGame(
      String wordId, Map<String, dynamic>? gameData) {
    if (gameData == null) return null;
    final wordsList = gameData['words'] as List<dynamic>?;
    if (wordsList == null) return null;
    try {
      return wordsList.firstWhere(
        (word) => word is Map && word['wordId'] == wordId,
        orElse: () => null, // Corrected orElse
      );
    } catch (e) {
      return null;
    }
  }

  void _reassignTilesToWord(
    String wordIdToStealFrom,
    List<Tile> currentInputtedLetters, // Mutable
    Set<String> currentOfficialIds, // Mutable
    List<Tile> allTilesData,
    Map<String, dynamic>? gameData,
  ) {
    final wordData = _getWordDataFromGame(wordIdToStealFrom, gameData);
    if (wordData == null) return;

    final List<String> tileIdsFromWordToSteal =
        (wordData['tileIds'] as List<dynamic>)
            .map((tileId) => tileId.toString())
            .toList();

    Set<String> usedTileIdsFromWordInThisReassignment = {};

    for (int i = 0; i < currentInputtedLetters.length; i++) {
      var selectedTile = currentInputtedLetters[i];
      if (selectedTile.tileId == 'TBD' || selectedTile.tileId == 'invalid')
        continue;

      final assignedTile = allTilesData.firstWhere(
        (tile) => tile.tileId.toString() == selectedTile.tileId.toString(),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );

      // If current tile is already from the target word and not yet claimed in this pass
      if (assignedTile.tileId.toString().isNotEmpty &&
          tileIdsFromWordToSteal.contains(assignedTile.tileId.toString()) &&
          !usedTileIdsFromWordInThisReassignment
              .contains(assignedTile.tileId.toString())) {
        usedTileIdsFromWordInThisReassignment
            .add(assignedTile.tileId.toString());
        continue;
      }

      // Find a matching tile from the target word that isn't already official or used in this pass
      final matchingWordTile = allTilesData.firstWhere(
        (tileFromWord) =>
            tileIdsFromWordToSteal.contains(tileFromWord.tileId.toString()) &&
            tileFromWord.letter == selectedTile.letter &&
            !currentOfficialIds.contains(tileFromWord.tileId.toString()) &&
            !usedTileIdsFromWordInThisReassignment
                .contains(tileFromWord.tileId.toString()),
        orElse: () => Tile(letter: '', tileId: '', location: ''),
      );

      if (matchingWordTile.tileId.toString().isNotEmpty) {
        currentOfficialIds.remove(selectedTile.tileId.toString()); // Remove old
        currentInputtedLetters[i] = Tile(
            letter: selectedTile.letter,
            tileId: matchingWordTile.tileId,
            location: matchingWordTile.location);
        currentOfficialIds.add(matchingWordTile.tileId.toString()); // Add new
        usedTileIdsFromWordInThisReassignment
            .add(matchingWordTile.tileId.toString());
      }
    }
  }

  void _syncTileIdsWithInputtedLetters(
      List<Tile> currentInputtedLetters, // Mutable
      Set<String> currentOfficialIds, // Mutable
      List<Tile> allTilesData) {
    currentOfficialIds.clear();
    Set<String> assignedTileIdsInSync = {};

    for (int i = 0; i < currentInputtedLetters.length; i++) {
      var tile = currentInputtedLetters[i];
      if (tile.tileId != 'TBD' && tile.tileId != 'invalid') {
        if (!assignedTileIdsInSync.contains(tile.tileId.toString())) {
          currentOfficialIds.add(tile.tileId.toString());
          assignedTileIdsInSync.add(tile.tileId.toString());
        } else {
          // Duplicate tileId found, try to reassign to another available tile with the same letter
          final alternativeTile = allTilesData.firstWhere(
            (t) =>
                t.letter == tile.letter &&
                !assignedTileIdsInSync.contains(t.tileId.toString()) &&
                // Optionally, consider location preference (e.g., from 'middle' or same original word)
                // For simplicity, just finding any available one for now.
                true,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          if (alternativeTile.tileId.toString().isNotEmpty) {
            currentInputtedLetters[i] = Tile(
                letter: tile.letter,
                tileId: alternativeTile.tileId,
                location: alternativeTile.location);
            currentOfficialIds.add(alternativeTile.tileId.toString());
            assignedTileIdsInSync.add(alternativeTile.tileId.toString());
          } else {
            // No alternative, mark as invalid or handle as error
            currentInputtedLetters[i] =
                Tile(letter: tile.letter, tileId: 'invalid', location: '');
          }
        }
      }
    }
  }

  String _findTileLocation(dynamic tileId, List<Tile> allTilesData) {
    if (tileId == null || tileId == 'TBD' || tileId == 'invalid') return '';
    try {
      return allTilesData
              .firstWhere(
                (t) => t.tileId.toString() == tileId.toString(),
                orElse: () => Tile(letter: '', tileId: '', location: ''),
              )
              .location ??
          '';
    } catch (e) {
      return '';
    }
  }
}

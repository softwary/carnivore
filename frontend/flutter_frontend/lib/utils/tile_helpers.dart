import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/screens/game_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

mixin TileHelpersMixin on ConsumerState<GameScreen> {
  GameScreenState get _gsState => this as GameScreenState;

  List<Tile> findAvailableTilesWithThisLetter(String letter) {
    // Access GameScreenState-specific members via _gsState
    final availableTiles = _gsState.allTiles.where((tile) {
      return tile.letter == letter &&
          !_gsState.inputtedLetters
              .any((inputtedTile) => inputtedTile.tileId == tile.tileId) &&
          !_gsState.officiallySelectedTileIds.contains(tile.tileId) &&
          !_gsState.usedTileIds.contains(tile.tileId);
    }).toList();
    return availableTiles;
  }

  void assignLetterToThisTileId(String letter, String tileId) {
    // setState is available directly from ConsumerState
    setState(() {
      if (tileId != "TBD" && tileId != "invalid") {
        _gsState.officiallySelectedTileIds.add(tileId);
        _gsState.inputtedLetters.removeLast();
        final newTileLocation = _gsState.allTiles
            .firstWhere(
              (t) => t.tileId.toString() == tileId,
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            )
            .location;
        final newTile =
            Tile(letter: letter, tileId: tileId, location: newTileLocation);
        _gsState.inputtedLetters.add(newTile);
        _gsState.officiallySelectedTileIds.add(tileId);
      } else {
        if (tileId == "invalid") {
          _gsState.inputtedLetters.removeLast();
          _gsState.inputtedLetters
              .add(Tile(letter: letter, tileId: tileId, location: ''));
        }
      }
    });
  }

  void assignTileId(String letter, List<Tile> tilesWithThisLetter) {
    if (tilesWithThisLetter.length == 1) {
      final tileId = tilesWithThisLetter.first.tileId.toString();
      setState(() {
        _gsState.inputtedLetters.removeLast();
        _gsState.inputtedLetters.add(Tile(letter: letter, tileId: tileId, location: ''));
        _gsState.potentiallySelectedTileIds.add(tileId);
        _gsState.officiallySelectedTileIds.add(tileId);
      });
      return;
    }
    final Set<String> currentUsedTileIds = _gsState.inputtedLetters
        .where((tile) => tile.tileId != 'TBD')
        .map((tile) => tile.tileId.toString())
        .toSet();

    for (var selectedTile in _gsState.inputtedLetters) {
      if (selectedTile.tileId == 'TBD' && selectedTile.letter == letter) {
        final tile = tilesWithThisLetter.firstWhere(
          (tile) =>
              tile.location == 'middle' &&
              !currentUsedTileIds.contains(tile.tileId.toString()),
          orElse: () => Tile(letter: '', tileId: '', location: ''),
        );

        final tileId = tile.tileId?.toString();
        if (tileId != null && tileId.isNotEmpty) {
          setState(() {
            selectedTile.tileId = tileId;
            currentUsedTileIds.add(tileId);
            _gsState.officiallySelectedTileIds.add(tileId);
          });
        } else {
          final fallbackTile = tilesWithThisLetter.firstWhere(
            (tile) => !currentUsedTileIds.contains(tile.tileId.toString()),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );

          final fallbackTileId = fallbackTile.tileId?.toString();
          if (fallbackTileId != null && fallbackTileId.isNotEmpty) {
            setState(() {
              selectedTile.tileId = fallbackTileId;
              currentUsedTileIds.add(fallbackTileId);
              _gsState.officiallySelectedTileIds.add(fallbackTileId);
            });
          } else {
            setState(() {
              selectedTile.tileId = 'invalid';
            });
          }
        }
      }
    }
  }

  void reassignTilesToMiddle() {
    final List<Tile> allMiddleTiles =
        _gsState.allTiles.where((tile) => tile.location == 'middle').toList();
    if (_gsState.inputtedLetters.every((tile) {
      final tileId = tile.tileId;
      if (tileId != 'TBD' && tileId != 'invalid') {
        final t = _gsState.allTiles.firstWhere(
          (t) => t.tileId.toString() == tileId,
          orElse: () => Tile(letter: '', tileId: '', location: ''),
        );
        return t.tileId != '' && t.location == 'middle';
      }
      return false;
    })) {
      return;
    }
    setState(() {
      for (var selectedTile in _gsState.inputtedLetters) {
        if (selectedTile.tileId != 'TBD' && selectedTile.tileId != 'invalid') {
          final assignedTile = _gsState.allTiles.firstWhere(
            (tile) => tile.tileId.toString() == selectedTile.tileId,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          if (assignedTile.tileId != '' && assignedTile.location == 'middle') {
            continue;
          }

          if (assignedTile.tileId != '' && assignedTile.location != 'middle') {
            final matchingMiddleTile = allMiddleTiles.firstWhere(
              (middleTile) =>
                  middleTile.letter == selectedTile.letter &&
                  !_gsState.inputtedLetters.any(
                      (tile) => tile.tileId == middleTile.tileId.toString()),
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );

            if (matchingMiddleTile.tileId != '') {
              _gsState.officiallySelectedTileIds.remove(selectedTile.tileId);
              selectedTile.tileId = matchingMiddleTile.tileId.toString();
              _gsState.officiallySelectedTileIds
                  .add(matchingMiddleTile.tileId.toString());
            }
          }
        }
      }
    });
  }

  Map<String, dynamic>? getWordDataFromGame(
      Map<String, dynamic> gameData, String wordId) {
    final wordsList = gameData['words'] as List<dynamic>?;
    if (wordsList == null) return null;
    try {
      return wordsList.firstWhere(
        (word) => word['wordId'] == wordId,
      );
    } catch (e) {
      return null;
    }
  }

  void reassignTilesToWord(Map<String, dynamic> gameData, String wordId) {
    final word = getWordDataFromGame(gameData, wordId);
    if (word == null) {
      return;
    }
    final List<String> tileIdsFromWord = (word['tileIds'] as List<dynamic>)
        .map((tileId) => tileId.toString())
        .toList();

    setState(() {
      for (var selectedTile in _gsState.inputtedLetters) {
        if (selectedTile.tileId != 'TBD' && selectedTile.tileId != 'invalid') {
          final assignedTile = _gsState.allTiles.firstWhere(
            (tile) => tile.tileId.toString() == selectedTile.tileId,
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );
          if (assignedTile.tileId != '' &&
              tileIdsFromWord.contains(assignedTile.tileId.toString())) {
            continue;
          }

          final matchingWordTile = _gsState.allTiles.firstWhere(
            (tile) =>
                tileIdsFromWord.contains(tile.tileId.toString()) &&
                tile.letter == selectedTile.letter &&
                !_gsState.inputtedLetters.any((inputtedTile) =>
                    inputtedTile.tileId == tile.tileId.toString()),
            orElse: () => Tile(letter: '', tileId: '', location: ''),
          );

          if (matchingWordTile.tileId != '') {
            _gsState.officiallySelectedTileIds.remove(selectedTile.tileId);
            selectedTile.tileId = matchingWordTile.tileId.toString();
            _gsState.officiallySelectedTileIds.add(matchingWordTile.tileId.toString());
          }
        }
      }
    });
    syncTileIdsWithInputtedLetters(); // This method itself will use _gsState for its members
  }

  void syncTileIdsWithInputtedLetters() {
    Set<String> assignedTileIds = {};
    setState(() {
      _gsState.officiallySelectedTileIds.clear();
      for (var tile in _gsState.inputtedLetters) {
        if (tile.tileId != 'TBD' && tile.tileId != 'invalid') {
          if (!assignedTileIds.contains(tile.tileId)) {
            assignedTileIds.add(tile.tileId);
            _gsState.officiallySelectedTileIds.add(tile.tileId);
          } else {
            final availableTile = _gsState.allTiles.firstWhere(
              (t) =>
                  t.letter == tile.letter &&
                  !assignedTileIds.contains(t.tileId.toString()),
              orElse: () => Tile(letter: '', tileId: '', location: ''),
            );
            if (availableTile.tileId != '') {
              tile.tileId = availableTile.tileId.toString();
              assignedTileIds.add(tile.tileId);
              _gsState.officiallySelectedTileIds.add(tile.tileId);
            }
          }
        }
      }
    });
  }

  void refinePotentialMatches(Map<String, dynamic> gameData) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final String typedWord = _gsState.inputtedLetters.map((tile) => tile.letter).join();
    final List<String> typedWordLetters = typedWord.split('');

    final bool allSelectedLettersHaveMiddleMatch =
        _gsState.inputtedLetters.every((tile) {
      final letter = tile.letter;
      if (letter != null) {
        return _gsState.allTiles
            .where((t) => t.letter == letter && t.location == 'middle')
            .isNotEmpty;
      }
      return false;
    });

    if (allSelectedLettersHaveMiddleMatch) {
      reassignTilesToMiddle();
    } else {
      debugPrint("❌ Not all selected letters have a middle match");
      final wordsList = gameData['words'] as List<dynamic>? ?? [];
      final matchingWords = wordsList.where((word) {
        final String status = (word['status'] as String? ?? '').toLowerCase();
        if (!status.contains("valid")) {
          return false;
        }
        final List<String> wordTileIds = (word['tileIds'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
        final String wordString = wordTileIds.map((tileId) {
          return _gsState.allTiles
              .firstWhere((t) => t.tileId.toString() == tileId,
                  orElse: () => Tile(letter: '', tileId: '', location: ''))
              .letter;
        }).join();

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
        return isContained;
      }).toList();

      if (matchingWords.isNotEmpty) {
        matchingWords.sort((a, b) {
         final aLength = (a['tileIds'] as List<dynamic>).length;
         final bLength = (b['tileIds'] as List<dynamic>).length;
         return bLength.compareTo(aLength);
        });

        final matchingWordToUse = matchingWords.firstWhere(
            (word) => word['current_owner_user_id'] != userId,
            orElse: () => matchingWords.first);
        reassignTilesToWord(gameData, matchingWordToUse['wordId']);
      }
      syncTileIdsWithInputtedLetters();
    }
  }

  String findTileLocation(dynamic tileId) {
    return _gsState.allTiles
            .firstWhere((t) => t.tileId.toString() == tileId.toString(), // Ensure tileId is string for comparison
                orElse: () => Tile(letter: '', tileId: '', location: ''))
            .location ??
        '';
  }
}
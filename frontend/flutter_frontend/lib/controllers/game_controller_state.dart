import 'package:flutter_frontend/classes/tile.dart';

class GameControllerState {
  final List<Tile> inputtedLetters;
  final Set<String> officiallySelectedTileIds;
  final Set<String> potentiallySelectedTileIds;
  final Set<String> usedTileIds;
  // Add other relevant game state properties here as you expand the controller

  GameControllerState({
    this.inputtedLetters = const [],
    this.officiallySelectedTileIds = const {},
    this.potentiallySelectedTileIds = const {},
    this.usedTileIds = const {},
  });

  GameControllerState copyWith({
    List<Tile>? inputtedLetters,
    Set<String>? officiallySelectedTileIds,
    Set<String>? potentiallySelectedTileIds,
    Set<String>? usedTileIds,
  }) {
    return GameControllerState(
      inputtedLetters: inputtedLetters ?? this.inputtedLetters,
      officiallySelectedTileIds:
          officiallySelectedTileIds ?? this.officiallySelectedTileIds,
      potentiallySelectedTileIds:
          potentiallySelectedTileIds ?? this.potentiallySelectedTileIds,
      usedTileIds: usedTileIds ?? this.usedTileIds,
    );
  }
}
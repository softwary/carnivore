import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/services/api_service.dart';

/// Represents the current authentication and join-game state.
class GameAuthState {
  final bool isLoading;
  final bool showAuthDialog;
  final bool isJoined;
  final String? username;
  final String? error;

  const GameAuthState({
    this.isLoading = false,
    this.showAuthDialog = false,
    this.isJoined = false,
    this.username,
    this.error,
  });

  GameAuthState copyWith({
    bool? isLoading,
    bool? showAuthDialog,
    bool? isJoined,
    String? username,
    String? error,
  }) {
    return GameAuthState(
      isLoading: isLoading ?? this.isLoading,
      showAuthDialog: showAuthDialog ?? this.showAuthDialog,
      isJoined: isJoined ?? this.isJoined,
      username: username ?? this.username,
      error: error ?? this.error,
    );
  }
}

/// A StateNotifier that handles login/sign-up, displayName prompts, and joining a game.
class GameAuthController extends StateNotifier<GameAuthState> {
  final Ref _ref;
  final ApiService _api;

  GameAuthController(this._ref)
      : _api = ApiService(),
        super(const GameAuthState());

  /// Initialize: check Firebase currentUser and ensure displayName is set.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        showAuthDialog: true,
      );
      return;
    }
    final displayName = user.displayName?.trim();
    if (displayName == null || displayName.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        showAuthDialog: true,
      );
      return;
    }
    state = state.copyWith(
      isLoading: false,
      username: displayName,
    );
  }

  /// Call this after user logs in / signs up via dialog
  Future<void> updateUsername(String newName) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.updateDisplayName(newName);
      await user.reload();
      state = state.copyWith(username: newName, showAuthDialog: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Attempt to join game via API
  Future<void> joinGame(String gameId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      await _api.joinGameApi(
        gameId: gameId,
        token: token!,
        username: state.username!,
        onGameNotFound: () {
          state = state.copyWith(error: "Game not found", isLoading: false);
        },
      );
      state = state.copyWith(isJoined: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final gameAuthControllerProvider =
    StateNotifierProvider<GameAuthController, GameAuthState>((ref) {
  final controller = GameAuthController(ref);
  // start loading immediately
  controller.initialize();
  return controller;
});

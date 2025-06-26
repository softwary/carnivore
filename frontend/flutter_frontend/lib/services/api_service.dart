import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/config.dart';
import 'package:flutter_frontend/classes/tile.dart';

class ApiService {
  Future<String?> playComputerApi({
    required String token,
    required String username,
  }) async {
    final url = Uri.parse('${Config.backendUrl}/play-computer');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        final String gameId = data['game_id'];
        return gameId;
      }
    } catch (e) {
      // Handle error, perhaps log it
      print('Exception during playComputer: $e');
      return null;
    }
  }

  Future<String?> joinGameApi({
    required String gameId,
    required String token,
    required String username,
    required Function onGameNotFound,
  }) async {
    if (gameId.isEmpty) return null;
    final url = Uri.parse('${Config.backendUrl}/join-game');
    final payload = {'game_id': gameId, 'username': username};
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      // Return the gameId on success so navigation can occur.
      return gameId;
    }

    if (response.statusCode == 404 ||
        response.body.contains("not found") ||
        response.body.contains("doesn't exist")) {
      onGameNotFound();
      return null;
    } else {
      throw Exception(
          'Error joining game: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<String?> createGameApi(String token,
      {required String username}) async {
    final url = Uri.parse('${Config.backendUrl}/create-game');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username, 'game_type': 'regular'}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        final String gameId = data['game_id'];
        return gameId;
      } else {
        // Handle error, perhaps log it or throw a more specific exception
        print('Failed to create game: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      // Handle error, perhaps log it
      print('Exception during createGameApi: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> flipNewTile(String gameId, String token) async {
    final url = Uri.parse('${Config.backendUrl}/flip-tile');
    final Map<String, dynamic> payload = {
      'game_id': gameId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      // Parse the JSON response
      Map<String, dynamic> responseData = {};
      if (response.body.isNotEmpty) {
        responseData = jsonDecode(response.body);
      }

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return {'success': true};
        } else if (responseData['reason'] == 'no_tiles_left') {
          return {'success': false, 'reason': 'no_tiles_left'};
        }
        return {'success': false};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<http.Response> sendTileIds(
      String gameId, String token, List<Tile> selectedTiles) async {
    final url = Uri.parse('${Config.backendUrl}/submit-word');
    // Convert tileIds to integers
    final List<int> tileIdsAsIntegers =
        selectedTiles.map((tile) => tile.tileId).cast<int>().toList();

    final Map<String, dynamic> payload = {
      'game_id': gameId,
      'tile_ids': tileIdsAsIntegers,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        jsonDecode(response.body);
      } else {}
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

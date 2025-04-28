import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/screens/game_screen.dart';
import 'package:flutter_frontend/config.dart';
import 'package:flutter_frontend/classes/tile.dart';

class ApiService {
  Future<void> joinGameApi(BuildContext context, String gameId, String token,
      {required String username}) async {
    if (gameId.isEmpty) return;
    final url = Uri.parse('${Config.backendUrl}/join-game');
    print("in joinGameApi, username = $username");
    final Map<String, String> payload = {
      'game_id': gameId,
      'username': username
    };

    try {
      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("Received Data: $data");

        // Navigate to GameScreen and pass gameId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GameScreen(gameId: gameId, username: username),
          ),
        );
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("failed to fetch data: $e");
    }
  }

  Future<void> createGameApi(BuildContext context, String token,
      {required String username}) async {
    final url = Uri.parse('${Config.backendUrl}/create-game');

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
        print("Received Data: $data");
        final String gameId = data['game_id'];
        // Navigate to GameScreen and pass gameId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GameScreen(gameId: gameId, username: username),
          ),
        );
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("failed to fetch data: $e");
    }
  }

  Future<void> flipNewTile(String gameId, String token) async {
    final url = Uri.parse('${Config.backendUrl}/flip-tile');
    print("Trying to flip a new tile");
    final Map<String, dynamic> payload = {
      'game_id': gameId,
    };
    print("Payload: $payload");

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
        print("Tile was flipped successfully");
      } else {
        print(
            'Error flipping new tile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error making flip new tile request: $e');
    }
  }

  Future<http.Response> sendTileIds(String gameId, String token,
    List<Tile> selectedTiles) async {
    final url = Uri.parse('${Config.backendUrl}/submit-word');
    // Convert tileIds to integers
    final List<int> tileIdsAsIntegers = selectedTiles
      .map((tile) => tile.tileId).cast<int>().toList();

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
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print("Response Data: $responseData");
      } else {
        print(
            'Error sending tileIds: ${response.statusCode} - ${response.body}');
      }
      return response;
    } catch (e) {
      print('Error sending tileIds: $e');
      rethrow;
    }
  }
}
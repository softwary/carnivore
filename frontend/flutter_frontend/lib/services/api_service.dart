import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/config.dart';
import 'package:flutter_frontend/classes/tile.dart';

class ApiService {
  Future<void> joinGameApi(BuildContext context, String gameId, String token,
      {required String username, required Function onGameNotFound}) async {
    if (gameId.isEmpty) return;
    final url = Uri.parse('${Config.backendUrl}/join-game');
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
        jsonDecode(response.body);

        Navigator.pushNamed(
          context,
          '/game/$gameId',
          arguments: {'username': username},
        );
      } else {

        // Check if the error is about game not found (could be 404 or a specific error message)
        if (response.statusCode == 404 ||
            response.body.contains("not found") ||
            response.body.contains("doesn't exist")) {
          onGameNotFound();
        } else {
          // Show a generic error for other issues
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error joining game: ${response.reasonPhrase}'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
        ),
      );
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
        final String gameId = data['game_id'];
        
        Navigator.pushNamed(
          context,
          '/game/$gameId',
          arguments: {'username': username}, 
        );
      } else {
      }
    } catch (e) {
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
      } else {
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

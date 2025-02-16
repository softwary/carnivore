import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GameService {
  static Future<Map<String, dynamic>?> sendTileIds(String gameId, List<int> orderedTiles) async {
    if (orderedTiles.isEmpty || orderedTiles.length < 3) {
      return null;
    }
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final url = Uri.parse('http://192.168.1.218:4000/submit-word');
    final Map<String, dynamic> payload = {
      'game_id': gameId,
      'tile_ids': orderedTiles,
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
        return jsonDecode(response.body);
      } else {
        print('Error sending tileIds: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error sending tileIds: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> flipNewTile(String gameId) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final url = Uri.parse('http://192.168.1.218:4000/flip-tile');
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

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error flipping new tile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error making flip new tile request: $e');
      return null;
    }
  }
}
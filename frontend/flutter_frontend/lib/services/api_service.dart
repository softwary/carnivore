import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/screens/game_screen.dart';

class ApiService {
  Future<void> joinGameApi(BuildContext context, String gameId, String token) async {
    if (gameId.isEmpty) return;

    final url = Uri.parse('http://192.168.1.218:4000/join-game');
    final Map<String, String> payload = {'game_id': gameId};

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
            builder: (context) => GameScreen(gameId: gameId),
          ),
        );
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("failed to fetch data: $e");
    }
  }
  }
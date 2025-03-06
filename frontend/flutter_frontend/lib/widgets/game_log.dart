import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Make sure you have this import
import 'package:flutter_frontend/widgets/tile_widget.dart'; // Import TileWidget

class GameLog extends StatefulWidget {
  final String gameId;
  final double tileSize;

  const GameLog({Key? key, required this.gameId, required this.tileSize})
      : super(key: key);

  @override
  _GameLogState createState() => _GameLogState();
}

class _GameLogState extends State<GameLog> {
  final DatabaseReference _gameLogRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _logs = [];
  late StreamSubscription<DatabaseEvent> _gameLogSubscription;

  @override
  void initState() {
    super.initState();
    _listenToGameLog();
  }

  void _listenToGameLog() {
    _gameLogSubscription = _gameLogRef
        .child('games/${widget.gameId}/actions')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        // Correctly handle the snapshot value
        Map<dynamic, dynamic> data = event.snapshot.value is Map
            ? event.snapshot.value as Map<dynamic, dynamic>
            : {}; // Default to an empty map if not a Map

        List<Map<String, dynamic>> newLogs = data.entries.map((entry) {
          Map<dynamic, dynamic> logData =
              entry.value as Map<dynamic, dynamic>; // Explicit cast
          return {
            'playerId': logData['playerId'] ?? "Unknown Player",
            'word': logData['word'] ?? "", // Use newWord for consistency
            'type': logData['type'] ?? "Unknown Type",
            'timestamp': logData['timestamp'] ?? 0,
            'tileLetter': logData['tileLetter'], // For flip_tile
            'tileId': logData['tileId'], // For flip_tile
          };
        }).toList();
        newLogs.sort((b, a) => (a['timestamp'] as num)
            .compareTo(b['timestamp'] as num)); // Cast to num

        if (mounted) {
          setState(() {
            _logs = newLogs;
          });
        }
      } else {
        //snapshot is null
        if (mounted) {
          setState(() {
            _logs = [];
          });
        }
      }
    }, onError: (error) {
      //added error handling
      print("Firebase error: $error");
    });
  }

  @override
  void dispose() {
    _gameLogSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    if (screenSize.width < 600) {
      // Assuming 600 as the threshold for mobile screens
      return SizedBox.shrink(); // Return an empty widget
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Game Log",
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: _logs.isEmpty
              ? const Center(
                  child: Text("No actions yet",
                      style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  reverse: false, // Most recent at bottom
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    var log = _logs[index];
                    return _buildLogMessage(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogMessage(Map<String, dynamic> log) {
    // print("Log action: ${log['type']}, Player: ${log['playerId']}, Word: ${log['word']}, TileLetter: ${log['tileLetter']}, TileId: ${log['tileId']}");

    String message;
    Color textColor = Colors.white;
    List<Widget> tileWidgets = [];
    Color tileBackgroundColor = Colors.purple[900]!; // Default background
    switch (log['type']) {
      case 'flip_tile':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} flipped: ";
        if (log['tileLetter'] != null) {
          tileWidgets.add(
            TileWidget(
              letter: log['tileLetter'],
              tileId: log['tileId'].toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ),
          );
        }
        break;

      case 'MIDDLE_WORD':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted: ";
        textColor = Colors.green; // Valid word
        tileBackgroundColor = Colors.purple[900]!; // Valid word background
        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(
              TileWidget(
                letter: letter,
                tileId: UniqueKey().toString(),
                onClickTile: (_, __, ___) {},
                isSelected: false,
                backgroundColor: tileBackgroundColor,
                tileSize: widget.tileSize,
              ),
            );
          }
        }
        break;
      case 'OWN_WORD_IMPROVEMENT':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted: ";
        textColor = Colors.green; // Valid word
        tileBackgroundColor = Colors.purple[900]!; // Valid word background
        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(
              TileWidget(
                letter: letter,
                tileId: UniqueKey().toString(),
                onClickTile: (_, __, ___) {},
                isSelected: false,
                backgroundColor: tileBackgroundColor,
                tileSize: widget.tileSize,
              ),
            );
          }
        }
        break;
      case 'STEAL_WORD':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} stole! ";
        textColor = Colors.green; // Valid word
        tileBackgroundColor = Colors.purple[900]!; // Valid word background
        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(
              TileWidget(
                letter: letter,
                tileId: UniqueKey().toString(),
                onClickTile: (_, __, ___) {},
                isSelected: false,
                backgroundColor: tileBackgroundColor,
                tileSize: widget.tileSize,
              ),
            );
          }
        }
        break;

      case 'INVALID_LENGTH':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted a word without enough letters: ";
        textColor = Colors.red;
        tileBackgroundColor = Colors.red[900]!; // Invalid word background

        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(TileWidget(
              letter: letter,
              tileId: UniqueKey().toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ));
          }
        }
        break;
      case 'INVALID_NO_MIDDLE':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted a word without using tiles from the middle: ";
        textColor = Colors.red;
        tileBackgroundColor = Colors.red[900]!; // Invalid word background

        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(TileWidget(
              letter: letter,
              tileId: UniqueKey().toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ));
          }
        }
        break;
      case 'INVALID_LETTERS_USED':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted a word without valid letters: ";
        textColor = Colors.red;
        tileBackgroundColor = Colors.red[900]!; // Invalid word background

        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(TileWidget(
              letter: letter,
              tileId: UniqueKey().toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ));
          }
        }
        break;
      case 'INVALID_WORD_NOT_IN_DICTIONARY':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted a word not in the dictionary! ";
        textColor = Colors.red;
        tileBackgroundColor = Colors.red[900]!; // Invalid word background

        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(TileWidget(
              letter: letter,
              tileId: UniqueKey().toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ));
          }
        }
        break;
      case 'INVALID_UNKNOWN_WHY':
        message =
            "Player ${log['playerId'].toString().substring(0, 4)} submitted an invalid word: ";
        textColor = Colors.red;
        tileBackgroundColor = Colors.red[900]!; // Invalid word background

        if (log['word'] != null) {
          for (var letter in log['word'].split('')) {
            tileWidgets.add(TileWidget(
              letter: letter,
              tileId: UniqueKey().toString(),
              onClickTile: (_, __, ___) {},
              isSelected: false,
              backgroundColor: tileBackgroundColor,
              tileSize: widget.tileSize,
            ));
          }
        }
        break;
      default:
        message =
            "Unknown action by Player ${log['playerId'].toString().substring(0, 4)}";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  message,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                ...tileWidgets,
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _formatTimestamp(log['timestamp']),
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return "Unknown time";
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

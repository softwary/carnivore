import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/classes/tile.dart';

class GameLog extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final double tileSize;
  final Map<String, String> playerIdToUsernameMap;
  final String gameId;

  const GameLog({
    Key? key,
    required this.gameData,
    required this.tileSize,
    required this.playerIdToUsernameMap,
    required this.gameId,
  }) : super(key: key);

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

      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

      List<Map<String, dynamic>> newLogs = data.entries.map((entry) {
        final logData = entry.value as Map<dynamic, dynamic>;
        final String actionType = logData['type'] as String? ?? "Unknown Type";

        Map<String, dynamic> logEntry = {
          'playerId': logData['playerId'] ?? "Unknown Player",
          'type': actionType,
          'timestamp': logData['timestamp'] ?? 0,
        };

        if (actionType == 'flip_tile') {
          logEntry['tileLetter'] = logData['tileLetter'] ?? '';
          logEntry['tileId'] = logData['tileId'] ?? '';
        }
        if (actionType == 'MIDDLE_WORD' ||
            actionType == 'INVALID_LENGTH' ||
            actionType == 'INVALID_NO_MIDDLE' ||
            actionType == 'INVALID_LETTERS_USED' ||
            actionType == 'INVALID_WORD_NOT_IN_DICTIONARY' ||
            actionType == 'INVALID_UNKNOWN_WHY') {
          logEntry['word'] = logData['word'] ?? '';
        }
        if (actionType == 'STEAL_WORD') {
          logEntry['word'] = logData['word'] ?? '';
          logEntry['robbedUserId'] = logData['robbedUserId'] ?? '';
          logEntry['stolenWord'] = logData['stolenWord'] ?? '';
        }
        if (actionType == 'OWN_WORD_IMPROVEMENT') {
          logEntry['word'] = logData['word'] ?? '';
          logEntry['originalWord'] = logData['originalWord'] ?? '';
        }
        return logEntry;
      }).toList();

      newLogs.sort(
          (b, a) => (a['timestamp'] as num).compareTo(b['timestamp'] as num));

      setState(() {
        _logs = newLogs;
      });
    }, onError: (error) {});
  }

  @override
  void dispose() {
    _gameLogSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < 600) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Game Log",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: _logs.isEmpty
              ? const Center(
                  child: Text("No actions yet",
                      style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return _buildLogMessage(_logs[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogMessage(Map<String, dynamic> log) {
    final username = widget.playerIdToUsernameMap[log['playerId']] ?? 'bing';
    print("👀 Log: $log");
    final String message = _getLogMessage(log, username);
    print("👀 Message: $message");
    final Color textColor = _getTextColor(log['type']);
    final Color tileBackgroundColor = _getTileColor(log['type']);
    final List<Widget> tileWidgets =
        _buildWordTiles(log['word'], tileBackgroundColor);

    // Add TileWidget for flip_tile action
    if (log['type'] == 'flip_tile' && log['tileLetter'] != null) {
      tileWidgets.add(
        TileWidget(
          tile: Tile(
            letter: log['tileLetter'],
            location: 'gameLog',
            tileId: log['tileId'].toString(),
          ),
          onClickTile: (_, __) {},
          isSelected: false,
          backgroundColor: tileBackgroundColor,
          tileSize: widget.tileSize,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tileWidgets.length > 1) ...[
            Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              children: tileWidgets,
            ),
          ] else ...[
            // Single tile or no tile case: Message and tile(s) on the same line
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4.0,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                ...tileWidgets,
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(log['timestamp']),
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  String _getLogMessage(Map<String, dynamic> log, String username) {
    switch (log['type']) {
      case 'flip_tile':
        return "$username flipped:";
      case 'MIDDLE_WORD':
        return "$username created a word from the middle:";
      case 'OWN_WORD_IMPROVEMENT':
        final originalWord = log['originalWord'] as String?;
        return "$username improved their word $originalWord:";
      case 'STEAL_WORD':
        print("⭐️ Steal word log: $log");
        final robbedId = log['robbedUserId'] as String;
        final robbedName = widget.playerIdToUsernameMap[robbedId] ?? robbedId;
        final stolenWord = log['stolenWord'] as String?;
        return "$username stole $stolenWord from $robbedName!";
      case 'INVALID_LENGTH':
        return "$username submitted a word without enough letters:";
      case 'INVALID_NO_MIDDLE':
        return "$username submitted a word without using tiles from the middle:";
      case 'INVALID_LETTERS_USED':
        return "$username submitted a word without valid letters:";
      case 'INVALID_WORD_NOT_IN_DICTIONARY':
        return "$username submitted a word not in the dictionary!";
      case 'INVALID_UNKNOWN_WHY':
        return "$username submitted an invalid word:";
      default:
        return "Unknown action by Player $username";
    }
  }

  Color _getTextColor(String type) {
    return {
          'MIDDLE_WORD': Colors.green,
          'OWN_WORD_IMPROVEMENT': Colors.green,
          'STEAL_WORD': Colors.green,
          'INVALID_LENGTH': Colors.red,
          'INVALID_NO_MIDDLE': Colors.red,
          'INVALID_LETTERS_USED': Colors.red,
          'INVALID_WORD_NOT_IN_DICTIONARY': Colors.red,
          'INVALID_UNKNOWN_WHY': Colors.red,
        }[type] ??
        Colors.white;
  }

  Color _getTileColor(String type) {
    return {
          'MIDDLE_WORD': Colors.purple[900]!,
          'OWN_WORD_IMPROVEMENT': Colors.purple[900]!,
          'STEAL_WORD': Colors.purple[900]!,
          'INVALID_LENGTH': Colors.red[900]!,
          'INVALID_NO_MIDDLE': Colors.red[900]!,
          'INVALID_LETTERS_USED': Colors.red[900]!,
          'INVALID_WORD_NOT_IN_DICTIONARY': Colors.red[900]!,
          'INVALID_UNKNOWN_WHY': Colors.red[900]!,
        }[type] ??
        Colors.purple[900]!;
  }

  List<Widget> _buildWordTiles(String? word, Color backgroundColor) {
    if (word == null || word.isEmpty) return [];
    return word.split('').map((letter) {
      return TileWidget(
        tile: Tile(
          letter: letter,
          location: 'gameLog',
          tileId: UniqueKey().toString(),
        ),
        onClickTile: (_, __) {},
        isSelected: false,
        backgroundColor: backgroundColor,
        tileSize: widget.tileSize,
      );
    }).toList();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return "Unknown time";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }
}

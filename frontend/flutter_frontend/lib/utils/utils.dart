import 'package:intl/intl.dart';

String buildWordHistoryTooltip(dynamic wordHistory) {
  final buffer = StringBuffer();
  final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  List<dynamic> historyEntries = []; // Initialize as an empty list

  if (wordHistory is List) {
    historyEntries = wordHistory; // Handles the case where it's already a list
  } else if (wordHistory is Map) {
    // Iterate through the map and add each entry to the list
    wordHistory.forEach((key, value) {
      historyEntries.add(value); // Add each history entry to the list
    });
  } else {
    buffer.writeln("Invalid word history format.");
    return buffer.toString();
  }

  if (historyEntries.isEmpty) {
    buffer.writeln("No word history available.");
    return buffer.toString();
  }

  for (var entry in historyEntries.reversed) {
    if (entry is Map) {
      // Check if the entry is a map
      final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp']);
      final formattedTime = formatter.format(timestamp.toLocal());
      buffer.writeln("Word: ${entry['word']}");
      buffer.writeln("Status: ${entry['status']}");
      buffer.writeln("Player: ${entry['playerId']}");
      buffer.writeln("Time: $formattedTime");
      buffer.writeln("-------------------");
    } else {
      buffer.writeln("Invalid history entry format.");
    }
  }

  return buffer.toString();
}
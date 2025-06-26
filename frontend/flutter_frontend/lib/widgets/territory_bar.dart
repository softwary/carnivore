import 'package:flutter/material.dart';

class TerritoryBar extends StatelessWidget {
  final List<Map<String, dynamic>> playerScores; // List of {'playerId': 'id', 'score': 10}
  final Map<String, Color> playerColors; // Map of {'playerId': Color}
  final Map<String, String> playerUsernames; // Optional: Map of {'playerId': 'username'}

  const TerritoryBar({
    Key? key,
    required this.playerScores,
    required this.playerColors,
    this.playerUsernames = const {}, // Optional: Map of {'playerId': 'username'}
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If there are no players, render an empty container to avoid errors.
    if (playerScores.isEmpty) {
      return Container(
        height: 10.0,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
      );
    }

    return Container(
      height: 10.0, // Fixed height for the bar
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect( // Clip to apply border radius to the whole bar
        borderRadius: BorderRadius.circular(5.0),
        child: Row(
          children: playerScores.map((player) {
            final playerId = player['playerId'] as String;
            final score = player['score'] as int;
            final color = playerColors[playerId] ?? Colors.grey; // Fallback color
            final username = playerUsernames[playerId] ?? 'Unknown Player';

            // To ensure players with 0 score are visible, we give them a small
            // base flex value. Players with scores > 0 get a much larger flex
            // value to show their dominance proportionally.
            const int baseFlexForZeroScore = 1;
            const int scoreMultiplier = 15;
            final flexFactor =
                score > 0 ? (score * scoreMultiplier) : baseFlexForZeroScore;

            return Expanded( // Use Expanded for proportional sizing
              flex: flexFactor,
              child: Tooltip( // Add Tooltip for hover information
                message: '$username: $score',
                child: Container(
                  color: color,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

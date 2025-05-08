// // game_data_provider.dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'dart:convert';
// import 'dart:collection';

// final gameDataProvider = StateNotifierProvider.family<GameDataNotifier, Map<String, dynamic>?, String>(
//   (ref, gameId) => GameDataNotifier(gameId),
// );

// class GameDataNotifier extends StateNotifier<Map<String, dynamic>?> {
//   final String gameId;
//   late final DatabaseReference gameRef;

//   GameDataNotifier(this.gameId) : super(<String, dynamic>{}) {
//     gameRef = FirebaseDatabase.instance.ref('games/$gameId');
//     print("Listening to game data for gameId: $gameId");
//     print("gameRef: $gameRef");
//     _listen();
//   }

//   void _listen() {
//     gameRef.onValue.listen((event) {
//       final data = event.snapshot.value;
//       if (data is LinkedHashMap) {
//         state = jsonDecode(jsonEncode(data));
//       }
//     });
//   }

//   void clear() {
//     state = null;
//   }
// }

// filepath: lib/classes/game_data_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert'; // For jsonEncode/Decode if used

final gameDataProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, gameId) {
  final databaseReference = FirebaseDatabase.instance.ref('games/$gameId');
  return databaseReference.onValue.map((event) {
    final data = event.snapshot.value;
    if (data == null) {
      return null;
    }
    if (data is Map<dynamic, dynamic>) {
      // More robust conversion for Firebase data
      try {
        // Encode to JSON string, then decode. This helps ensure
        // the map structure is compatible with Map<String, dynamic>.
        final encodedData = jsonEncode(data);
        final decodedData = jsonDecode(encodedData);
        if (decodedData is Map<String, dynamic>) {
          return decodedData;
        } else {
          // This case should be rare if jsonEncode/Decode works as expected
          print("❌ Decoded data is not Map<String, dynamic>: $decodedData");
          return null;
        }
      } catch (e) {
        print("❌ Error converting Firebase data to Map<String, dynamic>: $e");
        return null;
      }
    }
    // Handle other cases or return null if data is not in expected format
    print("❌ Firebase data is not a Map: $data");
    return null;
  });
});
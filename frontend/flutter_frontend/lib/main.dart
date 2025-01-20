import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_frontend/screens/game_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

Future<void> joinGame(BuildContext context, String gameId) async {
  // final url = Uri.parse('http://localhost:4000/join-game');
  if (gameId.isEmpty) {
    return;
  }
  final url = Uri.parse('http://192.168.1.218:4000/join-game');
  final Map<String, String> payload = {'game_id': gameId};

  try {
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordivore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181828),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF282838),
          titleTextStyle: TextStyle(color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF9C27B0),
          secondary: const Color(0xFF673AB7),
          background: const Color(0xFF181828),
          surface: const Color(0xFF282838),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          titleMedium: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Wordivore'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _gameIdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _gameIdController.text = '2834'; 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                """Wordivore is a word game played with 2+ players. There are 144 face-down letter tiles in the middle. 
          Players take turns flipping over a tile to create words. The first player to type out a valid English word 
          using the flipped tile gets to keep the letters in their word. Players can steal words by creating an anagram 
          using the existing letters. 
          
          The game ends when there are no more tiles left, and the player with the
          most tiles wins!""",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            ElevatedButton(
              // Create Game button
              onPressed: () => {/* Handle create game functionality */},
              child: const Text('Create Game'),
            ),
            const SizedBox(height: 20), // Add spacing between buttons
            Row(
              // Create a Row for horizontal layout
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                SizedBox(
                  // Wrap TextField with SizedBox for centering
                  width: MediaQuery.of(context).size.width /
                      2, // Half the screen width
                  child: TextField(
                    controller: _gameIdController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Enter Game ID',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (value) => joinGame(context, value)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Add spacing below buttons
            ElevatedButton(
              onPressed: () async {
                await joinGame(context, _gameIdController.text);
              },
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}

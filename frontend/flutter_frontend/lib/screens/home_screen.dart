import 'package:flutter/material.dart';
import 'package:flutter_frontend/services/auth_service.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/screens/create_account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _gameIdController =
      TextEditingController(text: '2834');
  final FocusNode _focusNode = FocusNode();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  String? token;
  User? user;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) {
      setState(() {
        user = firebaseUser;
      });
    });

    user = FirebaseAuth.instance.currentUser;
    token = await user?.getIdToken();
    setState(() {});

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
        actions: [
          if (user == null) ...[
            // Show login buttons if user is not logged in
            ElevatedButton(
              onPressed: () async {
                await _authService.loginAnonymously();
                setState(() {
                  user = FirebaseAuth.instance.currentUser;
                });
                token = await user?.getIdToken();
              },
              child: const Text('Login Anonymously'),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () async {
                await _authService.loginWithGoogle();
                setState(() {
                  user = FirebaseAuth.instance.currentUser;
                });
                token = await user?.getIdToken();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateAccountScreen(
                      onCreateAccount: () async {
                        setState(() {
                          user = FirebaseAuth.instance.currentUser;
                        });
                        token = await user?.getIdToken();
                      },
                    ),
                  ),
                );
              },
              child: const Text('Create Account'),
            ),
          ] else ...[
            // Show logout button if user is logged in
            ElevatedButton(
              onPressed: () async {
                await _authService.logout();
                setState(() {
                  user = null;
                  token = null;
                });
              },
              child: const Text('Logout'),
            ),
          ],
        ],
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
              onPressed: () => {/* TODO: Handle create game functionality */},
              child: const Text('Create Game'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                SizedBox(
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
                      onSubmitted: (value) {
                        if (token != null) {
                          _apiService.joinGameApi(context, value, token!);
                        } else {
                          // Handle case where user is not logged in
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please log in to join a game.'),
                            ),
                          );
                        }
                      }),
                ),
              ],
            ),
            const SizedBox(height: 20), // Add spacing below buttons
            ElevatedButton(
              onPressed: () async {
                if (token != null) {
                  await _apiService.joinGameApi(
                      context, _gameIdController.text, token!);
                } else {
                  // Handle case where user is not logged in
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please log in to join a game.'),
                    ),
                  );
                }
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

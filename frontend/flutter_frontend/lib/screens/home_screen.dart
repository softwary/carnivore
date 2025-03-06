import 'package:flutter/material.dart';
import 'package:flutter_frontend/services/auth_service.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:flutter_frontend/screens/create_account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _gameIdController =
      TextEditingController(text: '1337');
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _usernameController =
      TextEditingController(text: 'Nikki');
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
      body: SingleChildScrollView(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double tileSize =
                  constraints.maxWidth > 600 ? 40 : 25; // Adjust tile size

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 20),
                  // "Wordivore" title using tiles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: 'Wordivore'.split('').map((letter) {
                      return TileWidget(
                        letter: letter,
                        tileId: letter.hashCode.toString(),
                        onClickTile:
                            (String tileId, String letter, bool isSelected) {},
                        isSelected: false,
                        tileSize: tileSize, // Adjusted tile size
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (token != null &&
                          _usernameController.text.isNotEmpty) {
                        _apiService.createGameApi(context, token!,
                            username: _usernameController.text);
                      } else if (_usernameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Enter a username before creating a game!'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please log in to create a game.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Create Game'),
                  ),

                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      """Wordivore is a word game played with 2+ players. There are 144 face-down letter tiles in the middle.  
Players take turns flipping over a tile to create words. The first player to type out a valid English word  
using the flipped tile gets to keep the letters in their word. Players can steal words by creating an anagram  
using the existing letters.  

The game ends when there are no more tiles left, and the player with the most tiles wins!""",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),

                  SizedBox(
                    width: constraints.maxWidth / 2,
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: constraints.maxWidth / 2,
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
                          _apiService.joinGameApi(
                            context,
                            value,
                            token!,
                            username: _usernameController.text,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please log in to join a game.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      if (token != null) {
                        if (_usernameController.text.isEmpty ||
                            _gameIdController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please enter both username and game ID.'),
                            ),
                          );
                          return;
                        }

                        await _apiService.joinGameApi(
                          context,
                          _gameIdController.text,
                          token!,
                          username: _usernameController.text,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please log in to join a game.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Join Game'),
                  ),
                  const SizedBox(height: 50), // Extra spacing at bottom
                ],
              );
            },
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}

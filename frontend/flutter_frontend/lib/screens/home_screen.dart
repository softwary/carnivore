import 'package:flutter/material.dart';
import 'package:flutter_frontend/services/auth_service.dart';
import 'package:flutter_frontend/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'dart:math';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _gameIdController =
      TextEditingController(text: '');
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _usernameController =
      TextEditingController(text: '');
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: 'Wordivore'.split('').map((letter) {
            return TileWidget(
              tile: Tile(
                letter: letter,
                location: '',
                tileId: letter.hashCode.toString(),
              ),
              onClickTile: (Tile tile, bool isSelected) {},
              isSelected: false,
              tileSize: 30, // Adjusted for app bar
            );
          }).toList(),
        ),
        actions: [
          if (user == null) ...[
            ElevatedButton(
              onPressed: () async {
                await _authService.loginAnonymously();
                final random = Random();
                final randomNumber = random.nextInt(90000) + 10000;
                final randomUsername = 'player$randomNumber';
                setState(() {
                  user = FirebaseAuth.instance.currentUser;
                  _usernameController.text = randomUsername;
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
                  if (user?.displayName != null &&
                      user!.displayName!.isNotEmpty) {
                    _usernameController.text = user!.displayName!;
                  }
                });
                token = await user?.getIdToken();
              },
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () async {
                await _authService.logout();
                setState(() {
                  user = null;
                  token = null;
                  _usernameController.text = ''; // Clear username on logout
                });
              },
              child: const Text('Logout'),
            ),
          ],
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    """Wordivore is a word game played with 2+ players.

Players take turns flipping over tiles in the middle to create words. They can then use those middle tiles to steal other players' words by rearranging them and adding 1 or more tiles from the middle to those words. To steal someone's word or improve their own, a player must use all of the letters from that word.

The player with the most tiles at the end of the game wins!""",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 30),

                // Username field
                if (user != null)
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Username',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 30),

                // Action Buttons
                _buildGameButton(
                  context,
                  text: 'Play with a Friend',
                  onPressed: () async {
                    if (token != null && _usernameController.text.isNotEmpty) {
                      final gameId = await _apiService.createGameApi(token!,
                          username: _usernameController.text);
                      if (gameId != null && mounted) {
                        Navigator.pushNamed(
                          context,
                          '/game/$gameId',
                          arguments: {'username': _usernameController.text},
                        );
                      } else if (mounted) {
                        _showErrorSnackBar(
                            'Failed to create game. Please try again.');
                      }
                    } else {
                      _showErrorSnackBar('Please log in to create a game.');
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildGameButton(
                  context,
                  text: 'Play the Computer',
                  onPressed: () async {
                    if (token != null && _usernameController.text.isNotEmpty) {
                      final gameId = await _apiService.playComputerApi(
                          token: token!, username: _usernameController.text);
                      if (gameId != null && mounted) {
                        Navigator.pushNamed(
                          context,
                          '/game/$gameId',
                          arguments: {'username': _usernameController.text},
                        );
                      } else if (mounted) {
                        _showErrorSnackBar(
                            'Failed to create game. Please try again.');
                      }
                    } else {
                      _showErrorSnackBar('Please log in to play.');
                    }
                  },
                ),

                const SizedBox(height: 30),

                // Join Game Section
                _buildJoinGameSection(context),

                const SizedBox(height: 40),
                _buildHowToPlaySection(),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }

  Widget _buildGameButton(BuildContext context,
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: 300,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildHowToPlaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Play',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 15),
        _buildHowToPlayStep(
          '1. Flip a tile',
          'Players take turns flipping over a tile from the center pile.',
          // Placeholder for your GIF
          // flipTileGIF.gif
          Image.asset('assets/gifs/flipTiles2.gif', height: 150, fit: BoxFit.cover),
        ),
        const SizedBox(height: 20),
        _buildHowToPlayStep(
          '2. Make a word',
          'Use the letters in the center to form a word. The first player to type a valid word claims it!',
          // Placeholder for your GIF
          Image.asset('assets/gifs/createPOEMS2.gif', height: 150, fit: BoxFit.cover),
        ),
        const SizedBox(height: 20),
        _buildHowToPlayStep(
          '3. Steal words',
          'Steal words from other players by adding letters and rearranging them to form a new, longer word.',
          // Placeholder for your GIF
          Image.asset('assets/gifs/stealRIMS2.gif', height: 150, fit: BoxFit.cover),
        ),
      ],
    );
  }

  Widget _buildHowToPlayStep(String title, String description, Widget visual) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        visual,
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildJoinGameSection(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Or join an existing game',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _gameIdController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
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
            textAlign: TextAlign.center,
            onSubmitted: (value) => _joinGame(),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          height: 50,
          child: ElevatedButton(
            onPressed: _joinGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
            ),
            child: const Text('Join Game'),
          ),
        ),
      ],
    );
  }

  void _joinGame() async {
    if (token == null) {
      _showErrorSnackBar('Please log in to join a game.');
      return;
    }
    if (_usernameController.text.isEmpty || _gameIdController.text.isEmpty) {
      _showErrorSnackBar('Please enter both username and game ID.');
      return;
    }

    await _apiService.joinGameApi(
      gameId: _gameIdController.text.trim(),
      token: token!,
      username: _usernameController.text.trim(),
      onGameNotFound: () {
        _showErrorSnackBar('Game not found. Please check the game ID.');
      },
    );

    if (mounted) {
      Navigator.pushNamed(
        context,
        '/game/${_gameIdController.text.trim()}',
        arguments: {'username': _usernameController.text.trim()},
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

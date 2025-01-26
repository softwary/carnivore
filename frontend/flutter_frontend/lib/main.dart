// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_frontend/screens/game_screen.dart';
// import 'firebase_options.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Wordivore',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         scaffoldBackgroundColor: const Color(0xFF181828),
//         appBarTheme: const AppBarTheme(
//           backgroundColor: Color(0xFF282838),
//           titleTextStyle: TextStyle(color: Colors.white),
//           iconTheme: IconThemeData(color: Colors.white),
//         ),
//         colorScheme: ColorScheme.dark(
//           primary: const Color(0xFF9C27B0),
//           secondary: const Color(0xFF673AB7),
//           background: const Color(0xFF181828),
//           surface: const Color(0xFF282838),
//           onPrimary: Colors.white,
//           onSecondary: Colors.white,
//           onBackground: Colors.white,
//           onSurface: Colors.white,
//         ),
//         textTheme: const TextTheme(
//           bodyMedium: TextStyle(color: Colors.white),
//           bodySmall: TextStyle(color: Colors.white70),
//           titleMedium: TextStyle(color: Colors.white),
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFF9C27B0),
//             foregroundColor: Colors.white,
//           ),
//         ),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Wordivore'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final TextEditingController _gameIdController = TextEditingController();
//   final FocusNode _focusNode = FocusNode();

//   @override
//   void initState() {
//     super.initState();
//     _gameIdController.text = '2834';
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _focusNode.requestFocus();
//     });
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//           backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
//           title: Text(widget.title),
//           actions: [
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 ElevatedButton(
//                   onPressed: _loginAnonymously,
//                   child: const Text('Login Anonymously'),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.account_circle),
//                   onPressed: _loginWithGoogle,
//                 ),
//               ],
//             )
//           ]),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Padding(
//               padding: EdgeInsets.all(16.0),
//               child: Text(
//                 """Wordivore is a word game played with 2+ players. There are 144 face-down letter tiles in the middle. 
//           Players take turns flipping over a tile to create words. The first player to type out a valid English word 
//           using the flipped tile gets to keep the letters in their word. Players can steal words by creating an anagram 
//           using the existing letters. 
          
//           The game ends when there are no more tiles left, and the player with the
//           most tiles wins!""",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 18, color: Colors.white),
//               ),
//             ),
//             ElevatedButton(
//               // Create Game button
//               onPressed: () => {/* Handle create game functionality */},
//               child: const Text('Create Game'),
//             ),
//             const SizedBox(height: 20), // Add spacing between buttons
//             Row(
//               // Create a Row for horizontal layout
//               mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
//               children: [
//                 SizedBox(
//                   // Wrap TextField with SizedBox for centering
//                   width: MediaQuery.of(context).size.width /
//                       2, // Half the screen width
//                   child: TextField(
//                       controller: _gameIdController,
//                       focusNode: _focusNode,
//                       decoration: const InputDecoration(
//                         labelText: 'Enter Game ID',
//                         labelStyle: TextStyle(color: Colors.white),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide: BorderSide(color: Colors.white),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: BorderSide(color: Colors.white),
//                         ),
//                       ),
//                       style: const TextStyle(color: Colors.white),
//                       onSubmitted: (value) => joinGame(context, value)),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20), // Add spacing below buttons
//             ElevatedButton(
//               onPressed: () async {
//                 await joinGame(context, _gameIdController.text);
//               },
//               child: const Text('Join Game'),
//             ),
//           ],
//         ),
//       ),
//       backgroundColor: Theme.of(context).colorScheme.background,
//     );
//   }
// }
// class CreateAccountScreen extends StatefulWidget {
//   const CreateAccountScreen({super.key});

//   @override
//   State<CreateAccountScreen> createState() => _CreateAccountScreenState();
// }

// class _CreateAccountScreenState extends State<CreateAccountScreen> {
//   final TextEditingController _usernameController = TextEditingController();

//   Future<void> _createAccount() async {
//     final username = _usernameController.text.trim();
//     if (username.isEmpty) {
//       print('Username cannot be empty');
//       return;
//     }

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         await user.updateDisplayName(username);
//         print('Username updated to $username');
//         Navigator.pop(context);
//       } else {
//         print('No user is signed in');
//       }
//     } catch (e) {
//       print('Failed to update username: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Account'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _usernameController,
//               decoration: const InputDecoration(
//                 labelText: 'Username',
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _createAccount,
//               child: const Text('Create Account'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_frontend/screens/home_screen.dart'; // Import the new HomeScreen
import 'package:flutter_frontend/theme/app_theme.dart'; // Import your custom theme

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordivore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Use your custom theme
      home: const MyHomePage(title: 'Wordivore'),
    );
  }
}
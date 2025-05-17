import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_frontend/screens/home_screen.dart';
import 'package:flutter_frontend/theme/app_theme.dart';
import 'package:flutter_frontend/screens/game_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Use path-based URLs for web
    setUrlStrategy(PathUrlStrategy());
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordivore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorObservers: [HeroController()],
      initialRoute: '/',
      onGenerateRoute: _generateRoute, 
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
  final List<String> pathSegments = Uri.parse(settings.name ?? '/').pathSegments;

  print("Generating route for: ${settings.name}");
  print("Path segments: $pathSegments");
  print("Arguments: ${settings.arguments}");

  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => const MyHomePage(title: 'Wordivore'),
        settings: settings,
      );
    // Add other static routes here if needed
    // e.g., case '/login': return MaterialPageRoute(builder: (_) => LoginScreen());
  }

  // Handle dynamic routes like /game/:gameId
  if (pathSegments.isNotEmpty && pathSegments.first == 'game') {
    if (pathSegments.length == 2) {
      final gameId = pathSegments[1];
      final args = settings.arguments as Map<String, dynamic>?;
      
      // When navigating from within the app (create/join), username will be in args.
      // When opening a deep link, args might be null.
      // GameScreen's `username` prop should be nullable or GameScreen handles fetching it.
      String? usernameFromArgs = args?['username'] as String?;

      return MaterialPageRoute(
        builder: (_) => GameScreen(
          key: ValueKey('GameScreen_$gameId'), // Useful for widget identity
          gameId: gameId,
          username: usernameFromArgs, // Pass potentially null username
        ),
        settings: settings, // Pass settings for Hero animations, etc.
      );
    }
  }

  // Handle unknown routes
  print("Route not found: ${settings.name}");
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(child: Text('Page not found: ${settings.name}')),
    ),
    settings: settings,
  );
}
}

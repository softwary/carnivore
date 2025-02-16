import 'package:flutter/material.dart';

 class AppTheme {
   static ThemeData get darkTheme {
     return ThemeData(
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
        //  background: const Color(0xFF181828),
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
     );
   }
 }
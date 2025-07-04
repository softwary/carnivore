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
         primary: const Color(0xFF05B2DC),
         secondary: const Color(0xFF0B3142),
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
           backgroundColor: const Color(0xFF4A148C),
           foregroundColor: Colors.white,
         ),
       ),
       useMaterial3: true,
     );
   }
 }
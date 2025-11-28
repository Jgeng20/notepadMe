import 'package:flutter/material.dart';

class BookTheme {
  static const Color paperColor = Color(0xFFFFF8DC);
  static const Color darkPaperColor = Color(0xFFE8DCC4);
  
  static const Color inkColor = Color(0xFF2C1810);
  static const Color lightInkColor = Color(0xFF5C4033);
  
  static const Color accentBrown = Color(0xFF8B4513);
  static const Color lightBrown = Color(0xFFD2691E);
  
  static List<BoxShadow> bookShadow = [
    BoxShadow(
      // FIXED: withValues
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 10,
      offset: const Offset(0, 5),
    ),
  ];

  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: inkColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 16,
    color: inkColor,
    height: 1.6,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 14,
    color: lightInkColor,
    fontStyle: FontStyle.italic,
  );

  static BoxDecoration pageDecoration = BoxDecoration(
    color: paperColor,
    borderRadius: BorderRadius.circular(8),
    boxShadow: bookShadow,
    border: Border.all(
      color: darkPaperColor,
      width: 1,
    ),
  );

  static BoxDecoration linedPaperDecoration = const BoxDecoration(
    color: paperColor,
    image: DecorationImage(
      image: AssetImage('assets/lined_paper.png'),
      repeat: ImageRepeat.repeat,
      opacity: 0.1,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    primaryColor: accentBrown,
    scaffoldBackgroundColor: const Color(0xFFF5E6D3),
    // FIXED: Hapus background, gunakan surface
    colorScheme: const ColorScheme.light(
      primary: accentBrown,
      secondary: lightBrown,
      surface: paperColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: accentBrown,
      foregroundColor: paperColor,
      elevation: 4,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentBrown,
      foregroundColor: paperColor,
    ),
    textTheme: const TextTheme(
      displayLarge: titleStyle,
      bodyLarge: bodyStyle,
      bodyMedium: subtitleStyle,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: const Color(0xFF5C4033),
    scaffoldBackgroundColor: const Color(0xFF1A1410),
    // FIXED: Hapus background, gunakan surface
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF5C4033),
      secondary: Color(0xFF8B7355),
      surface: Color(0xFF2C2420),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2C2420),
      foregroundColor: Color(0xFFE8DCC4),
      elevation: 4,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF5C4033),
      foregroundColor: Color(0xFFE8DCC4),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE8DCC4),
      ),
      bodyLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 16,
        color: Color(0xFFE8DCC4),
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'serif',
        fontSize: 14,
        color: Color(0xFFB8A890),
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}
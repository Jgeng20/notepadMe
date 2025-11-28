import 'package:flutter/material.dart';
import 'widgets/book_theme.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final StorageService storageService = StorageService();
  bool isDarkMode = await storageService.getSetting('darkMode', false);
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const NotepadMeApp());
}

class NotepadMeApp extends StatelessWidget {
  // FIXED: Super parameter
  const NotepadMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'NotepadMe',
          debugShowCheckedModeBanner: false,
          theme: BookTheme.lightTheme,
          darkTheme: BookTheme.darkTheme,
          themeMode: currentMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
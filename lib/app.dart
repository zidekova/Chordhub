// Koreňový widget aplikácie: nastavenie svetlej/tmavej témy a prepínanie motívu.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/songbook_page.dart';

class ChordHubApp extends StatefulWidget {
  const ChordHubApp({super.key});

  @override
  State<ChordHubApp> createState() => _ChordHubAppState();
}

class _ChordHubAppState extends State<ChordHubApp> {
  static const Color _brandOrange = Color(0xFFFF9F00);
  static const String _prefThemeMode = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveThemeMode(_themeMode);
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefThemeMode);
    final restored =
        value == 'light'
            ? ThemeMode.light
            : value == 'dark'
            ? ThemeMode.dark
            : ThemeMode.dark;

    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = restored;
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light ? 'light' : 'dark';
    await prefs.setString(_prefThemeMode, value);
  }

  @override
  Widget build(BuildContext context) {
    final lightSeedScheme = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      brightness: Brightness.light,
    );
    final darkSeedScheme = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      brightness: Brightness.dark,
    );

    final lightScheme = lightSeedScheme.copyWith(
      primary: _brandOrange,
      surface: const Color(0xFFF7F8FA),
      surfaceContainerHighest: const Color(0xFFECEFF3),
      secondaryContainer: const Color(0xFFFFF1D7),
      onSecondaryContainer: const Color(0xFF4A2D00),
      tertiary: const Color(0xFF4B5563),
    );

    final darkScheme = darkSeedScheme.copyWith(
      primary: const Color(0xFFFFB433),
      surface: const Color(0xFF111317),
      surfaceContainerHighest: const Color(0xFF1D232C),
      secondaryContainer: const Color(0xFF3B2A00),
      onSecondaryContainer: const Color(0xFFFFE1AA),
      tertiary: const Color(0xFF9CA3AF),
    );

    return MaterialApp(
      title: 'Chordhub',
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
        ),
      ),
      themeMode: _themeMode,
      home: SongbookPage(
        themeMode: _themeMode,
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}

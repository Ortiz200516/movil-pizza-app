import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  // ── Getters principales ────────────────────────────────────────────────────
  bool get isDark => _isDark;

  /// Alias para compatibilidad con perfil_page.dart
  bool get oscuro => _isDark;

  /// ThemeMode para MaterialApp
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('tema_oscuro') ?? true;
    notifyListeners();
  }

  /// Alterna entre oscuro y claro
  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tema_oscuro', _isDark);
    notifyListeners();
  }

  /// Alias para compatibilidad con perfil_page.dart
  Future<void> toggleTema() => toggleTheme();

  Future<void> setDark(bool value) async {
    _isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tema_oscuro', _isDark);
    notifyListeners();
  }

  // ── Colores según tema ─────────────────────────────────────────────────────
  Color get bgColor       => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get cardColor     => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get card2Color    => _isDark ? const Color(0xFF263348) : const Color(0xFFF8FAFC);
  Color get textPrimary   => _isDark ? Colors.white            : const Color(0xFF1E293B);
  Color get textSecondary => _isDark ? Colors.white54          : const Color(0xFF64748B);
  Color get borderColor   => _isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.07);

  // ── ThemeData para MaterialApp (uso con Consumer<ThemeProvider>) ───────────
  ThemeData get themeData {
    if (_isDark) {
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFFFF6B35),
          secondary: Color(0xFFFF6B00),
          surface:   Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF1E293B),
      );
    } else {
      return ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFFFF6B35),
          secondary: Color(0xFFFF6B00),
          surface:   Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
        cardColor: Colors.white,
      );
    }
  }

  // ── ThemeData estáticos para MaterialApp con theme/darkTheme ──────────────
  /// Usar en MaterialApp como: theme: ThemeProvider.temaClaro
  static ThemeData get temaClaro => ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    colorScheme: const ColorScheme.light(
      primary:   Color(0xFFFF6B35),
      secondary: Color(0xFFFF6B00),
      surface:   Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1E293B),
      elevation: 0,
    ),
    cardColor: Colors.white,
  );

  /// Usar en MaterialApp como: darkTheme: ThemeProvider.temaOscuro
  static ThemeData get temaOscuro => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: const ColorScheme.dark(
      primary:   Color(0xFFFF6B35),
      secondary: Color(0xFFFF6B00),
      surface:   Color(0xFF1E293B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF1E293B),
  );
}
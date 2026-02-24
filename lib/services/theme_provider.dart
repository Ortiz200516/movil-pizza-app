import 'package:flutter/material.dart';

/// Controla el tema claro/oscuro de la app.
/// Persiste en memoria durante la sesión (sin SharedPreferences para web).
class ThemeProvider extends ChangeNotifier {
  bool _oscuro = true; // Default: oscuro (la app siempre fue oscura)
  bool get oscuro => _oscuro;
  ThemeMode get themeMode => _oscuro ? ThemeMode.dark : ThemeMode.light;

  void toggleTema() {
    _oscuro = !_oscuro;
    notifyListeners();
  }

  void setOscuro(bool value) {
    if (_oscuro == value) return;
    _oscuro = value;
    notifyListeners();
  }

  // ── TEMA OSCURO ──────────────────────────────────────────────
  static ThemeData get temaOscuro => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF111827),
    colorScheme: ColorScheme.dark(
      primary:    const Color(0xFFFF6B00),
      secondary:  const Color(0xFFFF6B35),
      surface:    const Color(0xFF1E293B),
      background: const Color(0xFF111827),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor:       const Color(0xFF1E293B),
    dividerColor:    Colors.white10,
    iconTheme:       const IconThemeData(color: Colors.white70),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall:  TextStyle(color: Colors.white54),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white12),
      ),
    ),
    useMaterial3: false,
  );

  // ── TEMA CLARO ───────────────────────────────────────────────
  static ThemeData get temaClaro => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    colorScheme: ColorScheme.light(
      primary:    const Color(0xFFFF6B00),
      secondary:  const Color(0xFFFF6B35),
      surface:    Colors.white,
      background: const Color(0xFFF8FAFC),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor:    Colors.white,
    dividerColor: Colors.black12,
    iconTheme:    const IconThemeData(color: Color(0xFF334155)),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFF0F172A)),
      bodySmall:  TextStyle(color: Color(0xFF64748B)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    useMaterial3: false,
  );
}
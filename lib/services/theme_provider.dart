import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _oscuro = true;
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

  // ── Colores de la marca ─────────────────────────────────────
  static const naranja = Color(0xFFFF6B00);
  static const naranjaL = Color(0xFFFF6B35);
  static const fondoOsc = Color(0xFF111827);
  static const cardOsc = Color(0xFF1E293B);
  static const fondoClr = Color(0xFFF8FAFC);

  // ── TEMA OSCURO ─────────────────────────────────────────────
  static ThemeData get temaOscuro => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoOsc,
        colorScheme: const ColorScheme.dark(
          primary: naranja,
          secondary: naranjaL,
          surface: cardOsc,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        cardColor: cardOsc,
        dividerColor: Colors.white10,
        iconTheme: const IconThemeData(color: Colors.white70),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white38),
          labelLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranja,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: naranja,
            side: const BorderSide(color: naranja),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardOsc,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: naranja, width: 1.5)),
          labelStyle: const TextStyle(color: Colors.white38),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? naranja : Colors.white38),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? naranja.withOpacity(0.4)
                  : Colors.white12),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? naranja : Colors.transparent),
          side: const BorderSide(color: Colors.white38),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: naranja,
          labelColor: naranja,
          unselectedLabelColor: Colors.white38,
        ),
        useMaterial3: false,
      );

  // ── TEMA CLARO ──────────────────────────────────────────────
  static ThemeData get temaClaro => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: fondoClr,
        colorScheme: ColorScheme.light(
          primary: naranja,
          secondary: naranjaL,
          surface: Colors.white,
          background: fondoClr,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.black12,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF0F172A)),
          bodyMedium: TextStyle(color: Color(0xFF334155)),
          bodySmall: TextStyle(color: Color(0xFF64748B)),
          labelLarge:
              TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranja,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: naranja, width: 1.5)),
          labelStyle: const TextStyle(color: Color(0xFF64748B)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? naranja : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? naranja.withOpacity(0.4)
                  : Colors.black12),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? naranja : Colors.transparent),
          side: const BorderSide(color: Color(0xFF94A3B8)),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: naranja,
          labelColor: naranja,
          unselectedLabelColor: Color(0xFF94A3B8),
        ),
        useMaterial3: false,
      );
}

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de caché offline para toda la app
/// Guarda datos clave en SharedPreferences para uso sin conexión
class OfflineService {
  static const _kMenu      = 'cache_menu_v2';
  static const _kPedidos   = 'cache_pedidos_v2';
  static const _kConfig    = 'cache_config_v2';
  static const _kTimestamp = 'cache_timestamp_v2';
  static const _ttlMinutos = 30; // cache válido 30 min

  // ── Verificar si el cache es fresco ──────────────────────────────────────
  static Future<bool> cacheEsFresco() async {
    final prefs = await SharedPreferences.getInstance();
    final ts    = prefs.getInt(_kTimestamp) ?? 0;
    final diff  = DateTime.now().millisecondsSinceEpoch - ts;
    return diff < _ttlMinutos * 60 * 1000;
  }

  // ── Menú ──────────────────────────────────────────────────────────────────
  static Future<void> guardarMenu(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMenu, jsonEncode(items));
    await prefs.setInt(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>> cargarMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kMenu);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // ── Últimos pedidos del cliente ───────────────────────────────────────────
  static Future<void> guardarMisPedidos(List<Map<String, dynamic>> pedidos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPedidos, jsonEncode(pedidos));
  }

  static Future<List<Map<String, dynamic>>> cargarMisPedidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPedidos);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // ── Config del local ──────────────────────────────────────────────────────
  static Future<void> guardarConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfig, jsonEncode(config));
  }

  static Future<Map<String, dynamic>?> cargarConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kConfig);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  // ── Limpiar cache ─────────────────────────────────────────────────────────
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMenu);
    await prefs.remove(_kPedidos);
    await prefs.remove(_kConfig);
    await prefs.remove(_kTimestamp);
  }
}



/// Banner de estado de conexión que se muestra automáticamente
class BannerSinConexion extends StatelessWidget {
  final bool sinConexion;
  const BannerSinConexion({super.key, required this.sinConexion});

  @override
  Widget build(BuildContext context) {
    if (!sinConexion) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.orange.withValues(alpha: 0.9),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Sin conexión — mostrando datos guardados',
              style: TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
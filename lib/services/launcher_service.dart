import 'package:url_launcher/url_launcher.dart';

/// Servicio centralizado para abrir URLs externas:
/// llamadas, WhatsApp, Google Maps y navegación GPS.
class LauncherService {
  LauncherService._();

  // ── Llamada telefónica ──────────────────────────────────────────────────────
  static Future<bool> llamar(String telefono) async {
    // Limpiar el número (quitar espacios, guiones, etc.)
    final numero = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$numero');
    return _abrir(uri);
  }

  // ── WhatsApp ────────────────────────────────────────────────────────────────
  static Future<bool> whatsapp(String telefono, {String mensaje = ''}) async {
    final numero = telefono.replaceAll(RegExp(r'[^\d]'), '');
    final msg    = Uri.encodeComponent(mensaje);
    final uri    = Uri.parse('https://wa.me/$numero?text=$msg');
    return _abrir(uri);
  }

  // ── Google Maps (dirección de texto) ───────────────────────────────────────
  static Future<bool> abrirMaps(String direccion) async {
    final query = Uri.encodeComponent(direccion);
    // Intenta abrir la app nativa de Maps primero
    final uriNativa = Uri.parse('geo:0,0?q=$query');
    if (await canLaunchUrl(uriNativa)) {
      return launchUrl(uriNativa);
    }
    // Fallback a Google Maps web
    final uriWeb = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query');
    return _abrir(uriWeb);
  }

  // ── Google Maps con coordenadas ─────────────────────────────────────────────
  static Future<bool> abrirMapsCoordenadas(
      double lat, double lng, {String? label}) async {
    final etiqueta = label != null ? Uri.encodeComponent(label) : '';
    final uriNativa = Uri.parse('geo:$lat,$lng?q=$lat,$lng($etiqueta)');
    if (await canLaunchUrl(uriNativa)) {
      return launchUrl(uriNativa);
    }
    final uriWeb = Uri.parse(
        'https://www.google.com/maps?q=$lat,$lng');
    return _abrir(uriWeb);
  }

  // ── Navegación GPS (ruta hacia destino) ────────────────────────────────────
  static Future<bool> navegar(String direccion) async {
    final query = Uri.encodeComponent(direccion);
    // Google Maps navegación
    final uriGmaps = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
    if (await canLaunchUrl(uriGmaps)) {
      return launchUrl(uriGmaps, mode: LaunchMode.externalApplication);
    }
    // Waze fallback
    final uriWaze = Uri.parse('waze://?q=$query&navigate=yes');
    if (await canLaunchUrl(uriWaze)) {
      return launchUrl(uriWaze);
    }
    return false;
  }

  // ── Helper interno ──────────────────────────────────────────────────────────
  static Future<bool> _abrir(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
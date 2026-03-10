import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UbicacionService — GPS real con geolocator
//
// Uso en home_repartidor.dart:
//   final _gps = UbicacionService();
//   await _gps.iniciarTracking();   // en initState / al activar disponible
//   _gps.detenerTracking();         // en dispose / al desactivar disponible
// ─────────────────────────────────────────────────────────────────────────────

class UbicacionService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _gpsSub;
  bool _tracking = false;

  // ── Iniciar tracking en tiempo real ────────────────────────────────────────
  Future<void> iniciarTracking() async {
    if (_tracking) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Verificar y solicitar permisos
    final ok = await _verificarPermisos();
    if (!ok) return;

    _tracking = true;

    // 2. Publicar ubicación inicial inmediatamente
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _publicar(uid, pos);
    } catch (_) {}

    // 3. Suscribirse a actualizaciones continuas
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // metros mínimos entre updates
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _publicar(uid, pos));
  }

  // ── Detener tracking ────────────────────────────────────────────────────────
  Future<void> detenerTracking() async {
    _tracking = false;
    await _gpsSub?.cancel();
    _gpsSub = null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Marcar como inactivo en Firestore (no borrar coords para historial)
    try {
      await _db.collection('ubicaciones').doc(uid).set({
        'activo': false,
        'ultimaVez': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Publicar posición en Firestore ──────────────────────────────────────────
  Future<void> _publicar(String uid, Position pos) async {
    try {
      await _db.collection('ubicaciones').doc(uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'precision': pos.accuracy,       // metros de precisión
        'velocidad': pos.speed,          // m/s
        'rumbo': pos.heading,            // grados 0-360
        'altitud': pos.altitude,
        'activo': true,
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Verificar permisos ──────────────────────────────────────────────────────
  static Future<bool> _verificarPermisos() async {
    // ¿Servicio GPS activado?
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // ¿Permiso concedido?
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // ── Obtener posición una sola vez (para cliente en tracking_page) ───────────
  static Future<({double lat, double lng})?> obtenerUnaVez() async {
    try {
      final ok = await _verificarPermisos();
      if (!ok) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Stream de ubicación del repartidor (para cliente) ──────────────────────
  static Stream<({double lat, double lng})?> streamUbicacionRepartidor(
      String repartidorId) {
    return FirebaseFirestore.instance
        .collection('ubicaciones')
        .doc(repartidorId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final d = doc.data()!;
      final activo = d['activo'] as bool? ?? false;
      if (!activo) return null;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    });
  }

  // ── Stream de velocidad del repartidor (extra para UI) ─────────────────────
  static Stream<double?> streamVelocidadRepartidor(String repartidorId) {
    return FirebaseFirestore.instance
        .collection('ubicaciones')
        .doc(repartidorId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final d = doc.data()!;
      final vel = (d['velocidad'] as num?)?.toDouble();
      if (vel == null) return null;
      return vel * 3.6; // m/s → km/h
    });
  }

  // ── Stream del estado del pedido ───────────────────────────────────────────
  static Stream<String> streamEstadoPedido(String pedidoId) {
    return FirebaseFirestore.instance
        .collection('pedidos')
        .doc(pedidoId)
        .snapshots()
        .map((doc) => doc.exists
            ? (doc.data()?['estado'] as String? ?? 'Pendiente')
            : 'Pendiente');
  }

  // ── Verificar si GPS está disponible (para mostrar UI condicional) ──────────
  static Future<bool> gpsDisponible() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }
}
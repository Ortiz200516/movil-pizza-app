import 'dart:js_interop';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// JS interop declarations
@JS('startWatchingPosition')
external JSNumber? _startWatch(JSFunction onSuccess, JSFunction onError);

@JS('stopWatchingPosition')
external void _stopWatch(JSNumber? watchId);

@JS('getCurrentPosition')
external void _getOnce(JSFunction onSuccess, JSFunction onError);

/// Publica la ubicación del repartidor en Firestore cada ~5 s (via watchPosition)
class UbicacionService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  JSNumber? _watchId;

  /// Inicia el tracking continuo del repartidor.
  void iniciarTracking() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _watchId = _startWatch(
      ((JSNumber lat, JSNumber lng, JSNumber acc) {
        _db.collection('ubicaciones').doc(uid).set({
          'lat': lat.toDartDouble,
          'lng': lng.toDartDouble,
          'precision': acc.toDartDouble,
          'actualizadoEn': FieldValue.serverTimestamp(),
          'activo': true,
        });
      }).toJS,
      ((JSString err) {
        // Error silencioso — no bloqueamos UI
      })
          .toJS,
    );
  }

  /// Detiene el tracking y marca al repartidor como inactivo.
  void detenerTracking() {
    _stopWatch(_watchId);
    _watchId = null;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _db.collection('ubicaciones').doc(uid).update({'activo': false});
  }

  /// Obtiene la ubicación actual una sola vez (para centrar el mapa del cliente).
  static Future<({double lat, double lng})?> obtenerUnaVez() async {
    final completer = _Completer<({double lat, double lng})?>();
    _getOnce(
      ((JSNumber lat, JSNumber lng) {
        completer.complete((lat: lat.toDartDouble, lng: lng.toDartDouble));
      }).toJS,
      ((JSString _) => completer.complete(null)).toJS,
    );
    return completer.future;
  }

  /// Stream del estado en tiempo real de un pedido.
  static Stream<String> streamEstadoPedido(String pedidoId) {
    return FirebaseFirestore.instance
        .collection('pedidos')
        .doc(pedidoId)
        .snapshots()
        .map((doc) => doc.exists
            ? (doc.data()?['estado'] as String? ?? 'Pendiente')
            : 'Pendiente');
  }

  /// Stream de la ubicación del repartidor asignado a un pedido.
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
}

// Mini completer para convertir callback → Future
class _Completer<T> {
  T? _value;
  bool _done = false;
  final List<Function(T)> _listeners = [];
  void complete(T value) {
    _value = value;
    _done = true;
    for (final l in _listeners) {
      l(value);
    }
  }

  Future<T> get future async {
    if (_done) return _value as T;
    await Future.delayed(const Duration(milliseconds: 100));
    return future;
  }
}

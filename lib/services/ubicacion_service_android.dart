import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UbicacionService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  void iniciarTracking() {
    // En Android el tracking GPS se implementa con geolocator
    // Por ahora stub — no bloquea la compilación
  }

  void detenerTracking() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _db.collection('ubicaciones').doc(uid).update({'activo': false});
  }

  static Future<({double lat, double lng})?> obtenerUnaVez() async {
    return null;
  }

  static Stream<String> streamEstadoPedido(String pedidoId) {
    return FirebaseFirestore.instance
        .collection('pedidos')
        .doc(pedidoId)
        .snapshots()
        .map((doc) => doc.exists
            ? (doc.data()?['estado'] as String? ?? 'Pendiente')
            : 'Pendiente');
  }

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
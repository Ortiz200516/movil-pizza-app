import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UbicacionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 📍 VERIFICAR Y SOLICITAR PERMISOS DE UBICACIÓN
  Future<bool> verificarPermisos() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 📍 OBTENER UBICACIÓN ACTUAL
  Future<Position?> obtenerUbicacionActual() async {
    try {
      final hasPermission = await verificarPermisos();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error al obtener ubicación: $e');
      return null;
    }
  }

  /// 🚚 ACTUALIZAR UBICACIÓN DEL REPARTIDOR EN FIRESTORE
  Future<void> actualizarUbicacionRepartidor(String repartidorId) async {
    try {
      final position = await obtenerUbicacionActual();
      if (position == null) return;

      await _db.collection('users').doc(repartidorId).update({
        'ubicacionActual': {
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'disponible': true,
      });
    } catch (e) {
      print('Error al actualizar ubicación: $e');
    }
  }

  /// 📡 STREAM DE UBICACIÓN EN TIEMPO REAL (para repartidores)
  Stream<Position> streamUbicacion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    );
  }

  /// 📍 OBTENER UBICACIÓN DE UN REPARTIDOR DESDE FIRESTORE
  Stream<Map<String, dynamic>?> obtenerUbicacionRepartidor(String repartidorId) {
    return _db.collection('users').doc(repartidorId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['ubicacionActual'] as Map<String, dynamic>?;
    });
  }

  /// 🎯 GUARDAR DIRECCIÓN DEL CLIENTE EN EL PEDIDO
  Future<void> guardarDireccionCliente({
    required String pedidoId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'direccionEntrega.coordenadas': {
          'lat': lat,
          'lng': lng,
        },
      });
    } catch (e) {
      print('Error al guardar coordenadas: $e');
    }
  }

  /// 📏 CALCULAR DISTANCIA ENTRE DOS PUNTOS (en metros)
  double calcularDistancia({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
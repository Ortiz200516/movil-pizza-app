import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  // Verificar y solicitar permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Abrir configuración de la app
      await openAppSettings();
      return false;
    }

    return true;
  }

  // Obtener ubicación actual una sola vez
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return null;
    }
  }

  // Iniciar tracking en tiempo real (para repartidores)
  Future<void> startTracking(String repartidorId, String pedidoId) async {
    if (_isTracking) {
      print('Ya hay un tracking activo');
      return;
    }

    bool hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      throw Exception('No hay permisos de ubicación');
    }

    _isTracking = true;

    // Configuración de tracking
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    // Escuchar cambios de posición
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Actualizar ubicación en Firestore
      _updateLocationInFirestore(repartidorId, pedidoId, position);
    });

    print('Tracking iniciado para repartidor: $repartidorId');
  }

  // Actualizar ubicación en Firestore
  Future<void> _updateLocationInFirestore(
    String repartidorId,
    String pedidoId,
    Position position,
  ) async {
    try {
      await _firestore.collection('tracking').doc(pedidoId).set({
        'repartidorId': repartidorId,
        'pedidoId': pedidoId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'speed': position.speed,
        'heading': position.heading,
      }, SetOptions(merge: true));

      print('Ubicación actualizada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error actualizando ubicación: $e');
    }
  }

  // Detener tracking
  Future<void> stopTracking(String pedidoId) async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;

    // Eliminar tracking de Firestore
    try {
      await _firestore.collection('tracking').doc(pedidoId).delete();
      print('Tracking detenido para pedido: $pedidoId');
    } catch (e) {
      print('Error eliminando tracking: $e');
    }
  }

  // Obtener stream de ubicación de un repartidor
  Stream<DocumentSnapshot> getDeliveryLocationStream(String pedidoId) {
    return _firestore.collection('tracking').doc(pedidoId).snapshots();
  }

  // Calcular distancia entre dos puntos (en metros)
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // Calcular tiempo estimado de llegada (en minutos)
  int calculateETA(double distanceInMeters, double speedInMetersPerSecond) {
    if (speedInMetersPerSecond <= 0) {
      // Velocidad promedio de moto en ciudad: 30 km/h = 8.33 m/s
      speedInMetersPerSecond = 8.33;
    }

    double timeInSeconds = distanceInMeters / speedInMetersPerSecond;
    return (timeInSeconds / 60).ceil(); // Convertir a minutos
  }

  // Estado del tracking
  bool get isTracking => _isTracking;
}
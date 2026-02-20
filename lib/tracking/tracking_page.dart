import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../models/pedido_model.dart';

class TrackingPage extends StatefulWidget {
  final PedidoModel pedido;

  const TrackingPage({super.key, required this.pedido});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  
  LatLng? _repartidorPosition;
  LatLng? _clientePosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  StreamSubscription<DocumentSnapshot>? _trackingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    // Obtener posición del cliente desde el pedido
    if (widget.pedido.direccionEntrega != null) {
      final lat = widget.pedido.direccionEntrega!['latitude'];
      final lng = widget.pedido.direccionEntrega!['longitude'];
      
      if (lat != null && lng != null) {
        _clientePosition = LatLng(lat, lng);
        _updateMarkers();
      }
    }

    // Escuchar ubicación del repartidor
    _trackingSubscription = _locationService
        .getDeliveryLocationStream(widget.pedido.id)
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final lat = data['latitude'];
        final lng = data['longitude'];

        if (lat != null && lng != null) {
          setState(() {
            _repartidorPosition = LatLng(lat, lng);
            _updateMarkers();
            _updatePolyline();
          });

          // Centrar mapa en el repartidor
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_repartidorPosition!),
          );
        }
      }
    });
  }

  void _updateMarkers() {
    _markers.clear();

    // Marcador del repartidor
    if (_repartidorPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('repartidor'),
          position: _repartidorPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: '🛵 Repartidor',
            snippet: 'En camino hacia ti',
          ),
        ),
      );
    }

    // Marcador del cliente
    if (_clientePosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('cliente'),
          position: _clientePosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: '🏠 Tu ubicación',
            snippet: 'Dirección de entrega',
          ),
        ),
      );
    }
  }

  void _updatePolyline() {
    if (_repartidorPosition != null && _clientePosition != null) {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_repartidorPosition!, _clientePosition!],
          color: Colors.blue,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }
  }

  double? _getDistance() {
    if (_repartidorPosition == null || _clientePosition == null) return null;

    return _locationService.calculateDistance(
      _repartidorPosition!.latitude,
      _repartidorPosition!.longitude,
      _clientePosition!.latitude,
      _clientePosition!.longitude,
    );
  }

  int? _getETA() {
    final distance = _getDistance();
    if (distance == null) return null;

    return _locationService.calculateETA(distance, 8.33); // Velocidad promedio de moto
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Tracking en Tiempo Real'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Información del pedido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(
                      'Estado',
                      widget.pedido.estado,
                      Icons.info_outline,
                      Colors.blue,
                    ),
                    if (_getDistance() != null)
                      _buildInfoChip(
                        'Distancia',
                        '${(_getDistance()! / 1000).toStringAsFixed(1)} km',
                        Icons.route,
                        Colors.orange,
                      ),
                    if (_getETA() != null)
                      _buildInfoChip(
                        'ETA',
                        '~${_getETA()} min',
                        Icons.timer,
                        Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.pedido.direccionEntrega?['direccion'] ?? 'Sin dirección',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: _clientePosition != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _clientePosition!,
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),

          // Botones de acción
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Llamar al repartidor
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📞 Llamando al repartidor...')),
                      );
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Llamar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _centerMapOnDelivery,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Centrar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _centerMapOnDelivery() {
    if (_repartidorPosition != null && _clientePosition != null) {
      // Calcular bounds para mostrar ambos marcadores
      final bounds = LatLngBounds(
        southwest: LatLng(
          _repartidorPosition!.latitude < _clientePosition!.latitude
              ? _repartidorPosition!.latitude
              : _clientePosition!.latitude,
          _repartidorPosition!.longitude < _clientePosition!.longitude
              ? _repartidorPosition!.longitude
              : _clientePosition!.longitude,
        ),
        northeast: LatLng(
          _repartidorPosition!.latitude > _clientePosition!.latitude
              ? _repartidorPosition!.latitude
              : _clientePosition!.latitude,
          _repartidorPosition!.longitude > _clientePosition!.longitude
              ? _repartidorPosition!.longitude
              : _clientePosition!.longitude,
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } else if (_repartidorPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_repartidorPosition!),
      );
    }
  }
}
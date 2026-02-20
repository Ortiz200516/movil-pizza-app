import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ubicacion_service.dart';
import 'dart:async';

class MapaRepartidorPage extends StatefulWidget {
  final String pedidoId;
  final String repartidorId;

  const MapaRepartidorPage({
    super.key,
    required this.pedidoId,
    required this.repartidorId,
  });

  @override
  State<MapaRepartidorPage> createState() => _MapaRepartidorPageState();
}

class _MapaRepartidorPageState extends State<MapaRepartidorPage> {
  final UbicacionService _ubicacionService = UbicacionService();
  GoogleMapController? _mapController;
  StreamSubscription? _ubicacionSubscription;

  LatLng? _ubicacionRepartidor;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _escucharUbicacionRepartidor();
  }

  void _escucharUbicacionRepartidor() {
    _ubicacionSubscription = _ubicacionService
        .obtenerUbicacionRepartidor(widget.repartidorId)
        .listen((ubicacion) {
      if (ubicacion != null && mounted) {
        final lat = ubicacion['lat'] as double;
        final lng = ubicacion['lng'] as double;

        setState(() {
          _ubicacionRepartidor = LatLng(lat, lng);
          _actualizarMarcador();
        });

        // Mover cámara a la nueva ubicación
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_ubicacionRepartidor!),
        );
      }
    });
  }

  void _actualizarMarcador() {
    if (_ubicacionRepartidor == null) return;

    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('repartidor'),
        position: _ubicacionRepartidor!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: '🚴 Tu Repartidor',
          snippet: 'En camino a tu dirección',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ubicacionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Ubicación del Repartidor'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _ubicacionRepartidor == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Esperando ubicación del repartidor...'),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _ubicacionRepartidor!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

                // Banner informativo
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.delivery_dining,
                              color: Colors.teal, size: 30),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Repartidor en camino',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tu pedido llegará pronto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ubicacion_service.dart';
import '../models/pedido_model.dart';
import 'dart:async';

class MapaEntregaPage extends StatefulWidget {
  final PedidoModel pedido;
  final String repartidorId;

  const MapaEntregaPage({
    super.key,
    required this.pedido,
    required this.repartidorId,
  });

  @override
  State<MapaEntregaPage> createState() => _MapaEntregaPageState();
}

class _MapaEntregaPageState extends State<MapaEntregaPage> {
  final UbicacionService _ubicacionService = UbicacionService();
  GoogleMapController? _mapController;
  StreamSubscription? _ubicacionSubscription;

  LatLng? _miUbicacion;
  LatLng? _ubicacionCliente;
  final Set<Marker> _markers = {};
  double? _distanciaEnMetros;

  @override
  void initState() {
    super.initState();
    _inicializarMapa();
  }

  Future<void> _inicializarMapa() async {
    // Obtener mi ubicación actual
    final position = await _ubicacionService.obtenerUbicacionActual();
    if (position != null && mounted) {
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      // Escuchar cambios en mi ubicación
      _escucharMiUbicacion();
    }

    // Verificar si el pedido tiene coordenadas del cliente
    if (widget.pedido.direccionEntrega != null &&
        widget.pedido.direccionEntrega!['coordenadas'] != null) {
      final coords = widget.pedido.direccionEntrega!['coordenadas'];
      setState(() {
        _ubicacionCliente = LatLng(coords['lat'], coords['lng']);
      });
    } else {
      // Si no hay coordenadas, usar ubicación por defecto (centro de la ciudad)
      setState(() {
        _ubicacionCliente = const LatLng(-2.1709979, -79.9223592); // Guayaquil
      });
    }

    _actualizarMarcadores();
    _calcularDistancia();
  }

  void _escucharMiUbicacion() {
    _ubicacionSubscription = _ubicacionService.streamUbicacion().listen(
      (position) {
        if (mounted) {
          setState(() {
            _miUbicacion = LatLng(position.latitude, position.longitude);
          });
          _actualizarMarcadores();
          _calcularDistancia();

          // Actualizar cámara para seguir al repartidor
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_miUbicacion!),
          );
        }
      },
    );
  }

  void _actualizarMarcadores() {
    _markers.clear();

    // Marcador de mi ubicación (repartidor)
    if (_miUbicacion != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('repartidor'),
          position: _miUbicacion!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan,
          ),
          infoWindow: const InfoWindow(
            title: '🚴 Tu ubicación',
            snippet: 'Repartidor',
          ),
        ),
      );
    }

    // Marcador de la ubicación del cliente
    if (_ubicacionCliente != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('cliente'),
          position: _ubicacionCliente!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: '🏠 Cliente',
            snippet: widget.pedido.direccionEntrega?['direccion'] ?? 'Destino',
          ),
        ),
      );
    }

    setState(() {});
  }

  void _calcularDistancia() {
    if (_miUbicacion != null && _ubicacionCliente != null) {
      final distancia = _ubicacionService.calcularDistancia(
        lat1: _miUbicacion!.latitude,
        lng1: _miUbicacion!.longitude,
        lat2: _ubicacionCliente!.latitude,
        lng2: _ubicacionCliente!.longitude,
      );

      setState(() {
        _distanciaEnMetros = distancia;
      });
    }
  }

  String _formatearDistancia() {
    if (_distanciaEnMetros == null) return 'Calculando...';
    
    if (_distanciaEnMetros! < 1000) {
      return '${_distanciaEnMetros!.toStringAsFixed(0)} metros';
    } else {
      final km = _distanciaEnMetros! / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
  }

  void _centrarEnAmbos() {
    if (_miUbicacion != null && _ubicacionCliente != null && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _miUbicacion!.latitude < _ubicacionCliente!.latitude
              ? _miUbicacion!.latitude
              : _ubicacionCliente!.latitude,
          _miUbicacion!.longitude < _ubicacionCliente!.longitude
              ? _miUbicacion!.longitude
              : _ubicacionCliente!.longitude,
        ),
        northeast: LatLng(
          _miUbicacion!.latitude > _ubicacionCliente!.latitude
              ? _miUbicacion!.latitude
              : _ubicacionCliente!.latitude,
          _miUbicacion!.longitude > _ubicacionCliente!.longitude
              ? _miUbicacion!.longitude
              : _ubicacionCliente!.longitude,
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
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
        title: const Text('🗺️ Mapa de Entrega'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Centrar mapa',
            onPressed: _centrarEnAmbos,
          ),
        ],
      ),
      body: _miUbicacion == null || _ubicacionCliente == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Obteniendo ubicación...'),
                ],
              ),
            )
          : Stack(
              children: [
                // Mapa
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _miUbicacion!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Centrar en ambas ubicaciones al crear el mapa
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _centrarEnAmbos();
                    });
                  },
                ),

                // Panel de información superior
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.navigation,
                                color: Colors.teal,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pedido #${widget.pedido.id.substring(0, 6)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Distancia:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _formatearDistancia(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Panel de información del pedido (inferior)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Dirección de entrega:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.pedido.direccionEntrega?['direccion'] ??
                                'Sin dirección especificada',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (widget.pedido.direccionEntrega?['referencia'] !=
                                  null &&
                              widget.pedido.direccionEntrega!['referencia']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ref: ${widget.pedido.direccionEntrega!['referencia']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total del pedido:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '\$${widget.pedido.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
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
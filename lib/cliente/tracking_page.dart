import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pedido_model.dart';
import '../services/ubicacion_service.dart';

/// Página que el CLIENTE abre para ver dónde está su repartidor en tiempo real.
class TrackingClientePage extends StatefulWidget {
  final PedidoModel pedido;
  const TrackingClientePage({super.key, required this.pedido});
  @override
  State<TrackingClientePage> createState() => _TrackingClientePageState();
}

class _TrackingClientePageState extends State<TrackingClientePage> {
  GoogleMapController? _mapCtrl;
  StreamSubscription?  _sub;
  LatLng? _posRepartidor;
  LatLng? _posCliente;
  bool    _centrado = false;

  // Coordenadas de la pizzería (origen)
  static const _pizzeria = LatLng(-2.1894, -79.8891); // Guayaquil — ajusta según tu local

  @override
  void initState() {
    super.initState();
    _iniciarTracking();
    _obtenerPosCliente();
  }

  void _iniciarTracking() {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;

    _sub = UbicacionService.streamUbicacionRepartidor(rid).listen((pos) {
      if (!mounted) return;
      setState(() {
        _posRepartidor = pos != null ? LatLng(pos.lat, pos.lng) : null;
      });
      // Centrar mapa la primera vez que llega posición
      if (pos != null && !_centrado && _mapCtrl != null) {
        _centrado = true;
        _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(pos.lat, pos.lng), 15));
      }
    });
  }

  Future<void> _obtenerPosCliente() async {
    final pos = await UbicacionService.obtenerUnaVez();
    if (pos != null && mounted) {
      setState(() => _posCliente = LatLng(pos.lat, pos.lng));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Set<Marker> get _markers {
    final m = <Marker>{};

    // Marcador pizzería
    m.add(const Marker(
      markerId: MarkerId('pizzeria'),
      position: _pizzeria,
      infoWindow: InfoWindow(title: '🍕 La Pizzería'),
    ));

    // Marcador cliente
    if (_posCliente != null) {
      m.add(Marker(
        markerId: const MarkerId('cliente'),
        position: _posCliente!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Tu ubicación'),
      ));
    }

    // Marcador repartidor
    if (_posRepartidor != null) {
      m.add(Marker(
        markerId: const MarkerId('repartidor'),
        position: _posRepartidor!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: '🛵 Repartidor en camino',
          snippet: 'Pedido #${widget.pedido.id.substring(0, 6).toUpperCase()}',
        ),
      ));
    }

    return m;
  }

  LatLng get _centroInicial {
    if (_posCliente != null) return _posCliente!;
    final dir = widget.pedido.direccionEntrega;
    if (dir?['lat'] != null && dir?['lng'] != null) {
      return LatLng((dir!['lat'] as num).toDouble(), (dir['lng'] as num).toDouble());
    }
    return _pizzeria;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🛵 Seguimiento en vivo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('Pedido #${widget.pedido.id.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      ),
      body: Column(children: [
        // Banner estado
        _BannerEstado(pedido: widget.pedido, posRepartidor: _posRepartidor),

        // Mapa
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _centroInicial, zoom: 14),
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) => setState(() => _mapCtrl = ctrl),
          ),
        ),

        // Panel inferior
        _PanelInfo(pedido: widget.pedido, posRepartidor: _posRepartidor),
      ]),
    );
  }
}

class _BannerEstado extends StatelessWidget {
  final PedidoModel pedido;
  final LatLng?     posRepartidor;
  const _BannerEstado({required this.pedido, required this.posRepartidor});

  @override
  Widget build(BuildContext context) {
    final activo = posRepartidor != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activo
              ? [Colors.indigo.shade800, Colors.indigo.shade600]
              : [Colors.grey.shade800, Colors.grey.shade700],
        ),
      ),
      child: Row(children: [
        Text(activo ? '🛵' : '⏳', style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            activo ? '¡Tu repartidor está en camino!' : 'Esperando ubicación del repartidor...',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            activo ? 'Ubicación actualizándose en tiempo real' : 'Se mostrará cuando inicie la entrega',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ]),
        const Spacer(),
        if (activo)
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
          ),
      ]),
    );
  }
}

class _PanelInfo extends StatelessWidget {
  final PedidoModel pedido;
  final LatLng?     posRepartidor;
  const _PanelInfo({required this.pedido, required this.posRepartidor});

  @override
  Widget build(BuildContext context) {
    final dir = pedido.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref = pedido.direccionEntrega?['referencia'] ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E293B),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.location_on, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Entregando en:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text(dir, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (ref.isNotEmpty)
              Text(ref, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Código de entrega: ${pedido.codigoVerificacion}',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold,
                  fontSize: 16, letterSpacing: 4),
            ),
          ]),
        ),
      ]),
    );
  }
}
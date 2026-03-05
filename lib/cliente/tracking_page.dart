import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pedido_model.dart';
import '../services/ubicacion_service.dart';

class TrackingClientePage extends StatefulWidget {
  final PedidoModel pedido;
  const TrackingClientePage({super.key, required this.pedido});
  @override
  State<TrackingClientePage> createState() => _TrackingClientePageState();
}

class _TrackingClientePageState extends State<TrackingClientePage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  StreamSubscription?  _subUbic;
  StreamSubscription?  _subPedido;

  LatLng? _posRepartidor;
  LatLng? _posCliente;
  String  _estadoActual  = '';
  bool    _centrado      = false;
  Map<String, dynamic>? _datosRepartidor;
  int?    _minutosEstimados;
  double? _distanciaKm;

  late AnimationController _pulseCtrl;

  static const _pizzeria = LatLng(-2.1894, -79.8891);

  static const _pasos = [
    ('Pendiente',  '⏳', 'Pedido\nrecibido'),
    ('Preparando', '👨‍🍳', 'En la\ncocina'),
    ('Listo',      '✅', 'Listo para\nentregar'),
    ('En camino',  '🛵', 'En\ncamino'),
    ('Entregado',  '📦', 'Entregado'),
  ];

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.pedido.estado;
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _iniciarTracking();
    _obtenerPosCliente();
    _escucharEstadoPedido();
    _cargarDatosRepartidor();
  }

  void _iniciarTracking() {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;
    _subUbic = UbicacionService.streamUbicacionRepartidor(rid).listen((pos) {
      if (!mounted) return;
      setState(() {
        _posRepartidor = pos != null ? LatLng(pos.lat, pos.lng) : null;
        if (_posRepartidor != null && _posCliente != null) {
          _distanciaKm = _calcularDistancia(_posRepartidor!, _posCliente!);
          _minutosEstimados = (_distanciaKm! / 0.5).round().clamp(1, 60);
        }
      });
      if (pos != null && !_centrado && _mapCtrl != null) {
        _centrado = true;
        _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lng), 15));
      }
    });
  }

  void _escucharEstadoPedido() {
    _subPedido = UbicacionService.streamEstadoPedido(widget.pedido.id).listen((estado) {
      if (!mounted) return;
      setState(() => _estadoActual = estado);
    });
  }

  Future<void> _obtenerPosCliente() async {
    final pos = await UbicacionService.obtenerUnaVez();
    if (pos != null && mounted) setState(() => _posCliente = LatLng(pos.lat, pos.lng));
  }

  Future<void> _cargarDatosRepartidor() async {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(rid).get();
      if (doc.exists && mounted) setState(() => _datosRepartidor = doc.data());
    } catch (_) {}
  }

  // Fórmula Haversine para distancia en km
  double _calcularDistancia(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }
  double _toRad(double deg) => deg * pi / 180;

  @override
  void dispose() {
    _subUbic?.cancel();
    _subPedido?.cancel();
    _mapCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  int get _pasoActual {
    final idx = _pasos.indexWhere((p) => p.$1 == _estadoActual);
    return idx >= 0 ? idx : 0;
  }

  bool get _estaEnCamino => _estadoActual == 'En camino';
  bool get _entregado    => _estadoActual == 'Entregado';

  Set<Marker> get _markers {
    final m = <Marker>{};
    m.add(const Marker(
      markerId: MarkerId('pizzeria'),
      position: _pizzeria,
      infoWindow: InfoWindow(title: '🍕 La Pizzería'),
    ));
    if (_posCliente != null) {
      m.add(Marker(
        markerId: const MarkerId('cliente'),
        position: _posCliente!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Tu ubicación'),
      ));
    }
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
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
        actions: [
          if (_estaEnCamino && _posRepartidor != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
              tooltip: 'Centrar en repartidor',
              onPressed: () => _mapCtrl?.animateCamera(
                  CameraUpdate.newLatLngZoom(_posRepartidor!, 15)),
            ),
        ],
      ),
      body: Column(children: [

        // ── Línea de tiempo ──────────────────────────────────────
        _LineaTiempo(pasos: _pasos, pasoActual: _pasoActual),

        // ── Tiempo estimado ──────────────────────────────────────
        if (_estaEnCamino)
          _BannerTiempoEstimado(
            minutos: _minutosEstimados,
            distanciaKm: _distanciaKm,
          ),

        // ── Mapa ─────────────────────────────────────────────────
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _centroInicial, zoom: 14),
              markers: _markers,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (ctrl) => setState(() => _mapCtrl = ctrl),
            ),

            // Indicador GPS en vivo
            if (_estaEnCamino)
              Positioned(
                top: 12, right: 12,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.4 + _pulseCtrl.value * 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.6 + _pulseCtrl.value * 0.4),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3 + _pulseCtrl.value * 0.3), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('En vivo',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),

            // Pantalla entregado
            if (_entregado)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎉', style: TextStyle(fontSize: 70)),
                  const SizedBox(height: 16),
                  const Text('¡Pedido entregado!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('¡Buen provecho!',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ])),
              ),
          ]),
        ),

        // ── Panel inferior ────────────────────────────────────────
        _PanelInferior(
          pedido: widget.pedido,
          posRepartidor: _posRepartidor,
          datosRepartidor: _datosRepartidor,
        ),
      ]),
    );
  }
}

// ── Banner tiempo estimado ────────────────────────────────────
class _BannerTiempoEstimado extends StatelessWidget {
  final int? minutos;
  final double? distanciaKm;
  const _BannerTiempoEstimado({this.minutos, this.distanciaKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('⏱️', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tiempo estimado de llegada',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          Text(
            minutos != null ? '$minutos minutos aprox.' : 'Calculando...',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ])),
        if (distanciaKm != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Text(
              distanciaKm! < 1
                  ? '${(distanciaKm! * 1000).round()} m'
                  : '${distanciaKm!.toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
      ]),
    );
  }
}

// ── Línea de tiempo ───────────────────────────────────────────
class _LineaTiempo extends StatelessWidget {
  final List<(String, String, String)> pasos;
  final int pasoActual;
  const _LineaTiempo({required this.pasos, required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(pasos.length * 2 - 1, (i) {
            if (i.isOdd) {
              final completado = i ~/ 2 < pasoActual;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 32, height: 2,
                decoration: BoxDecoration(
                  color: completado ? const Color(0xFFFF6B00) : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }
            final idx        = i ~/ 2;
            final completado = idx < pasoActual;
            final activo     = idx == pasoActual;
            final (_, emoji, label) = pasos[idx];

            return Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completado
                      ? const Color(0xFFFF6B00)
                      : activo
                          ? const Color(0xFFFF6B00).withOpacity(0.15)
                          : const Color(0xFF1E293B),
                  border: Border.all(
                    color: (completado || activo) ? const Color(0xFFFF6B00) : Colors.white12,
                    width: activo ? 2.5 : 1.5,
                  ),
                  boxShadow: activo
                      ? [BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
                child: Center(child: Text(
                  completado ? '✓' : emoji,
                  style: TextStyle(fontSize: completado ? 16 : 18,
                      color: completado ? Colors.white : null),
                )),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 60,
                child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (completado || activo) ? Colors.white70 : Colors.white24,
                    fontSize: 9,
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    height: 1.3,
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

// ── Panel inferior ────────────────────────────────────────────
class _PanelInferior extends StatelessWidget {
  final PedidoModel pedido;
  final LatLng? posRepartidor;
  final Map<String, dynamic>? datosRepartidor;
  const _PanelInferior({required this.pedido, this.posRepartidor, this.datosRepartidor});

  @override
  Widget build(BuildContext context) {
    final dir = pedido.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref = pedido.direccionEntrega?['referencia'] ?? '';
    final nombre    = datosRepartidor?['nombres'] ?? datosRepartidor?['nombre'] ?? 'Repartidor';
    final telefono  = datosRepartidor?['telefono'] as String?;
    final fotoUrl   = datosRepartidor?['fotoUrl'] as String?;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // ── Info repartidor ──────────────────────────────────────
        if (datosRepartidor != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.indigo.withOpacity(0.2),
                backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                child: fotoUrl == null
                    ? Text(nombre[0].toUpperCase(),
                        style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tu repartidor', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Row(children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('En camino', style: TextStyle(color: Colors.green, fontSize: 11)),
                ]),
              ])),

              // Botones contacto
              if (telefono != null) ...[
                _BotonContacto(
                  icono: Icons.phone,
                  color: Colors.green,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: telefono));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Teléfono copiado: $telefono'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
                const SizedBox(width: 8),
                _BotonContacto(
                  icono: Icons.chat,
                  color: Colors.teal,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: telefono));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('WhatsApp: $telefono'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Dirección ────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('📍', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dirección de entrega', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(dir, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            if (ref.isNotEmpty)
              Text(ref, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ])),
        ]),

        const SizedBox(height: 12),

        // ── Código de verificación ───────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.orange.withOpacity(0.12),
              Colors.orange.withOpacity(0.06),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Text('🔑', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Código de entrega', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text(
                pedido.codigoVerificacion ?? '----',
                style: const TextStyle(color: Colors.orange, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: 6),
              ),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Dáselo al', style: TextStyle(color: Colors.white24, fontSize: 10)),
              const Text('repartidor', style: TextStyle(color: Colors.white24, fontSize: 10)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pedido.codigoVerificacion ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado ✅'), duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.copy, color: Colors.orange, size: 14),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _BotonContacto extends StatelessWidget {
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  const _BotonContacto({required this.icono, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icono, color: color, size: 18),
    ),
  );
}
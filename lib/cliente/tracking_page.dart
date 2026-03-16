import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pedido_model.dart';
import '../services/ubicacion_service.dart';
import 'chat_page.dart';

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
  String  _estadoActual = '';
  bool    _centrado = false;

  late AnimationController _pulseCtrl;

  static const _pizzeria = LatLng(-2.1894, -79.8891);

  static const _pasos = [
    ('Pendiente',  '⏳', 'Pedido recibido'),
    ('Preparando', '👨‍🍳', 'En la cocina'),
    ('Listo',      '✅', 'Listo para entregar'),
    ('En camino',  '🛵', 'En camino'),
    ('Entregado',  '📦', 'Entregado'),
  ];

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.pedido.estado;
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _iniciarTracking();
    _obtenerPosCliente();
    _escucharEstadoPedido();
  }

  void _iniciarTracking() {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;
    _subUbic = UbicacionService.streamUbicacionRepartidor(rid).listen((pos) {
      if (!mounted) return;
      setState(() {
        _posRepartidor = pos != null ? LatLng(pos.lat, pos.lng) : null;
      });
      if (pos != null && !_centrado && _mapCtrl != null) {
        _centrado = true;
        _mapCtrl!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lng), 15));
      }
    });
  }

  void _escucharEstadoPedido() {
    _subPedido = UbicacionService.streamEstadoPedido(widget.pedido.id)
        .listen((estado) {
      if (!mounted) return;
      setState(() => _estadoActual = estado);
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
      return LatLng((dir!['lat'] as num).toDouble(),
          (dir['lng'] as num).toDouble());
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
          // Botón chat — solo visible cuando está en camino
          if (_estaEnCamino && widget.pedido.repartidorId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChatBadge(
                pedidoId:     widget.pedido.id,
                clienteId:    widget.pedido.clienteId,
                repartidorId: widget.pedido.repartidorId,
                rolActual:    'cliente',
                nombreOtro:   'Tu repartidor',
              ),
            ),
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

        // ── Línea de tiempo ──────────────────────────────────────────────────
        _LineaTiempo(pasos: _pasos, pasoActual: _pasoActual),

        // ── Mapa ─────────────────────────────────────────────────────────────
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: _centroInicial, zoom: 14),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green
                              .withValues(alpha: 0.4 + _pulseCtrl.value * 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green
                              .withValues(alpha: 0.6 + _pulseCtrl.value * 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('En vivo',
                          style: TextStyle(color: Colors.white70,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),

            // Overlay entregado
            if (_entregado)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎉', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  const Text('¡Pedido entregado!',
                      style: TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Gracias por tu preferencia',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14)),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Volver',
                        style: TextStyle(color: Colors.orange, fontSize: 15)),
                  ),
                ])),
              ),
          ]),
        ),

        // ── Panel inferior ────────────────────────────────────────────────────
        _PanelInferior(
          pedido:        widget.pedido,
          posRepartidor: _posRepartidor,
          estaEnCamino:  _estaEnCamino,
        ),
      ]),
    );
  }
}

// ── Línea de tiempo ───────────────────────────────────────────────────────────
class _LineaTiempo extends StatelessWidget {
  final List<(String, String, String)> pasos;
  final int pasoActual;
  const _LineaTiempo({required this.pasos, required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(pasos.length * 2 - 1, (i) {
            if (i.isOdd) {
              final completado = i ~/ 2 < pasoActual;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 28, height: 2,
                color: completado ? const Color(0xFFFF6B00) : Colors.white12,
              );
            }
            final idx        = i ~/ 2;
            final completado = idx < pasoActual;
            final activo     = idx == pasoActual;
            final (_, emoji, label) = pasos[idx];

            return Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completado
                      ? const Color(0xFFFF6B00)
                      : activo
                          ? const Color(0xFFFF6B00).withValues(alpha: 0.2)
                          : const Color(0xFF1E293B),
                  border: Border.all(
                    color: (completado || activo)
                        ? const Color(0xFFFF6B00) : Colors.white12,
                    width: activo ? 2 : 1.5,
                  ),
                ),
                child: Center(child: Text(
                  completado ? '✓' : emoji,
                  style: TextStyle(
                    fontSize: completado ? 14 : 16,
                    color: completado ? Colors.white : null,
                  ),
                )),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (completado || activo)
                        ? Colors.white70 : Colors.white24,
                    fontSize: 9,
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
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

// ── Panel inferior ────────────────────────────────────────────────────────────
class _PanelInferior extends StatelessWidget {
  final PedidoModel pedido;
  final LatLng? posRepartidor;
  final bool estaEnCamino;
  const _PanelInferior({
    required this.pedido,
    required this.posRepartidor,
    required this.estaEnCamino,
  });

  @override
  Widget build(BuildContext context) {
    final dir = pedido.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref = pedido.direccionEntrega?['referencia'] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Dirección
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('📍', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text('Dirección de entrega',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(dir, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            if (ref.isNotEmpty)
              Text(ref, style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
          ])),
        ]),

        const SizedBox(height: 12),

        // Botón chat — solo cuando está en camino
        if (estaEnCamino && pedido.repartidorId != null) ...[
          ChatBadge(
            pedidoId:     pedido.id,
            clienteId:    pedido.clienteId,
            repartidorId: pedido.repartidorId,
            rolActual:    'cliente',
            nombreOtro:   'Tu repartidor',
          ),
          const SizedBox(height: 12),
        ],

        // Código de verificación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.orange.withValues(alpha: 0.12),
              Colors.orange.withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Text('🔐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Código de entrega',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text(
                pedido.codigoVerificacion ?? '----',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ]),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white38, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: pedido.codigoVerificacion ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
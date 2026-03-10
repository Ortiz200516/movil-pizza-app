import 'dart:async';
import 'dart:math' show sqrt, sin, cos, atan2, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../cliente/chat_page.dart';
import '../models/pedido_model.dart';
import '../services/ubicacion_service.dart';

const _kOrange = Color(0xFFFF6B00);
const _kBg     = Color(0xFF0F172A);
const _kCard   = Color(0xFF1E293B);

class TrackingClientePage extends StatefulWidget {
  final PedidoModel pedido;
  const TrackingClientePage({super.key, required this.pedido});
  @override State<TrackingClientePage> createState() => _TrackingClientePageState();
}

class _TrackingClientePageState extends State<TrackingClientePage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  StreamSubscription?  _subUbic;
  StreamSubscription?  _subPedido;

  LatLng? _posRepartidor;
  LatLng? _posCliente;
  String  _estadoActual = '';
  String  _nombreRepartidor = '';
  bool    _centrado = false;
  bool    _panelExpandido = false;

  late AnimationController _pulseCtrl;
  late Timer _clockTimer;
  late DateTime _ahora;

  static const _pizzeria = LatLng(-2.1894, -79.8891);

  static const _pasos = [
    ('Pendiente',  '⏳', 'Recibido'),
    ('Preparando', '👨‍🍳', 'En cocina'),
    ('Listo',      '✅', 'Listo'),
    ('En camino',  '🛵', 'En camino'),
    ('Entregado',  '🎉', 'Entregado'),
  ];

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.pedido.estado;
    _ahora = DateTime.now();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _ahora = DateTime.now()); });
    _iniciarTracking();
    _obtenerPosCliente();
    _escucharEstadoPedido();
    _cargarNombreRepartidor();
  }

  void _iniciarTracking() {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;
    _subUbic = UbicacionService.streamUbicacionRepartidor(rid).listen((pos) {
      if (!mounted) return;
      setState(() => _posRepartidor = pos != null ? LatLng(pos.lat, pos.lng) : null);
      if (pos != null && !_centrado && _mapCtrl != null) {
        _centrado = true;
        _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lng), 15));
      }
    });
  }

  void _escucharEstadoPedido() {
    _subPedido = UbicacionService.streamEstadoPedido(widget.pedido.id).listen((estado) {
      if (!mounted) return;
      final anterior = _estadoActual;
      setState(() => _estadoActual = estado);
      if (anterior != estado) HapticFeedback.mediumImpact();
    });
  }

  Future<void> _obtenerPosCliente() async {
    final pos = await UbicacionService.obtenerUnaVez();
    if (pos != null && mounted) setState(() => _posCliente = LatLng(pos.lat, pos.lng));
  }

  Future<void> _cargarNombreRepartidor() async {
    final rid = widget.pedido.repartidorId;
    if (rid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(rid).get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _nombreRepartidor = data['nombre'] as String? ??
            (data['email'] as String? ?? '').split('@').first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subUbic?.cancel();
    _subPedido?.cancel();
    _mapCtrl?.dispose();
    _pulseCtrl.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  int get _pasoActual {
    final idx = _pasos.indexWhere((p) => p.$1 == _estadoActual);
    return idx >= 0 ? idx : 0;
  }

  bool get _estaEnCamino => _estadoActual == 'En camino';
  bool get _entregado    => _estadoActual == 'Entregado';

  String get _etaTexto {
    if (!_estaEnCamino || _posRepartidor == null || _posCliente == null) return '';
    final km = _distanciaKm(_posRepartidor!, _posCliente!);
    final mins = ((km / 30.0) * 60).ceil();
    if (mins <= 1) return '~1 min';
    if (mins >= 60) return '~${mins ~/ 60}h ${mins % 60}m';
    return '~$mins min';
  }

  double _distanciaKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }
  double _deg2rad(double d) => d * pi / 180;

  String get _tiempoEnCamino {
    if (!_estaEnCamino) return '';
    final diff = _ahora.difference(widget.pedido.fecha);
    final mm = diff.inMinutes.toString().padLeft(2, '0');
    final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Set<Marker> get _markers {
    final m = <Marker>{};
    m.add(const Marker(markerId: MarkerId('pizzeria'), position: _pizzeria,
        infoWindow: InfoWindow(title: '🍕 La Pizzería')));
    if (_posCliente != null) {
      m.add(Marker(markerId: const MarkerId('cliente'), position: _posCliente!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: '📍 Tu ubicación')));
    }
    if (_posRepartidor != null) {
      m.add(Marker(markerId: const MarkerId('repartidor'), position: _posRepartidor!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '🛵 ${_nombreRepartidor.isNotEmpty ? _nombreRepartidor : "Repartidor"}',
            snippet: 'Pedido #${widget.pedido.id.substring(0, 6).toUpperCase()}',
          )));
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
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        // Mapa fondo completo
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _centroInicial, zoom: 14),
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) => setState(() => _mapCtrl = ctrl),
          ),
        ),

        // Overlay entregado
        if (_entregado)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.65),
              child: Center(child: _EntregadoOverlay(
                  pedido: widget.pedido,
                  onCerrar: () => Navigator.pop(context))),
            ),
          ),

        // AppBar flotante
        Positioned(top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: topPad + 4, left: 8, right: 8, bottom: 8),
            decoration: BoxDecoration(color: _kBg.withOpacity(0.92),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)]),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🛵 Seguimiento en vivo', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Pedido #${widget.pedido.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
              if (_estaEnCamino && _posRepartidor != null)
                IconButton(icon: const Icon(Icons.my_location, color: _kOrange),
                    onPressed: () => _mapCtrl?.animateCamera(
                        CameraUpdate.newLatLngZoom(_posRepartidor!, 15))),
            ]),
          ),
        ),

        // Línea de tiempo flotante
        Positioned(top: topPad + 70, left: 0, right: 0,
          child: _LineaTiempoFlotante(pasos: _pasos, pasoActual: _pasoActual),
        ),

        // Chips En vivo + timer
        if (_estaEnCamino)
          Positioned(top: topPad + 148, right: 12,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kBg.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.4 + _pulseCtrl.value * 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.6 + _pulseCtrl.value * 0.4),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3 + _pulseCtrl.value * 0.3), blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('En vivo', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
                
                if (_tiempoEnCamino.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kBg.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text('⏱ $_tiempoEnCamino',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                  ),
                ],
              ]),
            ),
          ),

        // Panel inferior
        Positioned(bottom: 0, left: 0, right: 0,
          child: _PanelInferior(
            pedido: widget.pedido,
            posRepartidor: _posRepartidor,
            nombreRepartidor: _nombreRepartidor,
            estadoActual: _estadoActual,
            etaTexto: _etaTexto,
            expandido: _panelExpandido,
            onToggle: () => setState(() => _panelExpandido = !_panelExpandido),
          ),
        ),
      ]),
    );
  }
}

// ── Línea de tiempo ──────────────────────────────────────────────────────────
class _LineaTiempoFlotante extends StatelessWidget {
  final List<(String, String, String)> pasos;
  final int pasoActual;
  const _LineaTiempoFlotante({required this.pasos, required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg.withOpacity(0.92),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(pasos.length * 2 - 1, (i) {
            if (i.isOdd) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 24, height: 2,
                color: i ~/ 2 < pasoActual ? _kOrange : Colors.white12,
              );
            }
            final idx = i ~/ 2;
            final completado = idx < pasoActual;
            final activo = idx == pasoActual;
            final (_, emoji, label) = pasos[idx];
            return Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completado ? _kOrange : activo ? _kOrange.withOpacity(0.2) : _kCard,
                  border: Border.all(
                    color: (completado || activo) ? _kOrange : Colors.white12,
                    width: activo ? 2.5 : 1.5,
                  ),
                  boxShadow: activo ? [BoxShadow(color: _kOrange.withOpacity(0.3), blurRadius: 8)] : null,
                ),
                child: Center(child: Text(completado ? '✓' : emoji,
                    style: TextStyle(fontSize: completado ? 14 : 16,
                        color: completado ? Colors.white : null))),
              ),
              const SizedBox(height: 4),
              SizedBox(width: 54, child: Text(label, textAlign: TextAlign.center,
                style: TextStyle(
                  color: (completado || activo) ? Colors.white70 : Colors.white24,
                  fontSize: 9,
                  fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                ))),
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
  final String nombreRepartidor, estadoActual, etaTexto;
  final bool expandido;
  final VoidCallback onToggle;
  const _PanelInferior({
    required this.pedido, required this.posRepartidor,
    required this.nombreRepartidor, required this.estadoActual,
    required this.etaTexto, required this.expandido, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dir = pedido.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref = pedido.direccionEntrega?['referencia'] as String? ?? '';
    final estaEnCamino = estadoActual == 'En camino';
    final mostrarCodigo = estaEnCamino || estadoActual == 'Listo';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle + toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(children: [
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              Row(children: [
                _EstadoBadge(estado: estadoActual),
                const Spacer(),
                if (etaTexto.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kOrange.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined, color: _kOrange, size: 13),
                      const SizedBox(width: 4),
                      Text(etaTexto, style: const TextStyle(color: _kOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                const SizedBox(width: 8),
                Icon(expandido ? Icons.expand_more : Icons.expand_less, color: Colors.white38, size: 20),
              ]),
            ]),
          ),
        ),

        // Código verificación
        if (mostrarCodigo)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _CodigoVerificacion(codigo: pedido.codigoVerificacion ?? '----'),
          ),

        // Panel expandible
        if (expandido) ...[
          // Repartidor
          if (estaEnCamino && nombreRepartidor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Row(children: [
                  Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: _kOrange.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Center(child: Text('🛵', style: TextStyle(fontSize: 18)))),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tu repartidor', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(nombreRepartidor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const Spacer(),
                  if (posRepartidor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3))),
                      child: const Text('GPS activo', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
            ),

          // Dirección
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Dirección de entrega', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(dir, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (ref.isNotEmpty) Text(ref, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
              ]),
            ),
          ),

          // Items del pedido
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Tu pedido', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('\$${pedido.total.toStringAsFixed(2)}',
                      style: const TextStyle(color: _kOrange, fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                ...pedido.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(width: 20, height: 20,
                      decoration: BoxDecoration(color: _kOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text('${item['cantidad'] ?? 1}',
                          style: const TextStyle(color: _kOrange, fontSize: 9, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item['productoNombre'] ?? item['nombre'] ?? '',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('\$${((item['precioTotal'] ?? 0.0) as num).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ]),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Código de verificación ────────────────────────────────────────────────────
class _CodigoVerificacion extends StatelessWidget {
  final String codigo;
  const _CodigoVerificacion({required this.codigo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kOrange.withOpacity(0.14), _kOrange.withOpacity(0.06)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOrange.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Text('🔐', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tu código de entrega', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(codigo, style: const TextStyle(color: _kOrange, fontSize: 30,
              fontWeight: FontWeight.w900, letterSpacing: 8)),
          const Text('Dáselo al repartidor al recibir tu pedido',
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: codigo));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('📋 Código copiado'),
              backgroundColor: _kOrange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kOrange.withOpacity(0.3)),
            ),
            child: const Icon(Icons.copy, color: _kOrange, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Badge estado ──────────────────────────────────────────────────────────────
class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});
  Color get _color { switch (estado) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return Colors.blue;
    case 'Listo':      return Colors.teal;
    case 'En camino':  return _kOrange;
    case 'Entregado':  return Colors.green;
    default:           return Colors.grey;
  }}
  String get _emoji { switch (estado) {
    case 'Pendiente':  return '⏳';
    case 'Preparando': return '👨‍🍳';
    case 'Listo':      return '✅';
    case 'En camino':  return '🛵';
    case 'Entregado':  return '🎉';
    default:           return '❓';
  }}
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(_emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text(estado, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
    ]),
  );
}

// ── Overlay entregado ─────────────────────────────────────────────────────────
class _EntregadoOverlay extends StatefulWidget {
  final PedidoModel pedido;
  final VoidCallback onCerrar;
  const _EntregadoOverlay({required this.pedido, required this.onCerrar});
  @override State<_EntregadoOverlay> createState() => _EntregadoOverlayState();
}

class _EntregadoOverlayState extends State<_EntregadoOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 30, spreadRadius: 4)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text('¡Pedido entregado!', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Gracias por elegir La Italiana',
              style: TextStyle(color: Colors.white38, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.25))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.attach_money, color: Colors.green, size: 22),
              Text('\$${widget.pedido.total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.w900)),
              const Text(' cobrado', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onCerrar,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Volver al inicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )),
        ]),
      ),
    );
  }
}
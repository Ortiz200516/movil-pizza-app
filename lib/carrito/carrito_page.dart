import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cliente/selector_direccion_page.dart';
import 'carrito_provider.dart';
import '../pedidos/pedidos_service.dart';
import '../services/fidelidad_service.dart';
import '../cliente/fidelidad_page.dart';

// ── Constantes de color ───────────────────────────────────────────────────────
const _kBg       = Color(0xFF0F172A);
const _kCard     = Color(0xFF1E293B);
const _kCard2    = Color(0xFF263348);
const _kNaranja  = Color(0xFFFF6B35);
const _kNaranja2 = Color(0xFFFF6B00);

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});
  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage>
    with TickerProviderStateMixin {

  // ── Tipo de pedido: 'mesa' | 'domicilio' | 'retirar' ─────────────────────
  String _tipo         = 'mesa';
  // ── Método de pago ────────────────────────────────────────────────────────
  String _metodoPago   = 'efectivo';
  // ── Campos domicilio ──────────────────────────────────────────────────────
  final _dirCtrl       = TextEditingController();
  final _refCtrl       = TextEditingController();
  double? _dirLat;       // coordenadas del pin en el mapa
  double? _dirLng;
  String? _dirNombre;    // "Casa", "Oficina", etc.
  // ── Cupon ─────────────────────────────────────────────────────────────────
  final _cuponCtrl     = TextEditingController();
  double _descuento    = 0.0;
  String? _cuponOk;
  String? _cuponErr;
  // ── Mesa ──────────────────────────────────────────────────────────────────
  int?   _mesaSel;
  // ── Efectivo domicilio ────────────────────────────────────────────────────
  final _pagoCtrl      = TextEditingController();
  // ── Banco seleccionado para transferencia ─────────────────────────────────
  Map<String, dynamic>? _bancoSel;
  // ── Estado envío ─────────────────────────────────────────────────────────
  bool  _enviando      = false;
  bool  _exito         = false;
  String? _codVerif;  // solo se muestra para domicilio
  // ── Fidelidad ──────────────────────────────────────────────────────────────
  int    _puntosDisponibles = 0;
  int    _puntosCanjeados   = 0;
  double _descuentoPuntos   = 0.0;
  // ── Comprobante transferencia ──────────────────────────────────────────────
  bool   _comprobanteEnviado = false;
  String? _pedidoIdPendiente;

  // ── Animación éxito ───────────────────────────────────────────────────────
  late AnimationController _exitoCtrl;
  late Animation<double>   _exitoScale;
  late Animation<double>   _exitoOpacity;

  @override
  void initState() {
    super.initState();
    // Cargar puntos disponibles
    FidelidadService().getPuntos().then((p) {
      if (mounted) setState(() => _puntosDisponibles = p);
    });
    _exitoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _exitoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _exitoCtrl, curve: Curves.elasticOut));
    _exitoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _exitoCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _dirCtrl.dispose(); _refCtrl.dispose();
    _cuponCtrl.dispose(); _pagoCtrl.dispose();
    _exitoCtrl.dispose();
    super.dispose();
  }

  // ── Aplicar cupón ─────────────────────────────────────────────────────────
  Future<void> _aplicarCupon() async {
    final cod = _cuponCtrl.text.trim().toUpperCase();
    if (cod.isEmpty) return;
    setState(() => _cuponErr = null);
    try {
      final snap = await FirebaseFirestore.instance.collection('cupones')
          .where('codigo', isEqualTo: cod)
          .where('activo', isEqualTo: true).get();
      if (snap.docs.isEmpty) {
        setState(() => _cuponErr = 'Cupón inválido o expirado'); return;
      }
      final d     = snap.docs.first.data();
      final carrito = Provider.of<CarritoProvider>(context, listen: false);
      final tipo  = d['tipo'] as String? ?? 'porcentaje';
      final valor = (d['valor'] ?? 0.0) as num;
      final desc  = tipo == 'porcentaje'
          ? carrito.total * (valor / 100) : valor.toDouble();
      setState(() { _descuento = desc; _cuponOk = cod; _cuponErr = null; });
      HapticFeedback.lightImpact();
    } catch (_) {
      setState(() => _cuponErr = 'Error al verificar el cupón');
    }
  }

  // ── Confirmar pedido ──────────────────────────────────────────────────────
  Future<void> _confirmar(CarritoProvider carrito) async {
    // Validaciones por tipo
    if (_tipo == 'mesa' && _mesaSel == null) {
      _snack('Selecciona una mesa', Colors.orange); return;
    }
    if (_tipo == 'domicilio' && _dirCtrl.text.trim().isEmpty) {
      _snack('Ingresa la dirección de entrega', Colors.orange); return;
    }
    if (_metodoPago == 'transferencia' && _bancoSel == null) {
      _snack('Selecciona el banco al que transferirás', Colors.orange); return;
    }

    setState(() => _enviando = true);
    try {
      final total = (carrito.total - _descuento - _descuentoPuntos).clamp(0.0, double.infinity);

      // Datos extra de pago (aplica a todos los tipos)
      Map<String, dynamic> datosPago = {'metodoPago': _metodoPago};
      if (_metodoPago == 'efectivo' && _tipo == 'domicilio') {
        final pago = double.tryParse(_pagoCtrl.text) ?? 0;
        datosPago = {
          'metodoPago': 'efectivo',
          'montoPago':  pago,
          'cambio':     (pago - total).clamp(0.0, double.infinity),
        };
      } else if (_metodoPago == 'transferencia' && _bancoSel != null) {
        datosPago = {
          'metodoPago':   'transferencia',
          'banco':        _bancoSel!['nombre'],
          'titular':      _bancoSel!['titular'],
          'numeroCuenta': _bancoSel!['numeroCuenta'],
          'tipoCuenta':   _bancoSel!['tipoCuenta'],
        };
      }

      final pedido = await PedidoService().crearPedido(
        items:            carrito.obtenerItemsParaFirestore(),
        subtotal:         carrito.subtotal,
        total:            total,
        tipoPedido:       _tipo,
        numeroMesa:       _tipo == 'mesa' ? _mesaSel : null,
        direccionEntrega: _tipo == 'domicilio'
            ? {
                'direccion':  _dirCtrl.text.trim(),
                'referencia': _refCtrl.text.trim(),
                if (_dirLat != null) 'lat': _dirLat,
                if (_dirLng != null) 'lng': _dirLng,
                if (_dirNombre != null) 'nombre': _dirNombre,
                ...datosPago,
              } : datosPago,
        metodoPago: _metodoPago,
      );

      final codigo = _tipo == 'domicilio'
          ? (pedido?.codigoVerificacion ?? '------')
          : null;

      setState(() { _exito = true; _codVerif = codigo; });
      carrito.limpiarCarrito();
      // Otorgar puntos si hubo canje previo, descontarlo
      if (_puntosCanjeados > 0) await FidelidadService().canjearPuntos(_puntosCanjeados);
      if (pedido != null) {
        _pedidoIdPendiente = pedido.id;
        await FidelidadService().sumarPuntos(pedido.id, total);
      }
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      _exitoCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', Colors.red);
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  // ── Calcular cambio ───────────────────────────────────────────────────────
  double get _cambio {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    final total   = (carrito.total - _descuento - _descuentoPuntos).clamp(0.0, double.infinity);
    final pago    = double.tryParse(_pagoCtrl.text) ?? 0;
    return (pago - total).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context);

    if (_exito) return _PantallaExito(
      tipo: _tipo,
      mesa: _mesaSel,
      codigo: _codVerif,
      scaleAnim: _exitoScale,
      opacityAnim: _exitoOpacity,
      metodoPago: _metodoPago,
      bancoSel: _bancoSel,
      pedidoId: _pedidoIdPendiente,
      total: (Provider.of<CarritoProvider>(context, listen: false).total
          - _descuento - _descuentoPuntos).clamp(0.0, double.infinity),
      onNuevo: () => setState(() {
        _exito = false; _tipo = 'mesa'; _mesaSel = null;
              _dirLat = null; _dirLng = null; _dirNombre = null;
        _descuento = 0; _cuponOk = null; _codVerif = null;
        _bancoSel = null; _metodoPago = 'efectivo';
        _puntosCanjeados = 0; _descuentoPuntos = 0;
        _comprobanteEnviado = false; _pedidoIdPendiente = null;
        _exitoCtrl.reset();
      }),
    );

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg, elevation: 0,
        title: Row(children: [
          const Text('🛒', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Mi Carrito', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const Spacer(),
          if (carrito.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context,
                    builder: (_) => _DialogVaciar());
                if (ok == true) carrito.limpiarCarrito();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
              label: const Text('Vaciar',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ]),
      ),
      body: carrito.estaVacio ? _CarritoVacio() : Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.all(14),
          children: [

            // ── Items ─────────────────────────────────────────────────────
            ...carrito.items.asMap().entries.map((e) =>
                _ItemCard(item: e.value, index: e.key)),
            const SizedBox(height: 14),

            // ── Tipo de pedido ─────────────────────────────────────────────
            _Sec('¿Cómo quieres tu pedido?', Column(children: [
              Row(children: [
                Expanded(child: _TipoBtn('🍽️', 'En mesa', _tipo == 'mesa',
                    () => setState(() { _tipo = 'mesa'; _mesaSel = null;
                                       _metodoPago = 'efectivo'; }))),
                const SizedBox(width: 8),
                Expanded(child: _TipoBtn('🛵', 'Domicilio', _tipo == 'domicilio',
                    () => setState(() { _tipo = 'domicilio';
                                       _metodoPago = 'efectivo'; }))),
                const SizedBox(width: 8),
                Expanded(child: _TipoBtn('🏃', 'Retirar', _tipo == 'retirar',
                    () => setState(() { _tipo = 'retirar';
                                       _metodoPago = 'efectivo'; }))),
              ]),
              const SizedBox(height: 14),

              // Sub-contenido según tipo
              if (_tipo == 'mesa')
                _SelectorMesas(
                  mesaSel: _mesaSel,
                  onSel: (n) => setState(() => _mesaSel = n),
                ),

              if (_tipo == 'domicilio') ...[
                // ── Botón abrir mapa ─────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SelectorDireccionPage(
                          direccionInicial: _dirCtrl.text.isNotEmpty ? {
                            'direccion':  _dirCtrl.text,
                            'referencia': _refCtrl.text,
                            'lat': _dirLat,
                            'lng': _dirLng,
                          } : null,
                        ),
                        transitionsBuilder: (_, anim, __, child) =>
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                        transitionDuration: const Duration(milliseconds: 320),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _dirCtrl.text  = result['direccion'] ?? '';
                        _refCtrl.text  = result['referencia'] ?? '';
                        _dirLat        = result['lat'] as double?;
                        _dirLng        = result['lng'] as double?;
                        _dirNombre     = result['nombre'] as String?;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF263348),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _dirCtrl.text.isNotEmpty
                            ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.map_outlined,
                            color: Color(0xFFFF6B35), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _dirCtrl.text.isEmpty
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Seleccionar en el mapa',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            Text('Toca para mover el pin a tu ubicación',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11)),
                          ])
                          : Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            if (_dirNombre != null && _dirNombre!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_dirNombre!,
                                    style: const TextStyle(
                                        color: Color(0xFFFF6B35),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            Text(_dirCtrl.text,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (_refCtrl.text.isNotEmpty)
                              Text(_refCtrl.text,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ]),
                      ),
                      Icon(
                        _dirCtrl.text.isNotEmpty
                            ? Icons.check_circle_outline_rounded
                            : Icons.chevron_right_rounded,
                        color: _dirCtrl.text.isNotEmpty
                            ? const Color(0xFF4ADE80)
                            : Colors.white24,
                        size: 20,
                      ),
                    ]),
                  ),
                ),
                // Coordenadas guardadas (debug badge pequeño)
                if (_dirLat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(children: [
                      const Icon(Icons.gps_fixed,
                          size: 11, color: Color(0xFF4ADE80)),
                      const SizedBox(width: 4),
                      Text(
                        'Ubicación guardada · '
                        '${_dirLat!.toStringAsFixed(4)}, '
                        '${_dirLng!.toStringAsFixed(4)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10),
                      ),
                    ]),
                  ),
              ],

              if (_tipo == 'retirar')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                  ),
                  child: const Row(children: [
                    Text('🏃', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Retiras en el local. Te avisaremos cuando esté listo.',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                    )),
                  ]),
                ),
            ])),
            const SizedBox(height: 12),

            // ── Método de pago ─────────────────────────────────────────────
            _Sec('💳 Método de pago',
              _tipo == 'domicilio'
                  ? _MetodosPagoDomicilio(
                      sel: _metodoPago,
                      onSel: (m) => setState(() {
                        _metodoPago = m;
                        _bancoSel = null;
                      }),
                    )
                  : _MetodosPagoCompleto(
                      sel: _metodoPago,
                      onSel: (m) => setState(() => _metodoPago = m),
                    ),
            ),
            const SizedBox(height: 12),

            // ── Contacto del local (todos los tipos y métodos) ─────────────
            _Sec('📞 Contacto del local', _InfoContactoLocal(
              tipo: _tipo,
              metodoPago: _metodoPago,
            )),
            const SizedBox(height: 12),

            // ── Panel efectivo con cambio (domicilio) ──────────────────────
            if (_tipo == 'domicilio' && _metodoPago == 'efectivo')
              _Sec('💵 ¿Con cuánto pagas?', _PanelEfectivo(
                ctrl:    _pagoCtrl,
                total:   (carrito.total - _descuento).clamp(0.0, double.infinity),
                onChanged: (_) => setState(() {}),
              )),
            if (_tipo == 'domicilio' && _metodoPago == 'efectivo')
              const SizedBox(height: 12),

            // ── Selector de banco (todos los tipos si es transferencia) ────
            if (_metodoPago == 'transferencia')
              _Sec('🏦 Selecciona el banco', _SelectorBancos(
                bancoSel: _bancoSel,
                onSel: (b) => setState(() => _bancoSel = b),
              )),
            if (_metodoPago == 'transferencia' && _bancoSel != null)
              const SizedBox(height: 12),

            // ── Puntos de fidelidad ────────────────────────────────────────
            if (_puntosDisponibles > 0)
              _Sec('🏆 Usar puntos de fidelidad',
                CanjeePuntosWidget(
                  puntosDisponibles: _puntosDisponibles,
                  totalCarrito: carrito.total - _descuento,
                  onDescuentoChanged: (d) => setState(() => _descuentoPuntos = d),
                  onPuntosCanjeadosChanged: (p) => setState(() => _puntosCanjeados = p),
                ),
              ),
            if (_puntosDisponibles > 0) const SizedBox(height: 12),

            // ── Cupón ──────────────────────────────────────────────────────
            _Sec('🎟️ ¿Tienes un cupón?', _PanelCupon(
              ctrl:      _cuponCtrl,
              cuponOk:   _cuponOk,
              cuponErr:  _cuponErr,
              descuento: _descuento,
              onAplicar: _aplicarCupon,
              onQuitar:  () => setState(() {
                _descuento = 0; _cuponOk = null;
                _cuponErr = null; _cuponCtrl.clear();
              }),
            )),
            const SizedBox(height: 12),

            // ── Resumen ────────────────────────────────────────────────────
            _Sec('📋 Resumen', Column(children: [
              _Fila('Subtotal', '\$${carrito.subtotal.toStringAsFixed(2)}'),
              _Fila('IVA (15%)', '\$${carrito.impuesto.toStringAsFixed(2)}'),
              if (_descuento > 0)
                _Fila('🎟️ Descuento',
                    '-\$${_descuento.toStringAsFixed(2)}',
                    color: Colors.green),
              const Divider(color: Colors.white12, height: 20),
              _Fila('TOTAL',
                '\$${(carrito.total - _descuento).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                bold: true, color: _kNaranja),
              // Cambio si aplica
              if (_tipo == 'domicilio' && _metodoPago == 'efectivo'
                  && _pagoCtrl.text.isNotEmpty
                  && double.tryParse(_pagoCtrl.text) != null) ...[
                const Divider(color: Colors.white12, height: 20),
                _Fila('Pagas con', '\$${double.parse(_pagoCtrl.text).toStringAsFixed(2)}'),
                _Fila('Cambio', '\$${_cambio.toStringAsFixed(2)}',
                    color: _cambio > 0 ? Colors.green : Colors.white38),
              ],
            ])),
            const SizedBox(height: 90),
          ],
        )),

        // ── Botón confirmar ────────────────────────────────────────────────
        _BtnConfirmar(
          enviando: _enviando,
          total: (carrito.total - _descuento - _descuentoPuntos).clamp(0.0, double.infinity),
          onTap: () => _confirmar(carrito),
        ),
      ]),
    );
  }
}

// ── Selector de mesas con capacidad + estado ──────────────────────────────────
class _SelectorMesas extends StatelessWidget {
  final int? mesaSel;
  final ValueChanged<int?> onSel;
  const _SelectorMesas({this.mesaSel, required this.onSel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesas')
          .where('activa', isEqualTo: true)
          .orderBy('numero')
          .snapshots(),
      builder: (ctx, mesasSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pedidos')
              .where('tipoPedido', isEqualTo: 'mesa')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
              .snapshots(),
          builder: (ctx2, pedidosSnap) {
            if (mesasSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: _kNaranja, strokeWidth: 2),
              ));
            }

            final mesas = mesasSnap.data?.docs ?? [];

            // Mesas que tienen pedidos activos
            final mesasOcupadas = <int>{};
            for (final doc in pedidosSnap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              final n = d['numeroMesa'];
              if (n != null) mesasOcupadas.add(n as int);
            }

            if (mesas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2))),
                child: const Row(children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('No hay mesas disponibles',
                      style: TextStyle(color: Colors.orange, fontSize: 13)),
                ]),
              );
            }

            return Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Leyenda
              Row(children: [
                _Leyenda(Colors.green,   'Libre'),
                const SizedBox(width: 14),
                _Leyenda(Colors.red,     'Ocupada'),
                const SizedBox(width: 14),
                _Leyenda(_kNaranja,      'Seleccionada'),
              ]),
              const SizedBox(height: 12),

              // Grid de mesas
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.8),
                itemCount: mesas.length,
                itemBuilder: (_, i) {
                  final d        = mesas[i].data() as Map<String, dynamic>;
                  final numero   = d['numero'] as int;
                  final cap      = d['capacidad'] as int? ?? 4;
                  final ocupada  = mesasOcupadas.contains(numero);
                  final sel      = mesaSel == numero;

                  return _MesaBtn(
                    numero: numero, capacidad: cap,
                    ocupada: ocupada, seleccionada: sel,
                    onTap: ocupada ? null : () => onSel(numero),
                  );
                },
              ),

              if (mesaSel != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kNaranja.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _kNaranja.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Text('🍽️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('Mesa $mesaSel seleccionada ✅',
                        style: const TextStyle(color: _kNaranja,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
              ],
            ]);
          },
        );
      },
    );
  }
}

class _MesaBtn extends StatelessWidget {
  final int numero, capacidad;
  final bool ocupada, seleccionada;
  final VoidCallback? onTap;
  const _MesaBtn({required this.numero, required this.capacidad,
      required this.ocupada, required this.seleccionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = seleccionada
        ? _kNaranja
        : ocupada
            ? Colors.red
            : Colors.green;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: color.withValues(
              alpha: seleccionada ? 0.22 : ocupada ? 0.1 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(
                  alpha: seleccionada ? 1.0 : ocupada ? 0.6 : 0.4),
              width: seleccionada ? 2 : 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // Emoji estado
          Text(ocupada ? '🔴' : seleccionada ? '✅' : '🟢',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          // Número de mesa
          Text('$numero', style: TextStyle(
              color: color, fontSize: 17,
              fontWeight: FontWeight.w900)),
          // Capacidad
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person, size: 10, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text('$capacidad', style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
          // Estado
          Text(
            ocupada ? 'Ocupada' : seleccionada ? 'Elegida' : 'Libre',
            style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color; final String label;
  const _Leyenda(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7), shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(
        color: color.withValues(alpha: 0.8), fontSize: 10)),
  ]);
}

// ── Métodos de pago ───────────────────────────────────────────────────────────
/// Para mesa y retirar → 3 opciones
class _MetodosPagoCompleto extends StatelessWidget {
  final String sel;
  final ValueChanged<String> onSel;
  const _MetodosPagoCompleto({required this.sel, required this.onSel});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _MetBtn('💵', 'Efectivo', sel == 'efectivo',
        () => onSel('efectivo'))),
    const SizedBox(width: 8),
    Expanded(child: _MetBtn('💳', 'Tarjeta', sel == 'tarjeta',
        () => onSel('tarjeta'))),
    const SizedBox(width: 8),
    Expanded(child: _MetBtn('📱', 'Transfer.', sel == 'transferencia',
        () => onSel('transferencia'))),
  ]);
}

/// Para domicilio → solo efectivo y transferencia
class _MetodosPagoDomicilio extends StatelessWidget {
  final String sel;
  final ValueChanged<String> onSel;
  const _MetodosPagoDomicilio({required this.sel, required this.onSel});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _MetBtn('💵', 'Efectivo', sel == 'efectivo',
        () => onSel('efectivo'))),
    const SizedBox(width: 10),
    Expanded(child: _MetBtn('📱', 'Transferencia', sel == 'transferencia',
        () => onSel('transferencia'))),
  ]);
}

class _MetBtn extends StatelessWidget {
  final String icono, label; final bool sel; final VoidCallback onTap;
  const _MetBtn(this.icono, this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? _kNaranja.withValues(alpha: 0.12) : _kCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: sel ? _kNaranja.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: sel ? 1.5 : 1)),
      child: Column(children: [
        Text(icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: sel ? _kNaranja : Colors.white38,
            fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ])));
}

// ── Panel efectivo con cambio ─────────────────────────────────────────────────
class _PanelEfectivo extends StatelessWidget {
  final TextEditingController ctrl;
  final double total;
  final ValueChanged<String> onChanged;
  const _PanelEfectivo({required this.ctrl, required this.total,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pago   = double.tryParse(ctrl.text) ?? 0;
    final cambio = (pago - total).clamp(0.0, double.infinity);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Total a pagar: \$${total.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16,
            fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '0.00',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixText: '\$ ',
          prefixStyle: const TextStyle(color: _kNaranja,
              fontWeight: FontWeight.bold, fontSize: 16),
          filled: true, fillColor: _kCard2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kNaranja, width: 1.5)),
        ),
      ),
      if (pago > 0 && pago >= total) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Text('💵', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Cambio: \$${cambio.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
      ],
      if (pago > 0 && pago < total) ...[
        const SizedBox(height: 8),
        Text('⚠️ El monto no cubre el total',
            style: TextStyle(color: Colors.orange.withValues(alpha: 0.8),
                fontSize: 12)),
      ],
    ]);
  }
}

// ── Info contacto del local ───────────────────────────────────────────────────
/// Muestra teléfono/WhatsApp del local para los 3 métodos y 3 tipos de pedido.
class _InfoContactoLocal extends StatelessWidget {
  final String tipo;
  final String metodoPago;
  const _InfoContactoLocal({required this.tipo, required this.metodoPago});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config_local')
          .doc('info')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 48,
            child: Center(
                child: CircularProgressIndicator(
                    color: _kNaranja, strokeWidth: 2)),
          );
        }
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final tel    = (d['telefono'] ?? '').toString().trim();
        final nombre = (d['nombre']   ?? 'La Italiana').toString();
        final hora   = (d['horario']  ?? '').toString().trim();

        final String tipoLabel = tipo == 'mesa'
            ? '🍽️ Mesa'
            : tipo == 'domicilio'
                ? '🛵 Domicilio'
                : '🏃 Retirar en local';

        final String metLabel = metodoPago == 'efectivo'
            ? '💵 Efectivo'
            : metodoPago == 'tarjeta'
                ? '💳 Tarjeta'
                : '📱 Transferencia';

        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Tipo + método seleccionado
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kNaranja.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _kNaranja.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Text(tipoLabel,
                  style: const TextStyle(
                      color: _kNaranja,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(width: 8),
              Container(width: 1, height: 14,
                  color: Colors.white24),
              const SizedBox(width: 8),
              Text(metLabel,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 10),

          // Datos del local
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(children: [
              // Nombre + horario
              Row(children: [
                const Text('🏪',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(nombre, style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
                  if (hora.isNotEmpty)
                    Text(hora, style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                ])),
              ]),

              if (tel.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 16),
                // WhatsApp / teléfono
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF25D366)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                        child: Text('📱',
                            style: TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('WhatsApp / Teléfono',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10)),
                    Text(tel, style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                  ])),
                  // Botón copiar
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: tel));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            '📋 Número copiado'),
                        backgroundColor: Color(0xFF25D366),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ));
                    },
                    icon: const Icon(Icons.copy,
                        size: 16, color: Colors.white38),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ],

              // Instrucción según método de pago
              const Divider(color: Colors.white10, height: 16),
              _InstruccionPago(
                  tipo: tipo, metodoPago: metodoPago),
            ]),
          ),
        ]);
      },
    );
  }
}

class _InstruccionPago extends StatelessWidget {
  final String tipo, metodoPago;
  const _InstruccionPago(
      {required this.tipo, required this.metodoPago});

  @override
  Widget build(BuildContext context) {
    String texto;
    String emoji;
    Color color;

    if (metodoPago == 'efectivo') {
      emoji = '💵';
      color = Colors.green;
      if (tipo == 'domicilio') {
        texto =
            'Ten el dinero listo al recibir tu pedido. El repartidor llevará el cambio.';
      } else if (tipo == 'mesa') {
        texto =
            'Paga en efectivo al finalizar en tu mesa. El mesero te traerá la cuenta.';
      } else {
        texto =
            'Paga en efectivo al retirar tu pedido en el local.';
      }
    } else if (metodoPago == 'tarjeta') {
      emoji = '💳';
      color = Colors.blue;
      if (tipo == 'mesa') {
        texto =
            'Paga con tarjeta al finalizar en tu mesa. El mesero traerá el datafono.';
      } else {
        texto =
            'Paga con tarjeta al retirar tu pedido en caja.';
      }
    } else {
      // transferencia
      emoji = '📱';
      color = _kNaranja;
      if (tipo == 'domicilio') {
        texto =
            'Realiza la transferencia y envía el comprobante por WhatsApp antes de confirmar tu pedido.';
      } else if (tipo == 'mesa') {
        texto =
            'Realiza la transferencia y muestra el comprobante al mesero.';
      } else {
        texto =
            'Realiza la transferencia y muestra el comprobante al retirar tu pedido.';
      }
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(texto,
          style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 11,
              height: 1.4))),
    ]);
  }
}

// ── Selector de bancos ────────────────────────────────────────────────────────
class _SelectorBancos extends StatelessWidget {
  final Map<String, dynamic>? bancoSel;
  final ValueChanged<Map<String, dynamic>?> onSel;
  const _SelectorBancos({this.bancoSel, required this.onSel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config_bancos')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _kNaranja, strokeWidth: 2));
        }
        final bancos = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final oa = ((a.data() as Map<String,dynamic>)['orden'] as int?) ?? 99;
            final ob = ((b.data() as Map<String,dynamic>)['orden'] as int?) ?? 99;
            return oa.compareTo(ob);
          });
        if (bancos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Text('⚠️', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'No hay bancos configurados. Consulta con el local.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              )),
            ]),
          );
        }

        return Column(children: [
          ...bancos.map((doc) {
            final d   = doc.data() as Map<String, dynamic>;
            final sel = bancoSel?['numeroCuenta'] == d['numeroCuenta'];

            return GestureDetector(
              onTap: () => onSel(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel
                      ? _kNaranja.withValues(alpha: 0.1)
                      : _kCard2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel
                          ? _kNaranja.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.06),
                      width: sel ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: sel
                            ? _kNaranja.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle),
                    child: const Center(child:
                        Text('🏦', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(d['nombre'] ?? '', style: TextStyle(
                        color: sel ? _kNaranja : Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${d['tipoCuenta'] ?? 'Corriente'} · ${d['numeroCuenta'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    Text('Titular: ${d['titular'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ])),
                  if (sel)
                    const Icon(Icons.check_circle, color: _kNaranja, size: 20),
                ]),
              ),
            );
          }),

          // Detalle del banco seleccionado
          if (bancoSel != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ℹ️ Datos para tu transferencia:',
                    style: TextStyle(color: Colors.blue, fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _DatoBanco('Banco', bancoSel!['nombre']),
                _DatoBanco('Titular', bancoSel!['titular']),
                _DatoBanco('Cuenta', bancoSel!['numeroCuenta']),
                _DatoBanco('Tipo', bancoSel!['tipoCuenta']),
                if ((bancoSel!['identificacion'] ?? '').isNotEmpty)
                  _DatoBanco('ID/RUC', bancoSel!['identificacion']),
              ]),
            ),
          ],
        ]);
      },
    );
  }
}

class _DatoBanco extends StatelessWidget {
  final String label, valor;
  const _DatoBanco(this.label, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(children: [
      SizedBox(width: 60, child: Text('$label:',
          style: const TextStyle(color: Colors.white38, fontSize: 11))),
      Text(valor ?? '', style: const TextStyle(
          color: Colors.white60, fontSize: 11,
          fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── Panel cupón ───────────────────────────────────────────────────────────────
class _PanelCupon extends StatelessWidget {
  final TextEditingController ctrl;
  final String? cuponOk, cuponErr;
  final double descuento;
  final VoidCallback onAplicar, onQuitar;
  const _PanelCupon({required this.ctrl, this.cuponOk, this.cuponErr,
      required this.descuento, required this.onAplicar,
      required this.onQuitar});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cuponOk != null
          ? Colors.green.withValues(alpha: 0.05)
          : _kCard2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: cuponOk != null
            ? Colors.green.withValues(alpha: 0.3)
            : cuponErr != null
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
        width: cuponOk != null ? 1.5 : 1,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Header sección
      Row(children: [
        Icon(cuponOk != null ? Icons.local_offer : Icons.local_offer_outlined,
            size: 15, color: cuponOk != null ? Colors.green : _kNaranja),
        const SizedBox(width: 8),
        Text(cuponOk != null ? 'Cupón aplicado' : 'Tengo un cupón',
            style: TextStyle(
                color: cuponOk != null ? Colors.green : Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)),
        if (cuponOk != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onQuitar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Text('Quitar', style: TextStyle(
                  color: Colors.red, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 10),

      // Cupón aplicado — vista compacta
      if (cuponOk != null)
        Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🎟️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(cuponOk!, style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w900,
                      fontSize: 13, letterSpacing: 1)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Descuento aplicado correctamente',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ])),
          Text('-\$${descuento.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green,
                  fontWeight: FontWeight.w900, fontSize: 18)),
        ])
      else ...[
        // Campo de código
        Row(children: [
          Expanded(child: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, letterSpacing: 3, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'CÓDIGO',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 2, fontSize: 13),
              prefixIcon: const Icon(Icons.confirmation_number_outlined,
                  color: Colors.white38, size: 18),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _kNaranja.withValues(alpha: 0.6), width: 1.5)),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAplicar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: _kNaranja,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: _kNaranja.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('Aplicar', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 13)),
            ),
          ),
        ]),

        // Error
        if (cuponErr != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 14),
            const SizedBox(width: 6),
            Text(cuponErr!, style: const TextStyle(
                color: Colors.red, fontSize: 12)),
          ]),
        ],
      ],
    ]),
  );
}

// ── Pantalla de éxito ─────────────────────────────────────────────────────────
class _PantallaExito extends StatefulWidget {
  final String tipo;
  final int?   mesa;
  final String? codigo;
  final String  metodoPago;
  final Map<String, dynamic>? bancoSel;
  final String? pedidoId;
  final double  total;
  final Animation<double> scaleAnim, opacityAnim;
  final VoidCallback onNuevo;

  const _PantallaExito({
    required this.tipo, this.mesa, this.codigo,
    required this.metodoPago, this.bancoSel, this.pedidoId,
    required this.total,
    required this.scaleAnim, required this.opacityAnim,
    required this.onNuevo,
  });

  @override
  State<_PantallaExito> createState() => _PantallaExitoState();
}

class _PantallaExitoState extends State<_PantallaExito> {
  bool _comprobanteEnviado = false;
  bool _enviandoWA         = false;

  String get _subtitulo {
    if (widget.tipo == 'mesa' && widget.mesa != null)
      return 'Mesa ${widget.mesa} · Preparando tu pedido 🍕';
    if (widget.tipo == 'retirar') return 'Te avisaremos cuando esté listo 🏃';
    return 'Tu pedido está en camino 🛵';
  }

  // ── Abrir WhatsApp con mensaje pre-armado ─────────────────────────────────
  Future<void> _abrirWhatsApp(String telefono) async {
    setState(() => _enviandoWA = true);
    try {
      final banco    = widget.bancoSel?['nombre']        ?? '';
      final cuenta   = widget.bancoSel?['numeroCuenta']  ?? '';
      final titular  = widget.bancoSel?['titular']       ?? '';
      final pedidoId = widget.pedidoId ?? '—';
      final total    = widget.total.toStringAsFixed(2);
      final tipo     = widget.tipo == 'mesa'
          ? 'Mesa ${widget.mesa}'
          : widget.tipo == 'retirar' ? 'Retiro en local' : 'Domicilio';

      final msg = Uri.encodeComponent(
        'La Italiana - Comprobante de pago\n\n'
        'Pedido: #${pedidoId.substring(0, pedidoId.length.clamp(0, 8))}\n'
        'Total: \$$total\n'
        'Banco: $banco\n'
        'Cuenta: $cuenta\n'
        'Titular: $titular\n'
        'Tipo: $tipo\n\n'
        'Adjunto el comprobante de transferencia. Por favor confirmar recepcion. Gracias!',
      );

      // Limpiar número: quitar espacios, guiones, +
      final numLimpio = telefono
          .replaceAll(RegExp(r'[^0-9]'), '');
      final numConPais = numLimpio.startsWith('593')
          ? numLimpio
          : numLimpio.startsWith('0')
              ? '593${numLimpio.substring(1)}'
              : '593$numLimpio';

      final url = Uri.parse('https://wa.me/$numConPais?text=$msg');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        setState(() { _comprobanteEnviado = true; });
        // Marcar en Firestore que el comprobante fue enviado
        if (widget.pedidoId != null) {
          await FirebaseFirestore.instance
              .collection('pedidos')
              .doc(widget.pedidoId)
              .update({'comprobanteEnviado': true,
                       'fechaComprobante': FieldValue.serverTimestamp()});
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo abrir WhatsApp'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _enviandoWA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esTransferencia = widget.metodoPago == 'transferencia';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(28),
        child: AnimatedBuilder(
          animation: widget.scaleAnim,
          builder: (_, child) => Transform.scale(
              scale: widget.scaleAnim.value,
              child: Opacity(opacity: widget.opacityAnim.value,
                  child: child)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const SizedBox(height: 20),
            // ── Icono éxito ────────────────────────────────────────────
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(child:
                  Text('✅', style: TextStyle(fontSize: 52))),
            ),
            const SizedBox(height: 20),
            const Text('¡Pedido confirmado!', style: TextStyle(
                color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_subtitulo,
                style: const TextStyle(color: Colors.white54,
                    fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // ── Código verificación (domicilio) ────────────────────────
            if (widget.codigo != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kNaranja.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kNaranja.withValues(alpha: 0.25)),
                ),
                child: Column(children: [
                  const Text('Código de verificación',
                      style: TextStyle(color: Colors.white38,
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(widget.codigo!, style: const TextStyle(
                        color: _kNaranja, fontSize: 32,
                        fontWeight: FontWeight.w900, letterSpacing: 8)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.codigo!));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código copiado ✅'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1)));
                      },
                    ),
                  ]),
                  Text('Muéstralo al recibir tu pedido',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Bloque de transferencia + WhatsApp ─────────────────────
            if (esTransferencia && widget.bancoSel != null) ...[
              _BloqueTransferencia(
                bancoSel: widget.bancoSel!,
                total: widget.total,
                enviado: _comprobanteEnviado,
                enviando: _enviandoWA,
                onEnviar: _abrirWhatsApp,
              ),
              const SizedBox(height: 16),
            ],

            // ── Botón nuevo pedido ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNuevo,
                icon: const Text('🍕', style: TextStyle(fontSize: 16)),
                label: const Text('Hacer otro pedido',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNaranja,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ))),
    );
  }
}

// ── Bloque de transferencia con datos bancarios y botón WhatsApp ──────────────
class _BloqueTransferencia extends StatelessWidget {
  final Map<String, dynamic> bancoSel;
  final double total;
  final bool   enviado, enviando;
  final Future<void> Function(String telefono) onEnviar;
  const _BloqueTransferencia({
    required this.bancoSel, required this.total,
    required this.enviado, required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config_local').doc('info').snapshots(),
      builder: (_, snap) {
        final localData = snap.data?.data() as Map<String, dynamic>?;
        final telefonoLocal = localData?['telefono'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F4C35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              const Text('💳', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Datos para transferir',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text('Pendiente', style: TextStyle(
                    color: Colors.orange, fontSize: 10,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),

            // Monto a transferir (resaltado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Text('Monto a transferir',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
                const SizedBox(height: 4),
                Text('\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 28)),
              ]),
            ),
            const SizedBox(height: 14),

            // Datos bancarios
            _DatoTransf('🏦 Banco',    bancoSel['nombre']        ?? ''),
            _DatoTransf('👤 Titular',  bancoSel['titular']       ?? ''),
            _DatoTransf('💳 Cuenta',   bancoSel['numeroCuenta']  ?? '',
                copiable: true),
            _DatoTransf('📄 Tipo',     bancoSel['tipoCuenta']    ?? ''),
            if ((bancoSel['identificacion'] as String? ?? '').isNotEmpty)
              _DatoTransf('🪪 Cédula', bancoSel['identificacion'] ?? '',
                  copiable: true),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 14),

            // Instrucciones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('📋 Pasos para confirmar tu pago:',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...[
                  '1. Realiza la transferencia por \$${total.toStringAsFixed(2)}',
                  '2. Toma captura del comprobante',
                  '3. Toca el botón verde de abajo',
                  '4. Se abrirá WhatsApp con el mensaje listo',
                  '5. Adjunta la foto del comprobante y envía',
                ].map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(t, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
                )),
              ]),
            ),
            const SizedBox(height: 14),

            // Botón WhatsApp
            if (telefonoLocal.isNotEmpty)
              GestureDetector(
                onTap: enviando ? null : () => onEnviar(telefonoLocal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: enviado
                        ? Colors.green.withValues(alpha: 0.15)
                        : const Color(0xFF25D366).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: enviado ? Border.all(
                        color: Colors.green.withValues(alpha: 0.4)) : null,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    if (enviando)
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                    else ...[
                      Text(enviado ? '✅' : '💬',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        enviado
                            ? 'Comprobante enviado'
                            : 'Enviar comprobante por WhatsApp',
                        style: TextStyle(
                          color: enviado ? Colors.green : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '⚠️ Contacta al local para enviar el comprobante. '
                  'El admin aún no ha configurado el número de WhatsApp.',
                  style: TextStyle(color: Colors.orange,
                      fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ── Dato de transferencia con opción de copiar ────────────────────────────────
class _DatoTransf extends StatelessWidget {
  final String label, valor;
  final bool copiable;
  const _DatoTransf(this.label, this.valor, {this.copiable = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label: ',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12)),
        TextSpan(text: valor,
            style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]))),
      if (copiable)
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: valor));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('📋 $label copiado'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF1E293B),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text('Copiar', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10)),
          ),
        ),
    ]),
  );
}

// ── Carrito vacío ─────────────────────────────────────────────────────────────
class _CarritoVacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🛒', style: TextStyle(fontSize: 80)),
    const SizedBox(height: 16),
    const Text('Tu carrito está vacío', style: TextStyle(
        color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text('Agrega productos desde el menú', style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
  ]));
}

class _DialogVaciar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('¿Vaciar carrito?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: const Text('Se eliminarán todos los productos.',
        style: TextStyle(color: Colors.white54)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white38))),
      ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: const Text('Vaciar')),
    ],
  );
}

// ── ItemCard ──────────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  const _ItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final c      = Provider.of<CarritoProvider>(context, listen: false);
    final nombre = item['nombre'] as String? ?? '';
    final precio = (item['precio'] ?? 0.0) as num;
    final cant   = (item['cantidad'] ?? 1) as int;
    final icono  = item['icono'] as String? ?? '🍽️';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(
                color: _kNaranja.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(icono,
                style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(nombre, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('\$${precio.toStringAsFixed(2)} c/u',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Row(children: [
          _Btn(cant == 1 ? Icons.delete_outline : Icons.remove,
              cant == 1 ? Colors.red : Colors.white38,
              () => c.disminuirCantidad(index)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$cant', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 15))),
          _Btn(Icons.add, _kNaranja, () => c.aumentarCantidad(index)),
        ]),
        const SizedBox(width: 8),
        Text('\$${(precio * cant).toStringAsFixed(2)}',
            style: const TextStyle(color: _kNaranja,
                fontWeight: FontWeight.w900, fontSize: 13)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _Btn(this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Icon(icon, color: color, size: 15)));
}

// ── Botón confirmar ───────────────────────────────────────────────────────────
class _BtnConfirmar extends StatelessWidget {
  final bool enviando;
  final double total;
  final VoidCallback onTap;
  const _BtnConfirmar({required this.enviando, required this.total,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
    decoration: BoxDecoration(
      color: _kBg,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12, offset: const Offset(0, -4))],
    ),
    child: GestureDetector(
      onTap: enviando ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 58,
        decoration: BoxDecoration(
          gradient: enviando ? null : const LinearGradient(
              colors: [_kNaranja2, _kNaranja],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: enviando ? _kNaranja.withValues(alpha: 0.4) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enviando ? [] : [BoxShadow(
              color: _kNaranja.withValues(alpha: 0.35),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            enviando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.check_circle_outline,
                    size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(
              enviando ? 'Procesando...' : 'CONFIRMAR PEDIDO',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5),
            )),
            Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Total', style: TextStyle(
                  color: Colors.white60, fontSize: 10)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),
      ),
    ),
  );
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String titulo; final Widget child;
  const _Sec(this.titulo, this.child);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      const SizedBox(height: 12), child,
    ]));
}

class _TipoBtn extends StatelessWidget {
  final String icon, label; final bool sel; final VoidCallback onTap;
  const _TipoBtn(this.icon, this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? _kNaranja.withValues(alpha: 0.15) : _kCard2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: sel ? _kNaranja.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
            width: sel ? 1.5 : 1)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: sel ? _kNaranja : Colors.white38,
            fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ])));
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl; final String label; final IconData icon;
  const _Campo(this.ctrl, this.label, this.icon);
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: _kNaranja, size: 18),
      filled: true, fillColor: _kCard2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kNaranja, width: 1.5))));
}

class _Fila extends StatelessWidget {
  final String l, v; final bool bold; final Color? color;
  const _Fila(this.l, this.v, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(
          color: bold ? Colors.white : Colors.white38,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: bold ? 15 : 13)),
      Text(v, style: TextStyle(
          color: color ?? (bold ? Colors.white : Colors.white38),
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          fontSize: bold ? 16 : 13)),
    ]));
}
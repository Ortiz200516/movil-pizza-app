import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'carrito_provider.dart';
import '../pedidos/pedidos_service.dart';

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
  String _tipoPedido    = 'mesa';
  String _metodoPago    = 'efectivo';
  final _dirCtrl        = TextEditingController();
  final _refCtrl        = TextEditingController();
  final _cuponCtrl      = TextEditingController();
  int?  _mesaSel;
  bool  _enviando       = false;
  double _descuento     = 0.0;
  String? _cuponOk;
  String? _cuponErr;
  bool  _exito          = false;
  String? _codVerif;

  late AnimationController _exitoCtrl;
  late Animation<double>   _exitoScale;
  late Animation<double>   _exitoOpacity;

  @override
  void initState() {
    super.initState();
    _exitoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _exitoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _exitoCtrl, curve: Curves.elasticOut));
    _exitoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _exitoCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _dirCtrl.dispose(); _refCtrl.dispose(); _cuponCtrl.dispose();
    _exitoCtrl.dispose();
    super.dispose();
  }

  Future<void> _aplicarCupon() async {
    final cod = _cuponCtrl.text.trim().toUpperCase();
    if (cod.isEmpty) return;
    setState(() => _cuponErr = null);
    try {
      final snap = await FirebaseFirestore.instance.collection('cupones')
          .where('codigo', isEqualTo: cod)
          .where('activo', isEqualTo: true).get();
      if (snap.docs.isEmpty) {
        setState(() => _cuponErr = 'Cupón inválido o expirado');
        return;
      }
      final d = snap.docs.first.data();
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

  Future<void> _confirmar(CarritoProvider carrito) async {
    if (_tipoPedido == 'mesa' && _mesaSel == null) {
      _snack('Selecciona una mesa', Colors.orange); return;
    }
    if (_tipoPedido == 'domicilio' && _dirCtrl.text.trim().isEmpty) {
      _snack('Ingresa la dirección de entrega', Colors.orange); return;
    }
    setState(() => _enviando = true);
    try {
      final total = (carrito.total - _descuento).clamp(0.0, double.infinity);
      final pedido = await PedidoService().crearPedido(
        items:            carrito.obtenerItemsParaFirestore(),
        subtotal:         carrito.subtotal,
        total:            total,
        tipoPedido:       _tipoPedido,
        numeroMesa:       _tipoPedido == 'mesa' ? _mesaSel : null,
        direccionEntrega: _tipoPedido == 'domicilio'
            ? {'direccion': _dirCtrl.text.trim(),
               'referencia': _refCtrl.text.trim()} : null,
        metodoPago:       _metodoPago,
      );
      final codigoFinal = pedido?.codigoVerificacion ?? '------';
      setState(() { _exito = true; _codVerif = codigoFinal; });
      carrito.limpiarCarrito();
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      _exitoCtrl.forward();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context);

    if (_exito) {
      return _PantallaExito(
        codigo: _codVerif ?? '------',
        tipoPedido: _tipoPedido,
        mesa: _mesaSel,
        scaleAnim: _exitoScale,
        opacityAnim: _exitoOpacity,
        onNuevo: () => setState(() {
          _exito = false; _tipoPedido = 'mesa'; _mesaSel = null;
          _descuento = 0; _cuponOk = null; _codVerif = null;
          _exitoCtrl.reset();
        }),
      );
    }

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
            ...carrito.items.asMap().entries.map((e) =>
                _ItemCard(item: e.value, index: e.key)),
            const SizedBox(height: 14),

            _Sec('¿Cómo quieres tu pedido?', Column(children: [
              Row(children: [
                Expanded(child: _TipoBtn('🍽️', 'Para mesa',
                    _tipoPedido == 'mesa', () => setState(() {
                      _tipoPedido = 'mesa'; _mesaSel = null; }))),
                const SizedBox(width: 10),
                Expanded(child: _TipoBtn('🛵', 'A domicilio',
                    _tipoPedido == 'domicilio', () => setState(() =>
                        _tipoPedido = 'domicilio'))),
              ]),
              const SizedBox(height: 14),
              if (_tipoPedido == 'mesa')
                _SelectorMesas(mesaSel: _mesaSel,
                    onSel: (n) => setState(() => _mesaSel = n)),
              if (_tipoPedido == 'domicilio') ...[
                _Campo(_dirCtrl, 'Dirección de entrega *', Icons.location_on),
                const SizedBox(height: 10),
                _Campo(_refCtrl, 'Referencia (ej: casa azul)',
                    Icons.info_outline),
              ],
            ])),
            const SizedBox(height: 12),

            _Sec('💳 Método de pago', Row(children: [
              Expanded(child: _MetodoPago('💵', 'Efectivo',
                  _metodoPago == 'efectivo',
                  () => setState(() => _metodoPago = 'efectivo'))),
              const SizedBox(width: 8),
              Expanded(child: _MetodoPago('💳', 'Tarjeta',
                  _metodoPago == 'tarjeta',
                  () => setState(() => _metodoPago = 'tarjeta'))),
              const SizedBox(width: 8),
              Expanded(child: _MetodoPago('📱', 'Transfer.',
                  _metodoPago == 'transferencia',
                  () => setState(() => _metodoPago = 'transferencia'))),
            ])),
            const SizedBox(height: 12),

            _Sec('🎟️ ¿Tienes un cupón?', Column(children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: _cuponCtrl,
                  enabled: _cuponOk == null,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'CÓDIGO',
                    hintStyle: const TextStyle(
                        color: Colors.white24, letterSpacing: 2),
                    filled: true, fillColor: _kCard2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kNaranja)),
                  ),
                )),
                const SizedBox(width: 10),
                _cuponOk != null
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() {
                          _descuento = 0; _cuponOk = null;
                          _cuponErr = null; _cuponCtrl.clear(); }))
                    : ElevatedButton(
                        onPressed: _aplicarCupon,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _kNaranja,
                            foregroundColor: Colors.white, elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text('Aplicar',
                            style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              if (_cuponOk != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Text('✅', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('Cupón "$_cuponOk" — -\$${_descuento.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.green,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              if (_cuponErr != null) ...[
                const SizedBox(height: 6),
                Text(_cuponErr!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ])),
            const SizedBox(height: 12),

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
            ])),
            const SizedBox(height: 90),
          ],
        )),

        // Botón confirmar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          decoration: BoxDecoration(
            color: _kBg,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, -4))],
          ),
          child: GestureDetector(
            onTap: _enviando ? null : () => _confirmar(carrito),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 58,
              decoration: BoxDecoration(
                gradient: _enviando ? null : const LinearGradient(
                    colors: [_kNaranja2, _kNaranja],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: _enviando ? _kNaranja.withValues(alpha: 0.4) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _enviando ? [] : [BoxShadow(
                    color: _kNaranja.withValues(alpha: 0.35),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _enviando
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_outline,
                          size: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _enviando ? 'Procesando...' : 'CONFIRMAR PEDIDO',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.5),
                  )),
                  Column(mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Total', style: TextStyle(
                        color: Colors.white60, fontSize: 10)),
                    Text(
                      '\$${(carrito.total - _descuento).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Pantalla éxito ────────────────────────────────────────────────────────────
class _PantallaExito extends StatelessWidget {
  final String codigo, tipoPedido;
  final int? mesa;
  final Animation<double> scaleAnim, opacityAnim;
  final VoidCallback onNuevo;

  const _PantallaExito({required this.codigo, required this.tipoPedido,
      this.mesa, required this.scaleAnim, required this.opacityAnim,
      required this.onNuevo});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: AnimatedBuilder(
        animation: scaleAnim,
        builder: (_, child) => Transform.scale(scale: scaleAnim.value,
            child: Opacity(opacity: opacityAnim.value, child: child)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3), width: 2),
              boxShadow: [BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 30, offset: const Offset(0, 8))],
            ),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 52))),
          ),
          const SizedBox(height: 24),
          const Text('¡Pedido confirmado!', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            tipoPedido == 'mesa' && mesa != null
                ? 'Mesa $mesa · Preparando tu pedido...'
                : 'Tu pedido está en camino 🛵',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kNaranja.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kNaranja.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              const Text('Código de verificación', style: TextStyle(
                  color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(codigo, style: const TextStyle(
                    color: _kNaranja, fontSize: 32,
                    fontWeight: FontWeight.w900, letterSpacing: 8)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white38, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado ✅'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1)));
                  },
                ),
              ]),
              Text('Muéstralo al recoger tu pedido',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onNuevo,
              icon: const Text('🍕', style: TextStyle(fontSize: 16)),
              label: const Text('Hacer otro pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNaranja, foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52), elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    )),
  );
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
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
          child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
      ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Vaciar')),
    ],
  );
}

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
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
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

class _SelectorMesas extends StatelessWidget {
  final int? mesaSel; final ValueChanged<int?> onSel;
  const _SelectorMesas({this.mesaSel, required this.onSel});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('mesas')
        .where('activa', isEqualTo: true).snapshots(),
    builder: (_, snap) {
      if (!snap.hasData) return const Center(child:
          CircularProgressIndicator(color: _kNaranja, strokeWidth: 2));
      final mesas = snap.data!.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['numero'] as int? ?? 0;
      }).where((n) => n > 0).toList()..sort();

      if (mesas.isEmpty) return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
        child: const Row(children: [
          Text('⚠️', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text('No hay mesas disponibles',
              style: TextStyle(color: Colors.orange, fontSize: 13)),
        ]));

      return Wrap(spacing: 8, runSpacing: 8, children: mesas.map((n) {
        final sel = mesaSel == n;
        return GestureDetector(onTap: () => onSel(n),
          child: AnimatedContainer(duration: const Duration(milliseconds: 150),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: sel ? _kNaranja.withValues(alpha: 0.2) : _kCard2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? _kNaranja : Colors.white.withValues(alpha: 0.1),
                  width: sel ? 2 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Text('🍽️', style: TextStyle(fontSize: 14)),
              Text('$n', style: TextStyle(
                  color: sel ? _kNaranja : Colors.white54,
                  fontSize: 11, fontWeight: FontWeight.bold)),
            ])));
      }).toList());
    });
}

class _Sec extends StatelessWidget {
  final String titulo; final Widget child;
  const _Sec(this.titulo, this.child);
  @override
  Widget build(BuildContext context) => Container(
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
    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            fontSize: 12, fontWeight: FontWeight.w600)),
      ])));
}

class _MetodoPago extends StatelessWidget {
  final String icono, label; final bool sel; final VoidCallback onTap;
  const _MetodoPago(this.icono, this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
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
            fontSize: 10, fontWeight: FontWeight.w600)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kNaranja, width: 1.5)),
    ));
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
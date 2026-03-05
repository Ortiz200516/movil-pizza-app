import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'carrito_provider.dart';
import '../pedidos/pedidos_service.dart';
import '../models/pedido_model.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});
  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  String _tipoPedido     = 'mesa';
  String _metodoPago     = 'efectivo';
  final _direccionCtrl   = TextEditingController();
  final _referenciaCtrl  = TextEditingController();
  final _cuponCtrl       = TextEditingController();
  final _vueltoCtrl      = TextEditingController();
  int?   _mesaSeleccionada;
  bool   _enviando       = false;
  double _descuento      = 0.0;
  String? _cuponAplicado;
  String? _cuponError;

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _referenciaCtrl.dispose();
    _cuponCtrl.dispose();
    _vueltoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text('🛒 Mi Carrito'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: carrito.estaVacio
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🛒', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text('Tu carrito está vacío',
                  style: TextStyle(fontSize: 20, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Ve al menú y agrega tus productos favoritos',
                  style: TextStyle(color: Colors.grey.shade600)),
            ]))
          : Column(children: [
              Expanded(child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...carrito.items.asMap().entries.map((e) => _ItemCard(item: e.value, index: e.key)),
                  const SizedBox(height: 16),
                  _seccion(
                    titulo: '¿Cómo quieres tu pedido?',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _TipoBtn(icon: '🍽️', label: 'Para mesa', selected: _tipoPedido == 'mesa',
                          onTap: () => setState(() { _tipoPedido = 'mesa'; _mesaSeleccionada = null; }))),
                        const SizedBox(width: 12),
                        Expanded(child: _TipoBtn(icon: '🛵', label: 'A domicilio', selected: _tipoPedido == 'domicilio',
                          onTap: () => setState(() => _tipoPedido = 'domicilio'))),
                      ]),
                      const SizedBox(height: 16),
                      if (_tipoPedido == 'mesa')
                        _SelectorMesas(mesaSeleccionada: _mesaSeleccionada,
                          onMesaSeleccionada: (n) => setState(() => _mesaSeleccionada = n)),
                      if (_tipoPedido == 'domicilio') ...[
                        _campo(_direccionCtrl, 'Dirección de entrega *', Icons.location_on),
                        const SizedBox(height: 12),
                        _campo(_referenciaCtrl, 'Referencia (ej: Casa azul, frente al parque)', Icons.info_outline),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _seccion(
                    titulo: '💳 Método de pago',
                    child: _SeccionMetodoPago(
                      metodoPago: _metodoPago,
                      vueltoCtrl: _vueltoCtrl,
                      total: carrito.total - _descuento,
                      onCambio: (m) => setState(() => _metodoPago = m),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _seccion(
                    titulo: '🎟️ ¿Tienes un cupón?',
                    child: _CuponField(
                      ctrl: _cuponCtrl, descuento: _descuento,
                      cuponAplicado: _cuponAplicado, cuponError: _cuponError,
                      onAplicar: () => _aplicarCupon(),
                      onQuitar: () => setState(() {
                        _descuento = 0; _cuponAplicado = null;
                        _cuponError = null; _cuponCtrl.clear();
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _seccion(
                    titulo: 'Resumen',
                    child: Column(children: [
                      _PrecioRow('Subtotal', '\$${carrito.subtotal.toStringAsFixed(2)}'),
                      _PrecioRow('IVA (15%)', '\$${carrito.impuesto.toStringAsFixed(2)}'),
                      if (_descuento > 0)
                        _PrecioRow('🎟️ Descuento', '-\$${_descuento.toStringAsFixed(2)}', color: Colors.green),
                      const Divider(color: Colors.white24),
                      _PrecioRow('TOTAL', '\$${(carrito.total - _descuento).clamp(0, double.infinity).toStringAsFixed(2)}',
                          bold: true, color: Colors.orange),
                    ]),
                  ),
                  const SizedBox(height: 90),
                ],
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -4))],
                ),
                child: GestureDetector(
                  onTap: _enviando ? null : () => _confirmarPedido(context, carrito),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 58,
                    decoration: BoxDecoration(
                      color: _enviando ? Colors.orange.withOpacity(0.5) : const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _enviando ? [] : [BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        if (_enviando)
                          const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        else
                          const Icon(Icons.check_circle_outline, size: 24, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          _enviando ? 'Procesando...' : 'CONFIRMAR PEDIDO',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                        )),
                        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('Total', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text('\$${(carrito.total - _descuento).clamp(0, double.infinity).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon) => TextField(
    controller: ctrl, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label, labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.orange),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange)),
    ),
  );

  Widget _seccion({required String titulo, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Future<void> _aplicarCupon() async {
    final codigo = _cuponCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() => _cuponError = null);
    try {
      final snap = await FirebaseFirestore.instance.collection('cupones')
          .where('codigo', isEqualTo: codigo).where('activo', isEqualTo: true).limit(1).get();
      if (snap.docs.isEmpty) { setState(() => _cuponError = 'Cupón inválido o expirado'); return; }
      final d = snap.docs.first.data();
      final exp = d['expira'] as Timestamp?;
      if (exp != null && exp.toDate().isBefore(DateTime.now())) {
        setState(() => _cuponError = 'Este cupón ya expiró'); return;
      }
      final carrito = Provider.of<CarritoProvider>(context, listen: false);
      final tipo  = d['tipo'] as String? ?? 'porcentaje';
      final valor = (d['descuento'] as num?)?.toDouble() ?? 0.0;
      final desc  = tipo == 'porcentaje' ? carrito.total * valor / 100 : valor;
      setState(() { _descuento = desc; _cuponAplicado = codigo; _cuponError = null; });
    } catch (e) { setState(() => _cuponError = 'Error al verificar cupón'); }
  }

  Future<void> _confirmarPedido(BuildContext context, CarritoProvider carrito) async {
    if (_tipoPedido == 'mesa' && _mesaSeleccionada == null) {
      _snack(context, '🍽️ Selecciona una mesa primero', Colors.red.shade700); return;
    }
    if (_tipoPedido == 'domicilio' && _direccionCtrl.text.isEmpty) {
      _snack(context, '📍 Ingresa tu dirección de entrega', Colors.red.shade700); return;
    }
    if (_metodoPago == 'efectivo' && _vueltoCtrl.text.isNotEmpty) {
      final conPago = double.tryParse(_vueltoCtrl.text) ?? 0;
      if (conPago < carrito.total - _descuento) {
        _snack(context, '💵 El monto debe ser mayor o igual al total', Colors.red.shade700); return;
      }
    }
    setState(() => _enviando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión');
      String metodoFinal = _metodoPago;
      if (_metodoPago == 'efectivo' && _vueltoCtrl.text.isNotEmpty) {
        metodoFinal = 'efectivo (\$${_vueltoCtrl.text})';
      }
      final pedido = await PedidoService().crearPedido(
        items: carrito.obtenerItemsParaFirestore(),
        subtotal: carrito.subtotal,
        total: (carrito.total - _descuento).clamp(0, double.infinity),
        tipoPedido: _tipoPedido,
        numeroMesa: _tipoPedido == 'mesa' ? _mesaSeleccionada : null,
        direccionEntrega: _tipoPedido == 'domicilio'
            ? {'direccion': _direccionCtrl.text.trim(), 'referencia': _referenciaCtrl.text.trim()}
            : null,
        metodoPago: metodoFinal,
      );
      if (pedido != null) {
        carrito.limpiarCarrito();
        if (context.mounted) _mostrarConfirmacion(context, pedido);
      } else { throw Exception('No se pudo crear el pedido'); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _enviando = false); }
  }

  void _snack(BuildContext ctx, String msg, Color color) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));

  void _mostrarConfirmacion(BuildContext context, PedidoModel pedido) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('✅ ¡Pedido Confirmado!', textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (pedido.tipoPedido == 'domicilio') ...[
          const Text('Tu código de verificación:', style: TextStyle(fontSize: 15, color: Colors.white70)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(pedido.codigoVerificacion,
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold,
                      letterSpacing: 10, color: Colors.orange)),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy, color: Colors.orange, size: 16),
                label: const Text('Copiar código', style: TextStyle(color: Colors.orange, fontSize: 13)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pedido.codigoVerificacion));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado ✅'), duration: Duration(seconds: 1)));
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.yellow.withOpacity(0.3))),
            child: const Text('⚠️ Guarda este código. El repartidor lo necesitará para confirmar la entrega.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white70)),
          ),
        ] else ...[
          const Text('🍽️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Mesa ${pedido.numeroMesa ?? ""}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          const Text('Tu pedido está siendo preparado.\nEl mesero te lo llevará a la mesa.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ],
        const SizedBox(height: 16),
        Text('Total: \$${pedido.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
      ]),
      actions: [ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44)),
        child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
      )],
    ));
  }
}

// ── SECCIÓN MÉTODO DE PAGO ────────────────────────────────────
class _SeccionMetodoPago extends StatelessWidget {
  final String metodoPago;
  final TextEditingController vueltoCtrl;
  final double total;
  final void Function(String) onCambio;
  const _SeccionMetodoPago({required this.metodoPago, required this.vueltoCtrl,
      required this.total, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _MetodoBtn(icono: '💵', label: 'Efectivo', desc: 'Paga al recibir',
            color: Colors.green, selected: metodoPago == 'efectivo', onTap: () => onCambio('efectivo'))),
        const SizedBox(width: 10),
        Expanded(child: _MetodoBtn(icono: '💳', label: 'Tarjeta', desc: 'Débito / Crédito',
            color: Colors.blue, selected: metodoPago == 'tarjeta', onTap: () => onCambio('tarjeta'))),
        const SizedBox(width: 10),
        Expanded(child: _MetodoBtn(icono: '📱', label: 'Transferencia', desc: 'Pago digital',
            color: Colors.purple, selected: metodoPago == 'transferencia', onTap: () => onCambio('transferencia'))),
      ]),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: metodoPago == 'efectivo'
            ? _DetalleEfectivo(key: const ValueKey('efectivo'), vueltoCtrl: vueltoCtrl, total: total)
            : metodoPago == 'tarjeta'
                ? const _DetalleTarjeta(key: ValueKey('tarjeta'))
                : const _DetalleTransferencia(key: ValueKey('transferencia')),
      ),
    ]);
  }
}

class _MetodoBtn extends StatelessWidget {
  final String icono, label, desc;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _MetodoBtn({required this.icono, required this.label, required this.desc,
      required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.15) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color.withOpacity(0.7) : Colors.grey.shade700,
            width: selected ? 2 : 1),
      ),
      child: Column(children: [
        Text(icono, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
            color: selected ? color : Colors.grey.shade400)),
        Text(desc, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9,
                color: selected ? color.withOpacity(0.7) : Colors.grey.shade600)),
      ]),
    ),
  );
}

// ── Detalle: Efectivo ─────────────────────────────────────────
class _DetalleEfectivo extends StatefulWidget {
  final TextEditingController vueltoCtrl;
  final double total;
  const _DetalleEfectivo({super.key, required this.vueltoCtrl, required this.total});
  @override
  State<_DetalleEfectivo> createState() => _DetalleEfectivoState();
}

class _DetalleEfectivoState extends State<_DetalleEfectivo> {
  double get _conPago => double.tryParse(widget.vueltoCtrl.text) ?? 0;
  double get _vuelto  => (_conPago - widget.total).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('💵', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Pago en efectivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: widget.vueltoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: '¿Con cuánto paga? (opcional)',
            labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixText: '\$ ',
            prefixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            filled: true, fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.green, width: 1.5)),
          ),
        ),
        if (widget.vueltoCtrl.text.isNotEmpty && _conPago > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _conPago >= widget.total ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _conPago >= widget.total
                  ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_conPago >= widget.total ? '💸 Vuelto estimado' : '⚠️ Monto insuficiente',
                  style: TextStyle(color: _conPago >= widget.total ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(_conPago >= widget.total
                  ? '\$${_vuelto.toStringAsFixed(2)}'
                  : '-\$${(widget.total - _conPago).toStringAsFixed(2)}',
                  style: TextStyle(color: _conPago >= widget.total ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Denominaciones rápidas:', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [5, 10, 20, 50, 100].map((v) {
            final redondeado = (widget.total / v).ceil() * v;
            return GestureDetector(
              onTap: () { widget.vueltoCtrl.text = redondeado.toStringAsFixed(0); setState(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Text('\$$redondeado',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Detalle: Tarjeta ──────────────────────────────────────────
class _DetalleTarjeta extends StatelessWidget {
  const _DetalleTarjeta({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('💳', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Pago con tarjeta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity, height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('💳 TARJETA', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2)),
              Row(children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.red.withOpacity(0.7), shape: BoxShape.circle)),
                Transform.translate(offset: const Offset(-8, 0),
                  child: Container(width: 20, height: 20,
                      decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.7), shape: BoxShape.circle))),
              ]),
            ]),
            const Text('•••• •••• •••• ••••', style: TextStyle(color: Colors.white60, fontSize: 16, letterSpacing: 3)),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16), SizedBox(width: 8),
            Expanded(child: Text('El cobro se realizará al momento de la entrega con datáfono portátil.',
                style: TextStyle(color: Colors.blue, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: ['VISA', 'Mastercard', 'Amex', 'Diners'].map((l) =>
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3))),
              child: Text(l, style: const TextStyle(color: Colors.blue, fontSize: 11)))).toList()),
      ]),
    );
  }
}

// ── Detalle: Transferencia ────────────────────────────────────
class _DetalleTransferencia extends StatelessWidget {
  const _DetalleTransferencia({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('📱', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Transferencia / Pago digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        _DatoBancario(icono: '🏦', label: 'Banco', valor: 'Banco Pichincha'),
        const SizedBox(height: 8),
        _DatoBancario(icono: '👤', label: 'Titular', valor: 'La Italiana S.A.'),
        const SizedBox(height: 8),
        _DatoBancario(icono: '💳', label: 'Cuenta corriente', valor: '2200847621', copiable: true),
        const SizedBox(height: 8),
        _DatoBancario(icono: '🪪', label: 'RUC', valor: '0912345678001', copiable: true),
        const SizedBox(height: 8),
        _DatoBancario(icono: '📧', label: 'Email / Nequi', valor: 'pagos@laitaliana.com', copiable: true),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.amber, size: 16), SizedBox(width: 8),
            Expanded(child: Text('Envía el comprobante de pago al número de WhatsApp del local.',
                style: TextStyle(color: Colors.amber, fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

class _DatoBancario extends StatelessWidget {
  final String icono, label, valor;
  final bool copiable;
  const _DatoBancario({required this.icono, required this.label, required this.valor, this.copiable = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Row(children: [
      Text(icono, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ])),
      if (copiable)
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: valor));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$label copiado ✅'), duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating));
          },
          child: Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.copy, color: Colors.purple, size: 14)),
        ),
    ]),
  );
}

// ── WIDGETS BASE (sin cambios) ────────────────────────────────
class _SelectorMesas extends StatelessWidget {
  final int? mesaSeleccionada;
  final void Function(int) onMesaSeleccionada;
  const _SelectorMesas({required this.mesaSeleccionada, required this.onMesaSeleccionada});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mesas').where('activa', isEqualTo: true).orderBy('numero').snapshots(),
      builder: (context, mesasSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pedidos')
              .where('tipoPedido', isEqualTo: 'mesa')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo']).snapshots(),
          builder: (context, pedidosSnap) {
            if (mesasSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.orange)));
            }
            final mesas = mesasSnap.data?.docs ?? [];
            final mesasOcupadas = <int>{};
            for (final doc in pedidosSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              final mesa = data['numeroMesa'];
              if (mesa != null) mesasOcupadas.add(mesa as int);
            }
            if (mesas.isEmpty) {
              return Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange), SizedBox(width: 10),
                  Expanded(child: Text('No hay mesas configuradas.\nContacta al administrador.',
                      style: TextStyle(color: Colors.orange, fontSize: 13))),
                ]));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Leyenda(color: Colors.green, label: 'Libre'),
                const SizedBox(width: 16),
                _Leyenda(color: Colors.red.shade400, label: 'Ocupada'),
                const SizedBox(width: 16),
                _Leyenda(color: Colors.orange, label: 'Seleccionada'),
              ]),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
                itemCount: mesas.length,
                itemBuilder: (_, i) {
                  final data = mesas[i].data() as Map<String, dynamic>;
                  final numero = data['numero'] as int;
                  final capacidad = data['capacidad'] as int? ?? 4;
                  final ocupada = mesasOcupadas.contains(numero);
                  final seleccionada = mesaSeleccionada == numero;
                  return _MesaBtn(numero: numero, capacidad: capacidad,
                      ocupada: ocupada, seleccionada: seleccionada,
                      onTap: ocupada ? null : () => onMesaSeleccionada(numero));
                },
              ),
              if (mesaSeleccionada != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.5))),
                  child: Row(children: [
                    const Icon(Icons.table_restaurant, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text('Mesa $mesaSeleccionada seleccionada ✅',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
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
    final Color color = seleccionada ? Colors.orange : ocupada ? Colors.red.shade400 : Colors.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withOpacity(seleccionada ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(seleccionada ? 1.0 : 0.5), width: seleccionada ? 2.5 : 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ocupada ? '🔴' : seleccionada ? '✅' : '🟢', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text('$numero', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people, size: 11, color: color.withOpacity(0.7)),
            const SizedBox(width: 2),
            Text('$capacidad', style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ]),
          if (ocupada) Text('Ocupada', style: TextStyle(fontSize: 9, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color; final String label;
  const _Leyenda({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
  ]);
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item; final int index;
  const _ItemCard({required this.item, required this.index});
  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    final nombre   = item['nombre'] ?? '';
    final precio   = (item['precio'] ?? item['precioBase'] ?? 0.0) as double;
    final cantidad = (item['cantidad'] ?? 1) as int;
    final icono    = item['icono'] ?? '🍽️';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Text(icono, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          Text('\$${(precio * cantidad).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ])),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
              onPressed: () => carrito.disminuirCantidad(index)),
          Text('$cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
              onPressed: () => carrito.aumentarCantidad(index)),
        ]),
      ]),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String icon, label; final bool selected; final VoidCallback onTap;
  const _TipoBtn({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? Colors.orange.withOpacity(0.15) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? Colors.orange : Colors.grey.shade700, width: 2),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold,
            color: selected ? Colors.orange : Colors.grey.shade400)),
      ]),
    ),
  );
}

class _CuponField extends StatelessWidget {
  final TextEditingController ctrl;
  final double descuento;
  final String? cuponAplicado, cuponError;
  final VoidCallback onAplicar, onQuitar;
  const _CuponField({required this.ctrl, required this.descuento,
      required this.cuponAplicado, required this.cuponError,
      required this.onAplicar, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    if (cuponAplicado != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.4))),
        child: Row(children: [
          const Text('🎟️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cuponAplicado!, style: const TextStyle(color: Colors.green,
                fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 2)),
            Text('-\$${descuento.toStringAsFixed(2)} de descuento',
                style: const TextStyle(color: Colors.green, fontSize: 12)),
          ])),
          IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: onQuitar),
        ]),
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(child: TextField(
          controller: ctrl, textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Código de cupón', hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.local_offer_outlined, color: Colors.orange),
            filled: true, fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange)),
          ),
        )),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onAplicar,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
      if (cuponError != null) ...[
        const SizedBox(height: 8),
        Text(cuponError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ],
    ]);
  }
}

class _PrecioRow extends StatelessWidget {
  final String label, valor; final bool bold; final Color? color;
  const _PrecioRow(this.label, this.valor, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: bold ? Colors.white : Colors.grey.shade400,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
      Text(valor, style: TextStyle(color: color ?? (bold ? Colors.white : Colors.grey.shade400),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
    ]),
  );
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'carrito_provider.dart';
import '../pedidos/pedido_provider.dart';
import '../pedidos/pedidos_service.dart';
import '../models/pedido_model.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});
  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  String _tipoPedido = 'mesa';
  final _direccionCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  final _mesaCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _direccionCtrl.dispose(); _referenciaCtrl.dispose(); _mesaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Mi Carrito'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: carrito.estaVacio
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🛒', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text('Tu carrito está vacío', style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Ve al menú y agrega tus productos favoritos', style: TextStyle(color: Colors.grey.shade400)),
            ]))
          : Column(
              children: [
                Expanded(child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Lista de items
                    ...carrito.items.asMap().entries.map((e) => _ItemCard(item: e.value, index: e.key)),
                    const SizedBox(height: 16),
                    // Tipo de pedido
                    Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('¿Cómo quieres tu pedido?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _TipoBtn(icon: '🍽️', label: 'Para mesa', selected: _tipoPedido == 'mesa', onTap: () => setState(() => _tipoPedido = 'mesa'))),
                            const SizedBox(width: 12),
                            Expanded(child: _TipoBtn(icon: '🛵', label: 'A domicilio', selected: _tipoPedido == 'domicilio', onTap: () => setState(() => _tipoPedido = 'domicilio'))),
                          ]),
                          const SizedBox(height: 16),
                          if (_tipoPedido == 'mesa') ...[
                            TextField(
                              controller: _mesaCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Número de mesa', prefixIcon: const Icon(Icons.table_restaurant), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ] else ...[
                            TextField(controller: _direccionCtrl,
                              decoration: InputDecoration(labelText: 'Dirección de entrega *', prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: _referenciaCtrl,
                              decoration: InputDecoration(labelText: 'Referencia (ej: Casa azul, frente al parque)', prefixIcon: const Icon(Icons.info_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Resumen de precios
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          _PrecioRow('Subtotal', '\$${carrito.subtotal.toStringAsFixed(2)}'),
                          _PrecioRow('IVA (15%)', '\$${carrito.impuesto.toStringAsFixed(2)}'),
                          const Divider(),
                          _PrecioRow('TOTAL', '\$${carrito.total.toStringAsFixed(2)}', bold: true, color: Colors.green),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                )),
                // Botón confirmar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _enviando ? null : () => _confirmarPedido(context, carrito),
                      icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                      label: Text(_enviando ? 'Enviando...' : 'CONFIRMAR PEDIDO', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmarPedido(BuildContext context, CarritoProvider carrito) async {
    // Validaciones
    if (_tipoPedido == 'mesa' && _mesaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el número de mesa'), backgroundColor: Colors.red));
      return;
    }
    if (_tipoPedido == 'domicilio' && _direccionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa tu dirección de entrega'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _enviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión');

      final service = PedidoService();
      final pedido = await service.crearPedido(
        items: carrito.obtenerItemsParaFirestore(),
        subtotal: carrito.subtotal,
        total: carrito.total,
        tipoPedido: _tipoPedido,
        numeroMesa: _tipoPedido == 'mesa' ? int.tryParse(_mesaCtrl.text) : null,
        direccionEntrega: _tipoPedido == 'domicilio' ? {
          'direccion': _direccionCtrl.text.trim(),
          'referencia': _referenciaCtrl.text.trim(),
        } : null,
      );

      if (pedido != null) {
        carrito.limpiarCarrito();
        if (context.mounted) {
          _mostrarCodigoConfirmacion(context, pedido);
        }
      } else {
        throw Exception('No se pudo crear el pedido');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarCodigoConfirmacion(BuildContext context, PedidoModel pedido) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ ¡Pedido Confirmado!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (pedido.tipoPedido == 'domicilio') ...[
            const Text('Tu código de verificación:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(pedido.codigoVerificacion,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.deepOrange)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.copy, color: Colors.orange),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pedido.codigoVerificacion));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1)));
                    }),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                '⚠️ Guarda este código. El repartidor lo necesitará para confirmar la entrega. NO lo compartas antes de recibir tu pedido.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13),
              ),
            ),
          ] else ...[
            Text('Mesa ${pedido.numeroMesa ?? ""}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tu pedido está siendo preparado. El mesero te lo llevará a la mesa.', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          Text('Total: \$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item; final int index;
  const _ItemCard({required this.item, required this.index});
  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    final nombre = item['nombre'] ?? '';
    final precio = (item['precio'] ?? item['precioBase'] ?? 0.0) as double;
    final cantidad = (item['cantidad'] ?? 1) as int;
    final icono = item['icono'] ?? '🍽️';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text(icono, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('\$${(precio * cantidad).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ])),
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => carrito.disminuirCantidad(index)),
            Text('$cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: () => carrito.aumentarCantidad(index)),
          ]),
        ]),
      ),
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
        color: selected ? Colors.orange : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? Colors.orange : Colors.grey.shade300, width: 2),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.grey.shade700)),
      ]),
    ),
  );
}

Widget _PrecioRow(String label, String valor, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    Text(valor, style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
  ]),
);
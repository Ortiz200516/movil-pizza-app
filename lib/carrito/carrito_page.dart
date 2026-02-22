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
  String _tipoPedido = 'mesa';
  final _direccionCtrl   = TextEditingController();
  final _referenciaCtrl  = TextEditingController();
  int?  _mesaSeleccionada;
  bool  _enviando = false;

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _referenciaCtrl.dispose();
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
                  // ── Items del carrito ──
                  ...carrito.items.asMap().entries.map((e) => _ItemCard(item: e.value, index: e.key)),
                  const SizedBox(height: 16),

                  // ── Tipo de pedido ──
                  _seccion(
                    titulo: '¿Cómo quieres tu pedido?',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _TipoBtn(
                          icon: '🍽️', label: 'Para mesa',
                          selected: _tipoPedido == 'mesa',
                          onTap: () => setState(() { _tipoPedido = 'mesa'; _mesaSeleccionada = null; }),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _TipoBtn(
                          icon: '🛵', label: 'A domicilio',
                          selected: _tipoPedido == 'domicilio',
                          onTap: () => setState(() => _tipoPedido = 'domicilio'),
                        )),
                      ]),
                      const SizedBox(height: 16),

                      // ── Selector de mesa ──
                      if (_tipoPedido == 'mesa')
                        _SelectorMesas(
                          mesaSeleccionada: _mesaSeleccionada,
                          onMesaSeleccionada: (n) => setState(() => _mesaSeleccionada = n),
                        ),

                      // ── Campos domicilio ──
                      if (_tipoPedido == 'domicilio') ...[
                        _campo(_direccionCtrl, 'Dirección de entrega *', Icons.location_on),
                        const SizedBox(height: 12),
                        _campo(_referenciaCtrl, 'Referencia (ej: Casa azul, frente al parque)', Icons.info_outline),
                      ],
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Resumen de precios ──
                  _seccion(
                    titulo: 'Resumen',
                    child: Column(children: [
                      _PrecioRow('Subtotal', '\$${carrito.subtotal.toStringAsFixed(2)}'),
                      _PrecioRow('IVA (15%)', '\$${carrito.impuesto.toStringAsFixed(2)}'),
                      const Divider(color: Colors.white24),
                      _PrecioRow('TOTAL', '\$${carrito.total.toStringAsFixed(2)}',
                          bold: true, color: Colors.orange),
                    ]),
                  ),
                  const SizedBox(height: 90),
                ],
              )),

              // ── Botón confirmar ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                color: const Color(0xFF0F172A),
                child: SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : () => _confirmarPedido(context, carrito),
                    icon: _enviando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle),
                    label: Text(_enviando ? 'Enviando...' : 'CONFIRMAR PEDIDO',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.orange),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
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
      Text(titulo, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Future<void> _confirmarPedido(BuildContext context, CarritoProvider carrito) async {
    if (_tipoPedido == 'mesa' && _mesaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona una mesa'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_tipoPedido == 'domicilio' && _direccionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa tu dirección de entrega'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _enviando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión');

      final pedido = await PedidoService().crearPedido(
        items: carrito.obtenerItemsParaFirestore(),
        subtotal: carrito.subtotal,
        total: carrito.total,
        tipoPedido: _tipoPedido,
        numeroMesa: _tipoPedido == 'mesa' ? _mesaSeleccionada : null,
        direccionEntrega: _tipoPedido == 'domicilio'
            ? {'direccion': _direccionCtrl.text.trim(), 'referencia': _referenciaCtrl.text.trim()}
            : null,
      );

      if (pedido != null) {
        carrito.limpiarCarrito();
        if (context.mounted) _mostrarConfirmacion(context, pedido);
      } else {
        throw Exception('No se pudo crear el pedido');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarConfirmacion(BuildContext context, PedidoModel pedido) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ ¡Pedido Confirmado!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (pedido.tipoPedido == 'domicilio') ...[
            const Text('Tu código de verificación:',
                style: TextStyle(fontSize: 15, color: Colors.white70)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(pedido.codigoVerificacion,
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold,
                        letterSpacing: 10, color: Colors.orange)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.orange),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pedido.codigoVerificacion));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado ✅'),
                            duration: Duration(seconds: 1)));
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.yellow.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️ Guarda este código. El repartidor lo necesitará para confirmar la entrega.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ] else ...[
            const Text('🍽️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text('Mesa ${pedido.numeroMesa ?? ""}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 8),
            const Text('Tu pedido está siendo preparado.\nEl mesero te lo llevará a la mesa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          Text('Total: \$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44)),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─── Selector Visual de Mesas ────────────────────────────────
class _SelectorMesas extends StatelessWidget {
  final int? mesaSeleccionada;
  final void Function(int) onMesaSeleccionada;
  const _SelectorMesas({required this.mesaSeleccionada, required this.onMesaSeleccionada});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesas')
          .where('activa', isEqualTo: true)
          .orderBy('numero')
          .snapshots(),
      builder: (context, mesasSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pedidos')
              .where('tipoPedido', isEqualTo: 'mesa')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
              .snapshots(),
          builder: (context, pedidosSnap) {
            if (mesasSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }

            final mesas = mesasSnap.data?.docs ?? [];

            // Mesas con pedido activo
            final mesasOcupadas = <int>{};
            for (final doc in pedidosSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              final mesa = data['numeroMesa'];
              if (mesa != null) mesasOcupadas.add(mesa as int);
            }

            if (mesas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(child: Text('No hay mesas configuradas.\nContacta al administrador.',
                      style: TextStyle(color: Colors.orange, fontSize: 13))),
                ]),
              );
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Leyenda
              Row(children: [
                _Leyenda(color: Colors.green, label: 'Libre'),
                const SizedBox(width: 16),
                _Leyenda(color: Colors.red.shade400, label: 'Ocupada'),
                const SizedBox(width: 16),
                _Leyenda(color: Colors.orange, label: 'Seleccionada'),
              ]),
              const SizedBox(height: 12),

              // Grid de mesas
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: mesas.length,
                itemBuilder: (_, i) {
                  final data = mesas[i].data() as Map<String, dynamic>;
                  final numero = data['numero'] as int;
                  final capacidad = data['capacidad'] as int? ?? 4;
                  final ocupada = mesasOcupadas.contains(numero);
                  final seleccionada = mesaSeleccionada == numero;

                  return _MesaBtn(
                    numero: numero,
                    capacidad: capacidad,
                    ocupada: ocupada,
                    seleccionada: seleccionada,
                    onTap: ocupada ? null : () => onMesaSeleccionada(numero),
                  );
                },
              ),

              if (mesaSeleccionada != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.table_restaurant, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text('Mesa $mesaSeleccionada seleccionada ✅',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
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
    final Color color = seleccionada
        ? Colors.orange
        : ocupada
            ? Colors.red.shade400
            : Colors.green;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withOpacity(seleccionada ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withOpacity(seleccionada ? 1.0 : 0.5),
              width: seleccionada ? 2.5 : 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ocupada ? '🔴' : seleccionada ? '✅' : '🟢',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text('$numero',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people, size: 11, color: color.withOpacity(0.7)),
            const SizedBox(width: 2),
            Text('$capacidad',
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ]),
          if (ocupada)
            Text('Ocupada',
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.8),
                    fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String label;
  const _Leyenda({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
  ]);
}

// ─── Item del carrito ────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Text(icono, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          Text('\$${(precio * cantidad).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ])),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
            onPressed: () => carrito.disminuirCantidad(index),
          ),
          Text('$cantidad',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
            onPressed: () => carrito.aumentarCantidad(index),
          ),
        ]),
      ]),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
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
        border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade700, width: 2),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.orange : Colors.grey.shade400)),
      ]),
    ),
  );
}

Widget _PrecioRow(String label, String valor, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(
        fontSize: bold ? 16 : 14,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: Colors.white70)),
    Text(valor, style: TextStyle(
        fontSize: bold ? 18 : 14,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color ?? Colors.white)),
  ]),
);
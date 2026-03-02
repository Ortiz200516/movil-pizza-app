import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto_model.dart';

class DisponibilidadPage extends StatefulWidget {
  const DisponibilidadPage({super.key});
  @override
  State<DisponibilidadPage> createState() => _DisponibilidadPageState();
}

class _DisponibilidadPageState extends State<DisponibilidadPage> {
  final _db = FirebaseFirestore.instance;
  String _catSel = 'todos';

  static const _categorias = [
    ('todos', '🍽️ Todos'),
    ('pizza', '🍕 Pizzas'),
    ('hamburguesa', '🍔 Hamburguesas'),
    ('cerveza', '🍺 Cervezas'),
    ('bebida', '🥤 Bebidas'),
    ('entrada', '🍟 Entradas'),
    ('ensalada', '🥗 Ensaladas'),
    ('postre', '🍰 Postres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.purple.shade50,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _categorias.map((cat) {
                final (val, label) = cat;
                final sel = _catSel == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _catSel = val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.purple : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? Colors.purple : Colors.grey.shade300),
                      ),
                      child: Text(label, style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : Colors.grey.shade700,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('productos').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.purple));
              }
              var productos = (snap.data?.docs ?? [])
                  .map((d) => ProductoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                  .toList();
              if (_catSel != 'todos') {
                productos = productos.where((p) => p.categoria.toLowerCase() == _catSel).toList();
              }
              productos.sort((a, b) {
                if (a.disponible == b.disponible) return a.nombre.compareTo(b.nombre);
                return a.disponible ? -1 : 1;
              });
              if (productos.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🍽️', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 12),
                    Text('No hay productos en esta categoría',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  ]),
                );
              }
              final disponibles = productos.where((p) => p.disponible).length;
              final total = productos.length;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.white,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$disponibles disponibles de $total',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? disponibles / total : 0,
                              minHeight: 6,
                              backgroundColor: Colors.red.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () => _toggleTodos(productos, true),
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        label: const Text('Todo ON', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ),
                      TextButton.icon(
                        onPressed: () => _toggleTodos(productos, false),
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                        label: const Text('Todo OFF', style: TextStyle(fontSize: 11, color: Colors.red)),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: productos.length,
                      itemBuilder: (_, i) => _ProductoDisponibilidadCard(
                        producto: productos[i],
                        onToggle: (v) => _db.collection('productos').doc(productos[i].id).update({'disponible': v}),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleTodos(List<ProductoModel> productos, bool estado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(estado ? '✅ Habilitar todo' : '❌ Deshabilitar todo'),
        content: Text(estado ? '¿Habilitar todos los productos mostrados?' : '¿Deshabilitar todos los productos mostrados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: estado ? Colors.green : Colors.red, foregroundColor: Colors.white),
            child: Text(estado ? 'Habilitar todo' : 'Deshabilitar todo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final batch = _db.batch();
    for (final p in productos) {
      batch.update(_db.collection('productos').doc(p.id), {'disponible': estado});
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(estado ? '✅ Todos habilitados' : '❌ Todos deshabilitados'),
        backgroundColor: estado ? Colors.green : Colors.red,
      ));
    }
  }
}

class _ProductoDisponibilidadCard extends StatefulWidget {
  final ProductoModel producto;
  final Future<void> Function(bool) onToggle;
  const _ProductoDisponibilidadCard({required this.producto, required this.onToggle});
  @override
  State<_ProductoDisponibilidadCard> createState() => _ProductoDisponibilidadCardState();
}

class _ProductoDisponibilidadCardState extends State<_ProductoDisponibilidadCard> {
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.disponible ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (p.disponible ? Colors.green : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(p.icono, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nombre, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14,
                color: p.disponible ? Colors.black87 : Colors.grey.shade400,
                decoration: p.disponible ? null : TextDecoration.lineThrough,
              )),
              const SizedBox(height: 4),
              Row(children: [
                Text('\$${p.precio.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: p.disponible ? Colors.green : Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(p.categoria, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (p.disponible ? Colors.green : Colors.red).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(p.disponible ? '✅ Disponible' : '❌ Agotado',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: p.disponible ? Colors.green : Colors.red)),
                ),
              ]),
            ]),
          ),
          _cargando
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))
              : Switch(
                  value: p.disponible,
                  onChanged: (v) async {
                    setState(() => _cargando = true);
                    await widget.onToggle(v);
                    if (mounted) setState(() => _cargando = false);
                  },
                  activeThumbColor: Colors.green,
                ),
        ]),
      ),
    );
  }
}
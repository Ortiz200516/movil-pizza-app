import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MesasAdminPage extends StatefulWidget {
  const MesasAdminPage({super.key});
  @override
  State<MesasAdminPage> createState() => _MesasAdminPageState();
}

class _MesasAdminPageState extends State<MesasAdminPage> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('mesas').orderBy('numero').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purple));
          }
          final mesas = snap.data?.docs ?? [];
          return Column(
            children: [
              Container(
                color: Colors.purple.shade50,
                padding: const EdgeInsets.all(14),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('pedidos')
                      .where('tipoPedido', isEqualTo: 'mesa')
                      .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
                      .snapshots(),
                  builder: (context, pedidosSnap) {
                    final mesasOcupadas = <int>{};
                    for (final doc in pedidosSnap.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      final mesa = data['numeroMesa'];
                      if (mesa != null) mesasOcupadas.add(mesa as int);
                    }
                    final total = mesas.length;
                    final activas = mesas.where((m) {
                      final data = m.data() as Map<String, dynamic>;
                      return data['activa'] == true;
                    }).length;
                    final ocupadas = mesasOcupadas.length;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MesaResumenItem('Total', '$total', Icons.table_restaurant, Colors.purple),
                        _MesaResumenItem('Activas', '$activas', Icons.check_circle, Colors.green),
                        _MesaResumenItem('Ocupadas', '$ocupadas', Icons.people, Colors.orange),
                        _MesaResumenItem('Libres', '${activas - ocupadas}', Icons.event_seat, Colors.teal),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: mesas.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('🍽️', style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 12),
                          const Text('No hay mesas configuradas',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('Toca el botón ➕ para agregar mesas',
                            style: TextStyle(color: Colors.grey.shade500)),
                        ]),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('pedidos')
                            .where('tipoPedido', isEqualTo: 'mesa')
                            .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
                            .snapshots(),
                        builder: (context, pedidosSnap) {
                          final mesasOcupadas = <int, String>{};
                          for (final doc in pedidosSnap.data?.docs ?? []) {
                            final data = doc.data() as Map<String, dynamic>;
                            final mesa = data['numeroMesa'];
                            final estado = data['estado'] ?? '';
                            if (mesa != null) mesasOcupadas[mesa as int] = estado;
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: mesas.length,
                            itemBuilder: (_, i) {
                              final doc = mesas[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final numero = data['numero'] as int;
                              final activa = data['activa'] as bool? ?? true;
                              final capacidad = data['capacidad'] as int? ?? 4;
                              final estadoPedido = mesasOcupadas[numero];
                              final ocupada = estadoPedido != null;
                              return _MesaCard(
                                docId: doc.id,
                                numero: numero,
                                activa: activa,
                                capacidad: capacidad,
                                ocupada: ocupada,
                                estadoPedido: estadoPedido,
                                onToggle: () => _toggleMesa(doc.id, activa),
                                onEditar: () => _editarMesa(doc.id, numero, capacidad, activa),
                                onEliminar: () => _confirmarEliminar(doc.id, numero),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarMesa,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Mesa'),
      ),
    );
  }

  Future<void> _toggleMesa(String docId, bool estadoActual) async {
    await _db.collection('mesas').doc(docId).update({'activa': !estadoActual});
  }

  Future<void> _agregarMesa() async {
    final numCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '4');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('➕ Agregar Mesa'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: numCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de mesa', prefixIcon: Icon(Icons.table_restaurant), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: capCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacidad (personas)', prefixIcon: Icon(Icons.people), border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final num = int.tryParse(numCtrl.text);
              final cap = int.tryParse(capCtrl.text) ?? 4;
              if (num == null) return;
              await _db.collection('mesas').add({'numero': num, 'capacidad': cap, 'activa': true});
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarMesa(String docId, int numero, int capacidad, bool activa) async {
    final capCtrl = TextEditingController(text: capacidad.toString());
    bool activaLocal = activa;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('✏️ Mesa $numero'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: capCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacidad', prefixIcon: Icon(Icons.people), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Mesa activa'),
              value: activaLocal,
              onChanged: (v) => setSt(() => activaLocal = v),
              activeColor: Colors.purple,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await _db.collection('mesas').doc(docId).update({
                  'capacidad': int.tryParse(capCtrl.text) ?? capacidad,
                  'activa': activaLocal,
                });
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(String docId, int numero) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Eliminar Mesa'),
        content: Text('¿Eliminar la Mesa $numero?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await _db.collection('mesas').doc(docId).delete();
  }
}

class _MesaCard extends StatelessWidget {
  final String docId;
  final int numero, capacidad;
  final bool activa, ocupada;
  final String? estadoPedido;
  final VoidCallback onToggle, onEditar, onEliminar;

  const _MesaCard({
    required this.docId, required this.numero, required this.capacidad,
    required this.activa, required this.ocupada, required this.estadoPedido,
    required this.onToggle, required this.onEditar, required this.onEliminar,
  });

  Color get _color {
    if (!activa) return Colors.grey;
    if (ocupada) return Colors.orange;
    return Colors.green;
  }

  String get _estadoLabel {
    if (!activa) return 'Inactiva';
    if (estadoPedido == 'Listo') return '✅ Listo';
    if (estadoPedido == 'Preparando') return '👨‍🍳 Cocina';
    if (ocupada) return '🟡 Ocupada';
    return '🟢 Libre';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return GestureDetector(
      onTap: onEditar,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 2),
              ),
              child: Center(child: Text('$numero',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_estadoLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.people, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text('$capacidad', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: onToggle,
                child: Icon(activa ? Icons.toggle_on : Icons.toggle_off,
                  color: activa ? Colors.green : Colors.grey, size: 24),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MesaResumenItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MesaResumenItem(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 24),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
  ]);
}
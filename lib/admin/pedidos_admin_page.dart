import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class PedidosAdminPage extends StatefulWidget {
  const PedidosAdminPage({super.key});
  @override
  State<PedidosAdminPage> createState() => _PedidosAdminPageState();
}

class _PedidosAdminPageState extends State<PedidosAdminPage> {
  String _filtroEstado = 'todos';

  static const _estados = [
    ('todos', 'Todos', Icons.all_inbox, Colors.purple),
    ('Pendiente', 'Pendiente', Icons.schedule, Colors.orange),
    ('Preparando', 'Preparando', Icons.restaurant, Colors.blue),
    ('Listo', 'Listo', Icons.check_circle, Colors.green),
    ('En camino', 'En camino', Icons.delivery_dining, Colors.indigo),
    ('Entregado', 'Entregado', Icons.done_all, Colors.teal),
    ('Cancelado', 'Cancelado', Icons.cancel, Colors.red),
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
              children: _estados.map((e) {
                final (val, label, icon, color) = e;
                final sel = _filtroEstado == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(icon, size: 16, color: sel ? Colors.white : color),
                    label: Text(label, style: TextStyle(
                      fontSize: 12,
                      color: sel ? Colors.white : color,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    )),
                    selected: sel,
                    onSelected: (_) => setState(() => _filtroEstado = val),
                    backgroundColor: Colors.white,
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: sel ? color : Colors.grey.shade300),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PedidoModel>>(
            stream: PedidoService().obtenerTodosPedidos(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.purple));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              var pedidos = snap.data ?? [];
              if (_filtroEstado != 'todos') {
                pedidos = pedidos.where((p) => p.estado == _filtroEstado).toList();
              }
              if (pedidos.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No hay pedidos', style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  ]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: pedidos.length,
                itemBuilder: (_, i) => _PedidoAdminCard(pedido: pedidos[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PedidoAdminCard extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoAdminCard({required this.pedido});

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'Pendiente': return Colors.orange;
      case 'Preparando': return Colors.blue;
      case 'Listo': return Colors.green;
      case 'En camino': return Colors.indigo;
      case 'Entregado': return Colors.teal;
      case 'Cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado;
    final hora = '${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}';
    final esMesa = pedido.tipoPedido == 'mesa';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(pedido.iconoEstado, style: const TextStyle(fontSize: 18)),
        ),
        title: Row(children: [
          Expanded(child: Text(pedido.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(pedido.estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(esMesa ? Icons.table_restaurant : Icons.delivery_dining, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(esMesa ? 'Mesa ${pedido.numeroMesa ?? "?"}' : 'Domicilio', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(hora, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
          ]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(),
              const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...pedido.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${item['cantidad']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item['productoNombre'] ?? '', style: const TextStyle(fontSize: 13))),
                  Text('\$${((item['precioTotal'] ?? 0.0) as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
              )),
              const Divider(),
              if (!esMesa && pedido.direccionEntrega != null)
                _InfoRow(Icons.location_on, 'Dirección', pedido.direccionEntrega!['direccion'] ?? ''),
              if (pedido.clienteTelefono != null)
                _InfoRow(Icons.phone, 'Teléfono', pedido.clienteTelefono!),
              if (pedido.notasEspeciales?.isNotEmpty == true)
                _InfoRow(Icons.note, 'Notas', pedido.notasEspeciales!),
              _InfoRow(Icons.payment, 'Pago', pedido.metodoPago),
              const SizedBox(height: 8),
              _CambiarEstadoRow(pedido: pedido, color: color),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _CambiarEstadoRow extends StatefulWidget {
  final PedidoModel pedido;
  final Color color;
  const _CambiarEstadoRow({required this.pedido, required this.color});
  @override
  State<_CambiarEstadoRow> createState() => _CambiarEstadoRowState();
}

class _CambiarEstadoRowState extends State<_CambiarEstadoRow> {
  bool _cargando = false;
  static const _todosEstados = ['Pendiente', 'Preparando', 'Listo', 'En camino', 'Entregado', 'Cancelado'];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text('Cambiar estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 10),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.pedido.estado,
            isDense: true,
            items: _todosEstados.map((e) => DropdownMenuItem(
              value: e, child: Text(e, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: _cargando ? null : (nuevoEstado) async {
              if (nuevoEstado == null || nuevoEstado == widget.pedido.estado) return;
              setState(() => _cargando = true);
              await PedidoService().actualizarEstado(widget.pedido.id, nuevoEstado);
              if (mounted) {
                setState(() => _cargando = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ Estado → $nuevoEstado'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
        ),
      ),
      if (_cargando)
        const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)),
    ]);
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  String _periodo = 'hoy';

  DateTime get _desde {
    final now = DateTime.now();
    switch (_periodo) {
      case 'hoy': return DateTime(now.year, now.month, now.day);
      case 'semana': return now.subtract(const Duration(days: 7));
      case 'mes': return DateTime(now.year, now.month, 1);
      default: return DateTime(now.year, now.month, now.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.purple.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.date_range, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text('Período:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _RepPeriodoBtn(label: 'Hoy', val: 'hoy', actual: _periodo, onChange: (v) => setState(() => _periodo = v)),
              const SizedBox(width: 8),
              _RepPeriodoBtn(label: '7 días', val: 'semana', actual: _periodo, onChange: (v) => setState(() => _periodo = v)),
              const SizedBox(width: 8),
              _RepPeriodoBtn(label: 'Este mes', val: 'mes', actual: _periodo, onChange: (v) => setState(() => _periodo = v)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('pedidos')
                .where('estado', isEqualTo: 'Entregado')
                .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_desde))
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.purple));
              }
              final docs = snap.data?.docs ?? [];
              final pedidos = docs.map((d) =>
                PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();

              final totalVentas = pedidos.fold(0.0, (s, p) => s + p.total);
              final totalPedidos = pedidos.length;
              final ticketPromedio = totalPedidos > 0 ? totalVentas / totalPedidos : 0.0;
              final pedidosMesa = pedidos.where((p) => p.tipoPedido == 'mesa').length;
              final pedidosDomicilio = pedidos.where((p) => p.tipoPedido == 'domicilio').length;

              final Map<String, int> vendidos = {};
              final Map<String, double> ingresosPorProducto = {};
              for (final p in pedidos) {
                for (final item in p.items) {
                  final nombre = (item['productoNombre'] ?? 'Sin nombre') as String;
                  final cantidad = (item['cantidad'] ?? 1) as int;
                  final ingreso = ((item['precioTotal'] ?? 0.0) as num).toDouble();
                  vendidos[nombre] = (vendidos[nombre] ?? 0) + cantidad;
                  ingresosPorProducto[nombre] = (ingresosPorProducto[nombre] ?? 0) + ingreso;
                }
              }

              final top5 = (vendidos.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
              final maxVentas = top5.isNotEmpty ? top5.first.value : 1;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    _RepKpiCard(label: '💰 Ventas', value: '\$${totalVentas.toStringAsFixed(2)}', color: Colors.green),
                    const SizedBox(width: 10),
                    _RepKpiCard(label: '📦 Pedidos', value: '$totalPedidos', color: Colors.blue),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _RepKpiCard(label: '🎯 Ticket promedio', value: '\$${ticketPromedio.toStringAsFixed(2)}', color: Colors.orange),
                    const SizedBox(width: 10),
                    _RepKpiCard(label: '🛵 Domicilios', value: '$pedidosDomicilio', color: Colors.indigo),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _RepKpiCard(label: '🍽️ Mesas', value: '$pedidosMesa', color: Colors.teal),
                    const SizedBox(width: 10),
                    _RepKpiCard(label: '✅ Completados', value: '$totalPedidos', color: Colors.purple),
                  ]),
                  const SizedBox(height: 20),
                  if (top5.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Text('🏆', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text('Productos más vendidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 16),
                        ...top5.asMap().entries.map((e) {
                          final idx = e.key;
                          final nombre = e.value.key;
                          final cantidad = e.value.value;
                          final ingreso = ingresosPorProducto[nombre] ?? 0;
                          final pct = cantidad / maxVentas;
                          final medallaColor = idx == 0 ? Colors.amber : idx == 1 ? Colors.grey : idx == 2 ? Colors.brown.shade300 : Colors.purple;
                          final medalla = idx == 0 ? '🥇' : idx == 1 ? '🥈' : idx == 2 ? '🥉' : '${idx + 1}°';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(medalla, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(nombre,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text('$cantidad uds', style: TextStyle(color: medallaColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Text('\$${ingreso.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                              ]),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct, minHeight: 8,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(medallaColor),
                                ),
                              ),
                            ]),
                          );
                        }),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (totalPedidos > 0)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Text('📊', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('Distribución de pedidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 16),
                          _RepBarraDistribucion(label: '🍽️ Mesa', cantidad: pedidosMesa, total: totalPedidos, color: Colors.teal),
                          const SizedBox(height: 10),
                          _RepBarraDistribucion(label: '🛵 Domicilio', cantidad: pedidosDomicilio, total: totalPedidos, color: Colors.indigo),
                        ]),
                      ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Text('📊', style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 12),
                          Text('Sin datos para este período',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          Text('Los reportes aparecen cuando hay pedidos entregados',
                            style: TextStyle(color: Colors.grey.shade400), textAlign: TextAlign.center),
                        ]),
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
}

class _RepPeriodoBtn extends StatelessWidget {
  final String label, val, actual;
  final void Function(String) onChange;
  const _RepPeriodoBtn({required this.label, required this.val, required this.actual, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final sel = actual == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.purple : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : Colors.grey.shade700,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
      ),
    );
  }
}

class _RepKpiCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RepKpiCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

class _RepBarraDistribucion extends StatelessWidget {
  final String label;
  final int cantidad, total;
  final Color color;
  const _RepBarraDistribucion({required this.label, required this.cantidad, required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? cantidad / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text('$cantidad (${(pct * 100).toStringAsFixed(0)}%)',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 10,
          backgroundColor: Colors.grey.shade100,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}
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

  static const _periodos = [
    ('hoy',    'Hoy'),
    ('ayer',   'Ayer'),
    ('semana', '7 días'),
    ('mes',    'Este mes'),
  ];

  DateTime get _desde {
    final now = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(now.year, now.month, now.day);
      case 'ayer':   return DateTime(now.year, now.month, now.day - 1);
      case 'semana': return now.subtract(const Duration(days: 7));
      case 'mes':    return DateTime(now.year, now.month, 1);
      default:       return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _hasta {
    if (_periodo == 'ayer') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Selector de período
      Container(
        color: Colors.purple.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Icon(Icons.date_range, color: Colors.purple, size: 18),
            const SizedBox(width: 8),
            const Text('Período:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
            ..._periodos.map((p) {
              final (val, label) = p;
              final sel = _periodo == val;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _periodo = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
            }),
          ]),
        ),
      ),

      // Cuerpo con datos
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pedidos')
              .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_desde))
              .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(_hasta))
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.purple));
            }
            final docs = snap.data?.docs ?? [];
            final todos = docs.map((d) =>
                PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();
            final entregados = todos.where((p) => p.estado == 'Entregado').toList();
            final cancelados = todos.where((p) => p.estado == 'Cancelado').length;
            final activos    = todos.where((p) =>
                !['Entregado','Cancelado'].contains(p.estado)).length;

            if (todos.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📊', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text('Sin datos para este período',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Los reportes aparecen cuando hay pedidos',
                    style: TextStyle(color: Colors.grey.shade400)),
              ]));
            }

            final totalVentas    = entregados.fold(0.0, (s, p) => s + p.total);
            final ticketPromedio = entregados.isNotEmpty ? totalVentas / entregados.length : 0.0;
            final pedidosMesa    = entregados.where((p) => p.tipoPedido == 'mesa').length;
            final pedidosDom     = entregados.where((p) => p.tipoPedido == 'domicilio').length;

            // Productos más vendidos
            final Map<String, int>    vendidos  = {};
            final Map<String, double> ingresos  = {};
            for (final p in entregados) {
              for (final item in p.items) {
                final nombre   = (item['productoNombre'] ?? item['nombre'] ?? 'Sin nombre') as String;
                final cantidad = (item['cantidad'] ?? 1) as int;
                final ingreso  = ((item['precioTotal'] ?? item['precio'] ?? 0) as num).toDouble();
                vendidos[nombre] = (vendidos[nombre] ?? 0) + cantidad;
                ingresos[nombre] = (ingresos[nombre] ?? 0) + ingreso;
              }
            }
            final top5 = (vendidos.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

            // Ventas por hora (hoy/ayer) o por día (semana/mes)
            final tendencia = _calcularTendencia(entregados);

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // ── KPIs principales ──
                _TituloSeccion('📈 Resumen del período'),
                const SizedBox(height: 10),
                Row(children: [
                  _KpiCard('💰 Ventas', '\$${totalVentas.toStringAsFixed(2)}', Colors.green),
                  const SizedBox(width: 10),
                  _KpiCard('📦 Pedidos', '${entregados.length}', Colors.blue),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _KpiCard('🎯 Ticket prom.', '\$${ticketPromedio.toStringAsFixed(2)}', Colors.orange),
                  const SizedBox(width: 10),
                  _KpiCard('🔄 Activos ahora', '$activos', Colors.purple),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _KpiCard('🍽️ Mesas', '$pedidosMesa', Colors.teal),
                  const SizedBox(width: 10),
                  _KpiCard('❌ Cancelados', '$cancelados', Colors.red),
                ]),

                const SizedBox(height: 20),

                // ── Gráfica de tendencia ──
                if (tendencia.isNotEmpty) ...[
                  _TituloSeccion(
                    _periodo == 'hoy' || _periodo == 'ayer'
                        ? '⏱️ Ventas por hora'
                        : '📅 Ventas por día'),
                  const SizedBox(height: 10),
                  _GraficaTendencia(datos: tendencia, periodo: _periodo),
                  const SizedBox(height: 20),
                ],

                // ── Top productos ──
                if (top5.isNotEmpty) ...[
                  _TituloSeccion('🏆 Productos más vendidos'),
                  const SizedBox(height: 10),
                  _TopProductos(top5: top5, ingresos: ingresos),
                  const SizedBox(height: 20),
                ],

                // ── Distribución mesa vs domicilio ──
                if (entregados.isNotEmpty) ...[
                  _TituloSeccion('📊 Canal de pedidos'),
                  const SizedBox(height: 10),
                  _Distribucion(
                    pedidosMesa: pedidosMesa,
                    pedidosDom: pedidosDom,
                    total: entregados.length,
                    ventasMesa: entregados.where((p) => p.tipoPedido == 'mesa')
                        .fold(0.0, (s, p) => s + p.total),
                    ventasDom: entregados.where((p) => p.tipoPedido == 'domicilio')
                        .fold(0.0, (s, p) => s + p.total),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Horario pico ──
                if (entregados.length >= 3) ...[
                  _TituloSeccion('🕐 Hora pico'),
                  const SizedBox(height: 10),
                  _HoraPico(pedidos: entregados),
                  const SizedBox(height: 20),
                ],
              ],
            );
          },
        ),
      ),
    ]);
  }

  List<_PuntoDato> _calcularTendencia(List<PedidoModel> pedidos) {
    if (pedidos.isEmpty) return [];
    if (_periodo == 'hoy' || _periodo == 'ayer') {
      // Agrupar por hora (0-23)
      final Map<int, double> porHora = {};
      for (final p in pedidos) {
        final h = p.fecha.hour;
        porHora[h] = (porHora[h] ?? 0) + p.total;
      }
      if (porHora.isEmpty) return [];
      final minH = porHora.keys.reduce((a, b) => a < b ? a : b);
      final maxH = porHora.keys.reduce((a, b) => a > b ? a : b);
      return List.generate(maxH - minH + 1, (i) {
        final h = minH + i;
        return _PuntoDato('${h}h', porHora[h] ?? 0);
      });
    } else {
      // Agrupar por día
      final Map<String, double> porDia = {};
      for (final p in pedidos) {
        final key = '${p.fecha.day.toString().padLeft(2,'0')}/${p.fecha.month.toString().padLeft(2,'0')}';
        porDia[key] = (porDia[key] ?? 0) + p.total;
      }
      final dias = porDia.keys.toList()..sort();
      return dias.map((d) => _PuntoDato(d, porDia[d]!)).toList();
    }
  }
}

class _PuntoDato { final String label; final double valor;
  const _PuntoDato(this.label, this.valor); }

// ── Título de sección ─────────────────────────────────────────
class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);
  @override
  Widget build(BuildContext context) => Text(texto,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
}

// ── KPI card ──────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label, value; final Color color;
  const _KpiCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

// ── Gráfica de tendencia (barras custom sin librería) ─────────
class _GraficaTendencia extends StatelessWidget {
  final List<_PuntoDato> datos;
  final String periodo;
  const _GraficaTendencia({required this.datos, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final maxVal = datos.map((d) => d.valor).reduce((a, b) => a > b ? a : b);
    final totalVentas = datos.fold(0.0, (s, d) => s + d.valor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Total: \$${totalVentas.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green))),
          Text('${datos.length} ${periodo == 'hoy' || periodo == 'ayer' ? 'horas' : 'días'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: datos.map((d) {
              final pct = maxVal > 0 ? d.valor / maxVal : 0.0;
              final esMax = d.valor == maxVal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (esMax)
                      Text('\$${d.valor.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 8, color: Colors.purple,
                              fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: (pct * 90).clamp(4.0, 90.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: esMax
                              ? [Colors.purple, Colors.purple.shade300]
                              : [Colors.purple.shade200, Colors.purple.shade100],
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(d.label, style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Top productos ─────────────────────────────────────────────
class _TopProductos extends StatelessWidget {
  final List<MapEntry<String, int>> top5;
  final Map<String, double> ingresos;
  const _TopProductos({required this.top5, required this.ingresos});

  @override
  Widget build(BuildContext context) {
    final maxVal = top5.isNotEmpty ? top5.first.value : 1;
    const medallas = ['🥇','🥈','🥉','4°','5°'];
    final colores  = [Colors.amber, Colors.blueGrey, Colors.brown.shade300, Colors.purple, Colors.teal];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(children: top5.asMap().entries.map((e) {
        final i = e.key;
        final nombre   = e.value.key;
        final cantidad = e.value.value;
        final ingreso  = ingresos[nombre] ?? 0;
        final pct      = cantidad / maxVal;
        final color    = colores[i];

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(medallas[i], style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$cantidad uds', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Text('\$${ingreso.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 7,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Distribución mesa vs domicilio ────────────────────────────
class _Distribucion extends StatelessWidget {
  final int pedidosMesa, pedidosDom, total;
  final double ventasMesa, ventasDom;
  const _Distribucion({required this.pedidosMesa, required this.pedidosDom,
      required this.total, required this.ventasMesa, required this.ventasDom});

  @override
  Widget build(BuildContext context) {
    final pctMesa = total > 0 ? pedidosMesa / total : 0.0;
    final pctDom  = total > 0 ? pedidosDom  / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        // Barra visual dividida
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            Expanded(flex: (pctMesa * 100).round(),
              child: Container(height: 16, color: Colors.teal)),
            Expanded(flex: (pctDom * 100).round().clamp(1, 100),
              child: Container(height: 16, color: Colors.indigo)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _DistItem('🍽️ Mesa', pedidosMesa, pctMesa, '\$${ventasMesa.toStringAsFixed(2)}', Colors.teal),
          Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
          _DistItem('🛵 Domicilio', pedidosDom, pctDom, '\$${ventasDom.toStringAsFixed(2)}', Colors.indigo),
        ]),
      ]),
    );
  }
}

class _DistItem extends StatelessWidget {
  final String label, ventas; final int count; final double pct; final Color color;
  const _DistItem(this.label, this.count, this.pct, this.ventas, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      const SizedBox(height: 4),
      Text('$count pedidos · ${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      Text(ventas, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

// ── Hora pico ─────────────────────────────────────────────────
class _HoraPico extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _HoraPico({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final Map<int, int> porHora = {};
    for (final p in pedidos) {
      final h = p.fecha.hour;
      porHora[h] = (porHora[h] ?? 0) + 1;
    }
    if (porHora.isEmpty) return const SizedBox.shrink();
    final pico = porHora.entries.reduce((a, b) => a.value > b.value ? a : b);
    final totalHoras = porHora.length;
    // Top 3 horas
    final top3 = (porHora.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Text('🕐', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hora pico: ${pico.key}:00 – ${pico.key + 1}:00',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${pico.value} pedidos · $totalHoras horas activas',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Top 3 horas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        ...top3.asMap().entries.map((e) {
          final medallas = ['🥇','🥈','🥉'];
          final h = e.value.key;
          final n = e.value.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Text(medallas[e.key], style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text('${h.toString().padLeft(2,'0')}:00 – ${(h+1).toString().padLeft(2,'0')}:00',
                  style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('$n pedidos',
                    style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
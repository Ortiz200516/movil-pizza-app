import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';
import 'exportar_service.dart';

const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);
const _kMor   = Color(0xFFA78BFA);
const _kAmb   = Color(0xFFFFD700);

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  String _periodo = 'hoy';
  static const _periodos = [
    ('hoy',    'Hoy'),
    ('semana', '7 días'),
    ('mes',    'Mes'),
  ];

  DateTime get _desde {
    final now = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(now.year, now.month, now.day);
      case 'semana': return now.subtract(const Duration(days: 7));
      case 'mes':    return DateTime(now.year, now.month, 1);
      default:       return DateTime(now.year, now.month, now.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_desde))
          .snapshots(),
      builder: (_, snap) {
        final pedidos = snap.hasData
            ? snap.data!.docs.map((d) =>
                PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                .toList()
            : <PedidoModel>[];

        final entregados = pedidos.where((p) => p.estado == 'Entregado').toList();
        final cancelados = pedidos.where((p) => p.estado == 'Cancelado').length;
        final enProceso  = pedidos.where((p) =>
            p.estado != 'Entregado' && p.estado != 'Cancelado').length;
        final ventas     = entregados.fold(0.0, (s, p) => s + p.total);
        final ticket     = entregados.isEmpty ? 0.0 : ventas / entregados.length;

        // ── Ventas por día (para semana/mes) ───────────────────────────────
        final Map<String, double> ventasDia = {};
        for (final p in entregados) {
          final key = '${p.fecha.day}/${p.fecha.month}';
          ventasDia[key] = (ventasDia[key] ?? 0) + p.total;
        }

        // ── Ingresos por método de pago ────────────────────────────────────
        final ingEfectivo = entregados
            .where((p) => (p.metodoPago ?? '') == 'efectivo')
            .fold(0.0, (s, p) => s + p.total);
        final ingTarjeta = entregados
            .where((p) => (p.metodoPago ?? '') == 'tarjeta')
            .fold(0.0, (s, p) => s + p.total);
        final ingTransfer = entregados
            .where((p) => (p.metodoPago ?? '') == 'transferencia')
            .fold(0.0, (s, p) => s + p.total);

        // ── Productos más vendidos ─────────────────────────────────────────
        final Map<String, Map<String, dynamic>> prodStats = {};
        for (final p in entregados) {
          for (final item in p.items) {
            final nombre = item['nombre'] as String? ?? '?';
            final cant   = (item['cantidad'] as int?) ?? 1;
            final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
            if (!prodStats.containsKey(nombre)) {
              prodStats[nombre] = {'cant': 0, 'ingresos': 0.0};
            }
            prodStats[nombre]!['cant']     = prodStats[nombre]!['cant']     + cant;
            prodStats[nombre]!['ingresos'] = prodStats[nombre]!['ingresos'] + (cant * precio);
          }
        }
        final topProd = prodStats.entries.toList()
          ..sort((a, b) => (b.value['cant'] as int).compareTo(a.value['cant'] as int));

        return Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            color: _kBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              const Text('📋 Reportes', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 15)),
              const Spacer(),
              // Exportar
              PopupMenuButton<String>(
                icon: const Icon(Icons.download_outlined,
                    color: Colors.white54, size: 20),
                color: _kCard,
                tooltip: 'Exportar',
                onSelected: (v) async {
                  final ahora = DateTime.now();
                  if (v == 'pedidos') {
                    await ExportarService.exportarPedidosCSV(
                        desde: _desde, hasta: ahora);
                  } else {
                    await ExportarService.exportarResumenCSV(
                        desde: _desde, hasta: ahora);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('📥 Descarga iniciada'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating));
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'pedidos',
                      child: Row(children: [
                        Icon(Icons.receipt_long, size: 16, color: Colors.white54),
                        SizedBox(width: 8),
                        Text('Pedidos CSV', style: TextStyle(color: Colors.white)),
                      ])),
                  const PopupMenuItem(value: 'resumen',
                      child: Row(children: [
                        Icon(Icons.bar_chart, size: 16, color: Colors.white54),
                        SizedBox(width: 8),
                        Text('Resumen CSV', style: TextStyle(color: Colors.white)),
                      ])),
                ],
              ),
              // Períodos
              ..._periodos.map((p) {
                final sel = _periodo == p.$1;
                return GestureDetector(
                  onTap: () => setState(() => _periodo = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? _kNar.withValues(alpha: 0.18) : _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? _kNar : Colors.white12,
                          width: sel ? 1.5 : 1)),
                    child: Text(p.$2, style: TextStyle(
                        color: sel ? _kNar : Colors.white38,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11)),
                  ),
                );
              }),
            ]),
          ),

          Expanded(
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator(color: _kNar))
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      // ── KPIs ───────────────────────────────────────────────
                      GridView.count(
                        crossAxisCount: 2, shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10, mainAxisSpacing: 10,
                        childAspectRatio: 1.65,
                        children: [
                          _KpiR('💰', 'Ventas',
                              '\$${ventas.toStringAsFixed(2)}', _kVerde),
                          _KpiR('📦', 'Entregados',
                              '${entregados.length}', _kAzul,
                              sub: 'pedidos'),
                          _KpiR('🎯', 'Ticket prom.',
                              '\$${ticket.toStringAsFixed(2)}', _kNar),
                          _KpiR('❌', 'Cancelados',
                              '$cancelados', Colors.redAccent,
                              sub: '$enProceso en proceso'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Ingresos por método ────────────────────────────────
                      _SecT('Ingresos por método de pago'),
                      _IngresoMetodos(
                          efectivo: ingEfectivo,
                          tarjeta: ingTarjeta,
                          transferencia: ingTransfer,
                          total: ventas),
                      const SizedBox(height: 16),

                      // ── Gráfica ventas por día ─────────────────────────────
                      if (_periodo != 'hoy' && ventasDia.isNotEmpty) ...[
                        _SecT('Ventas por día (\$)'),
                        _BarChartDia(data: ventasDia),
                        const SizedBox(height: 16),
                      ],

                      // ── Top productos ──────────────────────────────────────
                      if (topProd.isNotEmpty) ...[
                        _SecT('Productos más vendidos'),
                        _TablaProductos(productos: topProd.take(10).toList()),
                        const SizedBox(height: 16),
                      ],

                      // ── Pedidos en proceso ─────────────────────────────────
                      if (enProceso > 0) ...[
                        _SecT('Pedidos en proceso ($enProceso)'),
                        _PedidosEnProceso(pedidos: pedidos
                            .where((p) => p.estado != 'Entregado'
                                && p.estado != 'Cancelado')
                            .take(5).toList()),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ]);
      },
    );
  }
}

// ── Ingresos por método con barras ────────────────────────────────────────────
class _IngresoMetodos extends StatelessWidget {
  final double efectivo, tarjeta, transferencia, total;
  const _IngresoMetodos({required this.efectivo, required this.tarjeta,
      required this.transferencia, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('💵 Efectivo',      efectivo,      _kVerde),
      ('💳 Tarjeta',       tarjeta,       _kAzul),
      ('📱 Transferencia', transferencia, _kAmb),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.map((item) {
          final pct = total > 0 ? item.$2 / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 110,
                  child: Text(item.$1, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12))),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(item.$3),
                ),
              )),
              const SizedBox(width: 10),
              SizedBox(width: 60,
                  child: Text('\$${item.$2.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: item.$3,
                          fontWeight: FontWeight.w700, fontSize: 12))),
              SizedBox(width: 36,
                  child: Text('${(pct * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 10))),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Barras de ventas por día ──────────────────────────────────────────────────
class _BarChartDia extends StatelessWidget {
  final Map<String, double> data;
  const _BarChartDia({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxV    = data.values.isEmpty ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Expanded(child: LayoutBuilder(builder: (_, box) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: entries.map((e) {
              final pct  = maxV > 0 ? e.value / maxV : 0.0;
              final barH = (pct * (box.maxHeight - 20)).clamp(3.0, box.maxHeight - 20);
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.value > 0)
                      Text('\$${e.value.toInt()}',
                          style: TextStyle(
                              color: _kNar.withValues(alpha: 0.7),
                              fontSize: 7, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Container(
                      height: barH,
                      decoration: BoxDecoration(
                        color: _kNar.withValues(alpha: e.value > 0 ? 0.85 : 0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ));
            }).toList(),
          );
        })),
        const SizedBox(height: 4),
        Row(children: entries.map((e) => Expanded(
          child: Text(e.key, textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 8)),
        )).toList()),
      ]),
    );
  }
}

// ── Tabla de productos con ingresos ──────────────────────────────────────────
class _TablaProductos extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> productos;
  const _TablaProductos({required this.productos});

  @override
  Widget build(BuildContext context) {
    final maxCant = productos.isEmpty ? 1
        : productos.map((e) => e.value['cant'] as int).reduce((a, b) => a > b ? a : b);

    final colors = [_kNar, _kAzul, _kVerde, _kMor, _kAmb,
        Colors.pink, Colors.teal, Colors.orange, Colors.cyan, Colors.lime];

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(children: [
              const SizedBox(width: 30),
              const Expanded(child: Text('Producto', style: TextStyle(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w700))),
              SizedBox(width: 50, child: Text('Uds', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.w700))),
              SizedBox(width: 70, child: Text('Ingresos', textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.w700))),
            ]),
          ),
          ...productos.asMap().entries.map((entry) {
            final i     = entry.key;
            final prod  = entry.value;
            final cant  = prod.value['cant'] as int;
            final ing   = (prod.value['ingresos'] as double);
            final color = colors[i % colors.length];
            final isLast = i == productos.length - 1;
            final pct   = maxCant > 0 ? cant / maxCant : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.04))),
              ),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                  child: Center(child: Text('${i + 1}', style: TextStyle(
                      color: color, fontSize: 10,
                      fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(prod.key, style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ])),
                SizedBox(width: 50, child: Text('$cant',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.w700, fontSize: 13))),
                SizedBox(width: 70, child: Text(
                    '\$${ing.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 11))),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Pedidos en proceso ────────────────────────────────────────────────────────
class _PedidosEnProceso extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _PedidosEnProceso({required this.pedidos});

  Color _col(String e) {
    switch (e) {
      case 'Preparando': return _kNar;
      case 'Listo':      return _kAmb;
      case 'En camino':  return _kAzul;
      default:           return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Column(children: pedidos.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      final col    = _col(p.estado);
      final isLast = i == pedidos.length - 1;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(p.estado, style: TextStyle(
                color: col, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(p.clienteNombre ?? 'Cliente',
              style: const TextStyle(color: Colors.white, fontSize: 12))),
          Text('\$${p.total.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70,
                  fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
    }).toList()),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _KpiR extends StatelessWidget {
  final String emoji, titulo, valor;
  final Color color;
  final String? sub;
  const _KpiR(this.emoji, this.titulo, this.valor, this.color, {this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Expanded(child: Text(titulo, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const Spacer(),
      Text(valor, style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 20)),
      if (sub != null)
        Text(sub!, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
    ]),
  );
}

Widget _SecT(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t.toUpperCase(), style: TextStyle(
      color: Colors.white.withValues(alpha: 0.3), fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 1)),
);
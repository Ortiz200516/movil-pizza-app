import 'exportar_service.dart';
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
      builder: (context, snap) {
        final pedidos = snap.hasData
            ? snap.data!.docs
                .map((d) => PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                .toList()
            : <PedidoModel>[];

        final entregados  = pedidos.where((p) => p.estado == 'Entregado').toList();
        final cancelados  = pedidos.where((p) => p.estado == 'Cancelado').length;
        final enProceso   = pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
        final ventas      = entregados.fold(0.0, (s, p) => s + p.total);
        final ticketProm  = entregados.isEmpty ? 0.0 : ventas / entregados.length;

        return Column(children: [
          // ── Selector de periodo ──────────────────────────
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              const Text('Reportes', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined, color: Colors.white54, size: 20),
              color: const Color(0xFF1E293B),
              tooltip: 'Exportar',
              onSelected: (v) async {
                final ahora = DateTime.now();
                if (v == 'pedidos') {
                  await ExportarService.exportarPedidosCSV(desde: _desde, hasta: ahora);
                } else {
                  await ExportarService.exportarResumenCSV(desde: _desde, hasta: ahora);
                }
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📥 Descarga iniciada'),
                      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'pedidos', child: Row(children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.white54),
                  SizedBox(width: 8),
                  Text('Pedidos CSV', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'resumen', child: Row(children: [
                  Icon(Icons.bar_chart, size: 16, color: Colors.white54),
                  SizedBox(width: 8),
                  Text('Resumen CSV', style: TextStyle(color: Colors.white)),
                ])),
              ],
            ),
            ..._periodos.map((p) {
                final sel = _periodo == p.$1;
                return GestureDetector(
                  onTap: () => setState(() => _periodo = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFFF6B00).withOpacity(0.2) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? const Color(0xFFFF6B00) : Colors.white12,
                        width: sel ? 1.5 : 1),
                    ),
                    child: Text(p.$2, style: TextStyle(
                      color: sel ? const Color(0xFFFF6B00) : Colors.white38,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12)),
                  ),
                );
              }),
            ]),
          ),

          Expanded(
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [

                      // ── KPIs ─────────────────────────────
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10, mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                        children: [
                          _KpiCard('💰', 'Ventas', '\$${ventas.toStringAsFixed(2)}', const Color(0xFF4ADE80)),
                          _KpiCard('📦', 'Entregados', '${entregados.length}', const Color(0xFF38BDF8)),
                          _KpiCard('🎯', 'Ticket prom.', '\$${ticketProm.toStringAsFixed(2)}', const Color(0xFFFF6B00)),
                          _KpiCard('❌', 'Cancelados', '$cancelados', Colors.red.shade400),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // En proceso
                      if (enProceso > 0)
                        _InfoBanner('⏳ $enProceso pedidos en proceso ahora mismo', Colors.orange),

                      const SizedBox(height: 14),

                      // ── Ventas por día ────────────────────
                      if (_periodo != 'hoy')
                        _GraficaVentasDia(pedidos: entregados, periodo: _periodo),

                      const SizedBox(height: 14),

                      // ── Top productos ─────────────────────
                      _TopProductos(pedidos: entregados),
                      const SizedBox(height: 14),

                      // ── Métodos de pago ───────────────────
                      _MetodosPago(pedidos: entregados),
                      const SizedBox(height: 14),

                      // ── Tipos de pedido ───────────────────
                      _TiposPedido(pedidos: entregados),
                      const SizedBox(height: 14),

                      // ── Horas pico ────────────────────────
                      _HorasPico(pedidos: pedidos),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ]);
      },
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String icono, titulo, valor;
  final Color color;
  const _KpiCard(this.icono, this.titulo, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Text(icono, style: const TextStyle(fontSize: 20)),
        const Spacer(),
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(
            color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(titulo, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    ]),
  );
}

class _InfoBanner extends StatelessWidget {
  final String texto; final Color color;
  const _InfoBanner(this.texto, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );
}

// ── Gráfica ventas por día ────────────────────────────────────
class _GraficaVentasDia extends StatelessWidget {
  final List<PedidoModel> pedidos;
  final String periodo;
  const _GraficaVentasDia({required this.pedidos, required this.periodo});

  @override
  Widget build(BuildContext context) {
    // Agrupar ventas por día
    final Map<String, double> porDia = {};
    for (final p in pedidos) {
      final key = '${p.fecha.day.toString().padLeft(2,'0')}/'
          '${p.fecha.month.toString().padLeft(2,'0')}';
      porDia[key] = (porDia[key] ?? 0) + p.total;
    }
    if (porDia.isEmpty) return const SizedBox.shrink();

    final keys = porDia.keys.toList()..sort();
    final maxVal = porDia.values.reduce((a, b) => a > b ? a : b);

    return _SeccionCard(
      titulo: '📈 Ventas por día',
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: keys.map((k) {
            final val = porDia[k]!;
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('\$${val.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 8)),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: (120 * pct).clamp(4.0, 120.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [const Color(0xFFFF6B00), const Color(0xFFFFB800)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(k, style: const TextStyle(color: Colors.white38, fontSize: 9),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Top productos ─────────────────────────────────────────────
class _TopProductos extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _TopProductos({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> conteo = {};
    for (final p in pedidos) {
      for (final item in p.items) {
        final nombre = item['productoNombre'] ?? item['nombre'] ?? 'Desconocido';
        conteo[nombre] = (conteo[nombre] ?? 0) + ((item['cantidad'] ?? 1) as int);
      }
    }
    if (conteo.isEmpty) return const SizedBox.shrink();

    final top = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final lista = top.take(5).toList();
    final maxVal = lista.first.value;
    final medals = ['🥇', '🥈', '🥉', '4°', '5°'];

    return _SeccionCard(
      titulo: '🏆 Top 5 productos',
      child: Column(
        children: List.generate(lista.length, (i) {
          final pct = lista[i].value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 24,
                  child: Text(medals[i],
                      style: const TextStyle(fontSize: 14), textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lista[i].key, style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(
                        i == 0 ? const Color(0xFFFFB800)
                        : i == 1 ? const Color(0xFF94A3B8)
                        : const Color(0xFFFF6B00)),
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              Text('×${lista[i].value}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ]),
          );
        }),
      ),
    );
  }
}

// ── Métodos de pago ───────────────────────────────────────────
class _MetodosPago extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _MetodosPago({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) return const SizedBox.shrink();
    final Map<String, int> conteo = {};
    for (final p in pedidos) {
      final m = p.metodoPago ?? 'efectivo';
      conteo[m] = (conteo[m] ?? 0) + 1;
    }
    final total = pedidos.length;
    final colores = {
      'efectivo': Colors.green,
      'tarjeta': Colors.blue,
      'transferencia': Colors.purple,
    };
    final iconos = {'efectivo': '💵', 'tarjeta': '💳', 'transferencia': '📱'};

    return _SeccionCard(
      titulo: '💳 Métodos de pago',
      child: Column(
        children: conteo.entries.map((e) {
          final pct = e.value / total;
          final color = colores[e.key] ?? Colors.orange;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Text(iconos[e.key] ?? '💰', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_capitalizar(e.key), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Text('${e.value}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tipos de pedido ───────────────────────────────────────────
class _TiposPedido extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _TiposPedido({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) return const SizedBox.shrink();
    final mesa      = pedidos.where((p) => p.tipoPedido == 'mesa').length;
    final domicilio = pedidos.where((p) => p.tipoPedido == 'domicilio').length;
    final total     = pedidos.length;

    return _SeccionCard(
      titulo: '🍽️ Tipo de pedido',
      child: Row(children: [
        Expanded(child: _DonutSegmento(
          icono: '🍽️', label: 'Mesa',
          valor: mesa, total: total,
          color: const Color(0xFF38BDF8),
        )),
        Container(width: 1, height: 60, color: Colors.white10),
        Expanded(child: _DonutSegmento(
          icono: '🛵', label: 'Domicilio',
          valor: domicilio, total: total,
          color: const Color(0xFFFF6B00),
        )),
      ]),
    );
  }
}

class _DonutSegmento extends StatelessWidget {
  final String icono, label;
  final int valor, total;
  final Color color;
  const _DonutSegmento({required this.icono, required this.label,
      required this.valor, required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (valor / total * 100) : 0.0;
    return Column(children: [
      Text(icono, style: const TextStyle(fontSize: 28)),
      const SizedBox(height: 6),
      Text('$valor', style: TextStyle(
          color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      Text('${pct.toStringAsFixed(0)}%',
          style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
    ]);
  }
}

// ── Horas pico ────────────────────────────────────────────────
class _HorasPico extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _HorasPico({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) return const SizedBox.shrink();
    final Map<int, int> porHora = {};
    for (final p in pedidos) {
      porHora[p.fecha.hour] = (porHora[p.fecha.hour] ?? 0) + 1;
    }
    if (porHora.isEmpty) return const SizedBox.shrink();
    final maxVal = porHora.values.reduce((a, b) => a > b ? a : b);
    // Mostrar horas relevantes (9am - 11pm)
    final horas = List.generate(15, (i) => i + 9);

    return _SeccionCard(
      titulo: '⏰ Horas pico',
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: horas.map((h) {
            final val = porHora[h] ?? 0;
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            final esPico = val == maxVal && val > 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (val > 0)
                    Text('$val', style: TextStyle(
                        color: esPico ? const Color(0xFFFF6B00) : Colors.white24,
                        fontSize: 8)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: (70 * pct).clamp(2.0, 70.0),
                    decoration: BoxDecoration(
                      color: esPico
                          ? const Color(0xFFFF6B00)
                          : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${h}h', style: const TextStyle(
                      color: Colors.white24, fontSize: 8)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Sección card ──────────────────────────────────────────────
class _SeccionCard extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _SeccionCard({required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
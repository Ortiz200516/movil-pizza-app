import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0F172A);
const _kCard   = Color(0xFF1E293B);
const _kCard2  = Color(0xFF263348);
const _kNar    = Color(0xFFFF6B35);
const _kVerde  = Color(0xFF4ADE80);
const _kAzul   = Color(0xFF38BDF8);
const _kMorado = Color(0xFFA78BFA);
const _kAmbar  = Color(0xFFFFD700);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _periodo = 'hoy';
  static const _periodos = [
    ('hoy',    'Hoy'),
    ('semana', '7 días'),
    ('mes',    'Mes'),
    ('todo',   'Total'),
  ];

  DateTime get _desde {
    final now = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(now.year, now.month, now.day);
      case 'semana': return now.subtract(const Duration(days: 7));
      case 'mes':    return DateTime(now.year, now.month, 1);
      default:       return DateTime(2020, 1, 1);
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
        final activos    = pedidos.where((p) =>
            ['Pendiente','Preparando','Listo','En camino'].contains(p.estado)).length;
        final ventas     = entregados.fold(0.0, (s, p) => s + p.total);
        final ticket     = entregados.isEmpty ? 0.0 : ventas / entregados.length;

        // ── Ventas por hora del día ─────────────────────────────────────────
        final Map<int, double> ventasPorHora = {};
        for (int i = 0; i < 24; i++) ventasPorHora[i] = 0;
        for (final p in entregados) ventasPorHora[p.fecha.hour] = (ventasPorHora[p.fecha.hour] ?? 0) + p.total;

        // ── Pedidos por día (últimos 7) ────────────────────────────────────
        final Map<String, int> pedidosPorDia = {};
        final hoy = DateTime.now();
        for (int i = 6; i >= 0; i--) {
          final d = hoy.subtract(Duration(days: i));
          final key = '${d.day}/${d.month}';
          pedidosPorDia[key] = 0;
        }
        for (final p in entregados) {
          final key = '${p.fecha.day}/${p.fecha.month}';
          if (pedidosPorDia.containsKey(key)) {
            pedidosPorDia[key] = (pedidosPorDia[key] ?? 0) + 1;
          }
        }

        // ── Productos más vendidos ──────────────────────────────────────────
        final Map<String, int> prodCount = {};
        for (final p in entregados) {
          for (final item in (p.items)) {
            final nombre = item['nombre'] as String? ?? '?';
            final cant   = (item['cantidad'] as int?) ?? 1;
            prodCount[nombre] = (prodCount[nombre] ?? 0) + cant;
          }
        }
        final topProd = prodCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // ── Por tipo de pedido ──────────────────────────────────────────────
        final cntMesa      = entregados.where((p) => p.tipoPedido == 'mesa').length;
        final cntDomicilio = entregados.where((p) => p.tipoPedido == 'domicilio').length;
        final cntRetirar   = entregados.where((p) => p.tipoPedido == 'retirar').length;

        // ── Por método de pago ──────────────────────────────────────────────
        final cntEfectivo     = entregados.where((p) => (p.metodoPago ?? '') == 'efectivo').length;
        final cntTarjeta      = entregados.where((p) => (p.metodoPago ?? '') == 'tarjeta').length;
        final cntTransferencia = entregados.where((p) => (p.metodoPago ?? '') == 'transferencia').length;

        return Column(children: [
          // ── Selector período ───────────────────────────────────────────────
          Container(
            color: _kBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              const Text('📊 Dashboard', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              ..._periodos.map((p) {
                final sel = _periodo == p.$1;
                return GestureDetector(
                  onTap: () => setState(() => _periodo = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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

          Expanded(child: snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: _kNar))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [

                    // ── KPIs ─────────────────────────────────────────────────
                    _SecTitle('Resumen'),
                    GridView.count(
                      crossAxisCount: 2, shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                      childAspectRatio: 1.65,
                      children: [
                        _KpiCard('💰', 'Ventas totales',
                            '\$${ventas.toStringAsFixed(2)}', _kVerde),
                        _KpiCard('📦', 'Entregados',
                            '${entregados.length}', _kAzul,
                            sub: 'pedidos completados'),
                        _KpiCard('🎯', 'Ticket promedio',
                            '\$${ticket.toStringAsFixed(2)}', _kNar),
                        _KpiCard('🔴', 'Activos ahora',
                            '$activos', _kMorado,
                            sub: '$cancelados cancelados'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Gráfica barras: ventas por hora ──────────────────────
                    _SecTitle('Ventas por hora del día'),
                    _BarChart(
                      data: ventasPorHora,
                      color: _kNar,
                      labelPrefix: '\$',
                      showXLabels: true,
                    ),
                    const SizedBox(height: 16),

                    // ── Gráfica líneas: pedidos últimos 7 días ───────────────
                    _SecTitle('Pedidos — últimos 7 días'),
                    _LineChart(
                      data: pedidosPorDia,
                      color: _kAzul,
                    ),
                    const SizedBox(height: 16),

                    // ── Tipo de pedido ────────────────────────────────────────
                    _SecTitle('Por tipo de pedido'),
                    Row(children: [
                      _DonutSlice('🍽️ Mesa',      cntMesa,      entregados.length, Colors.purple),
                      const SizedBox(width: 8),
                      _DonutSlice('🛵 Domicilio', cntDomicilio, entregados.length, _kNar),
                      const SizedBox(width: 8),
                      _DonutSlice('🏃 Retirar',   cntRetirar,   entregados.length, Colors.teal),
                    ]),
                    const SizedBox(height: 16),

                    // ── Método de pago ────────────────────────────────────────
                    _SecTitle('Por método de pago'),
                    Row(children: [
                      _DonutSlice('💵 Efectivo',  cntEfectivo,      entregados.length, _kVerde),
                      const SizedBox(width: 8),
                      _DonutSlice('💳 Tarjeta',   cntTarjeta,       entregados.length, _kAzul),
                      const SizedBox(width: 8),
                      _DonutSlice('📱 Transfer.', cntTransferencia, entregados.length, _kAmbar),
                    ]),
                    const SizedBox(height: 16),

                    // ── Top productos ─────────────────────────────────────────
                    if (topProd.isNotEmpty) ...[
                      _SecTitle('Productos más vendidos'),
                      _TopProductos(productos: topProd.take(8).toList()),
                      const SizedBox(height: 16),
                    ],

                    // ── Pedidos recientes ─────────────────────────────────────
                    _SecTitle('Últimos pedidos'),
                    _PedidosRecientes(pedidos: pedidos.take(8).toList()),
                    const SizedBox(height: 30),
                  ],
                )),
        ]);
      },
    );
  }
}

// ── Título de sección ─────────────────────────────────────────────────────────
Widget _SecTitle(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t.toUpperCase(), style: TextStyle(
      color: Colors.white.withValues(alpha: 0.35), fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 1)),
);

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String emoji, titulo, valor;
  final Color color;
  final String? sub;
  const _KpiCard(this.emoji, this.titulo, this.valor, this.color, {this.sub});

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
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const Spacer(),
      Text(valor, style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 20)),
      if (sub != null)
        Text(sub!, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10)),
    ]),
  );
}

// ── Gráfica de barras (ventas por hora) ───────────────────────────────────────
class _BarChart extends StatelessWidget {
  final Map<int, double> data;
  final Color color;
  final String labelPrefix;
  final bool showXLabels;
  const _BarChart({required this.data, required this.color,
      this.labelPrefix = '', this.showXLabels = false});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.isEmpty ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);
    final horas = List.generate(24, (i) => i);
    // Mostrar solo horas con actividad o cada 3 horas
    final horasFiltradas = horas.where((h) =>
        (data[h] ?? 0) > 0 || h % 3 == 0).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (_, constraints) {
            final barW = (constraints.maxWidth / 24) - 2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: horas.map((h) {
                final val  = data[h] ?? 0.0;
                final pct  = maxVal > 0 ? val / maxVal : 0.0;
                final barH = pct * (constraints.maxHeight - 20);
                final hasActivity = val > 0;
                return Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasActivity)
                      Text('${labelPrefix != '' ? '' : ''}${val.toInt()}',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 7, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Container(
                      width: barW.clamp(3.0, 20.0),
                      height: barH.clamp(2.0, constraints.maxHeight - 20),
                      decoration: BoxDecoration(
                        color: hasActivity
                            ? color.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ],
                ));
              }).toList(),
            );
          }),
        ),
        const SizedBox(height: 4),
        // Etiquetas horas
        Row(
          children: horas.map((h) => Expanded(child: Text(
            h % 6 == 0 ? '${h}h' : '',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 8),
          ))).toList(),
        ),
      ]),
    );
  }
}

// ── Gráfica de línea (pedidos por día) ────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final Map<String, int> data;
  final Color color;
  const _LineChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList();
    final vals = data.values.toList();
    final maxV = vals.isEmpty ? 1 : vals.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final n = keys.length;
            if (n < 2) return Center(child: Text('Sin datos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12)));

            final points = List.generate(n, (i) {
              final x = i * w / (n - 1);
              final y = maxV > 0
                  ? h - (vals[i] / maxV * (h - 16)) - 8
                  : h / 2;
              return Offset(x, y.clamp(8.0, h.toDouble()));
            });

            return Stack(clipBehavior: Clip.none, children: [
              // Área rellena
              CustomPaint(
                size: Size(w, h),
                painter: _AreaPainter(points: points, color: color, h: h),
              ),
              // Puntos y valores
              ...List.generate(n, (i) {
                final pt = points[i];
                final val = vals[i];
                return Positioned(
                  left: pt.dx - 4,
                  top: pt.dy - 4,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle,
                      border: Border.all(color: _kCard, width: 1.5)),
                  ),
                );
              }),
            ]);
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: keys.map((k) => Text(k, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 9))).toList(),
        ),
      ]),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double h;
  const _AreaPainter({required this.points, required this.color, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()..moveTo(points.first.dx, h);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    fillPath.lineTo(points.last.dx, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.points != points || old.color != color;
}

// ── Donut slice (proporción tipo pedido) ──────────────────────────────────────
class _DonutSlice extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _DonutSlice(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        // Mini barra de progreso circular
        SizedBox(
          width: 48, height: 48,
          child: CustomPaint(painter: _ArcPainter(pct, color)),
        ),
        const SizedBox(height: 8),
        Text('$count', style: TextStyle(
            color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10), maxLines: 2),
        Text('${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 10)),
      ]),
    ));
  }
}

class _ArcPainter extends CustomPainter {
  final double pct;
  final Color color;
  const _ArcPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r    = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r - 4);
    final bg   = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final fg   = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2832, false, bg);
    canvas.drawArc(rect, -1.5708, 6.2832 * pct, false, fg);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.pct != pct;
}

// ── Top productos con barra ───────────────────────────────────────────────────
class _TopProductos extends StatelessWidget {
  final List<MapEntry<String, int>> productos;
  const _TopProductos({required this.productos});

  @override
  Widget build(BuildContext context) {
    final maxV = productos.isEmpty ? 1
        : productos.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: productos.asMap().entries.map((entry) {
          final i    = entry.key;
          final prod = entry.value;
          final pct  = maxV > 0 ? prod.value / maxV : 0.0;
          final isLast = i == productos.length - 1;
          final colors = [_kNar, _kAzul, _kVerde, _kMorado, _kAmbar,
              Colors.pink, Colors.teal, Colors.orange];
          final color = colors[i % colors.length];

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
                child: Center(child: Text('${i + 1}', style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prod.key, style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Text('${prod.value} uds', style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 13)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Pedidos recientes ─────────────────────────────────────────────────────────
class _PedidosRecientes extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _PedidosRecientes({required this.pedidos});

  Color _estadoColor(String e) {
    switch (e) {
      case 'Entregado':  return _kVerde;
      case 'Cancelado':  return Colors.red;
      case 'En camino':  return _kAzul;
      case 'Listo':      return _kAmbar;
      case 'Preparando': return _kNar;
      default:           return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text('Sin pedidos en este período',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: pedidos.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isLast = i == pedidos.length - 1;
          final color  = _estadoColor(p.estado);
          final hora   = '${p.fecha.hour}:${p.fecha.minute.toString().padLeft(2,'0')}';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.clienteNombre ?? 'Cliente',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${p.tipoPedido ?? 'mesa'} · $hora',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.estado, style: TextStyle(
                      color: color, fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Loading card ──────────────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(child: CircularProgressIndicator(
        color: _kNar, strokeWidth: 2)),
  );
}
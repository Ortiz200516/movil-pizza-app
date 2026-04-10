import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);
const _kMor   = Color(0xFFA78BFA);
const _kAmb   = Color(0xFFFFD700);
const _kRojo  = Color(0xFFEF4444);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  String _periodo = 'hoy';
  late TabController _tabs;

  static const _periodos = [
    ('hoy',    'Hoy'),
    ('semana', '7 días'),
    ('mes',    'Mes'),
    ('todo',   'Total'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

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
        final todos = snap.hasData
            ? snap.data!.docs.map((d) =>
                PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                .toList()
            : <PedidoModel>[];

        final entregados   = todos.where((p) => p.estado == 'Entregado').toList();
        final cancelados   = todos.where((p) => p.estado == 'Cancelado').toList();
        final activos      = todos.where((p) =>
            ['Pendiente','Preparando','Listo','En camino'].contains(p.estado)).toList();
        final ventas       = entregados.fold(0.0, (s, p) => s + p.total);
        final ticket       = entregados.isEmpty ? 0.0 : ventas / entregados.length;
        final tasaCancelacion = todos.isEmpty ? 0.0
            : cancelados.length / todos.length * 100;

        // ── Métricas avanzadas ────────────────────────────────────────────
        // Ventas por hora
        final Map<int, double> ventasPorHora = {for (int i=0;i<24;i++) i: 0.0};
        for (final p in entregados) {
          ventasPorHora[p.fecha.hour] = (ventasPorHora[p.fecha.hour]??0) + p.total;
        }

        // Pedidos por día (últimos 7)
        final hoy = DateTime.now();
        final Map<String, int> pedidosPorDia = {};
        final Map<String, double> ventasPorDia = {};
        for (int i = 6; i >= 0; i--) {
          final d = hoy.subtract(Duration(days: i));
          final key = '${d.day}/${d.month}';
          pedidosPorDia[key] = 0;
          ventasPorDia[key] = 0;
        }
        for (final p in entregados) {
          final key = '${p.fecha.day}/${p.fecha.month}';
          if (pedidosPorDia.containsKey(key)) {
            pedidosPorDia[key] = (pedidosPorDia[key] ?? 0) + 1;
            ventasPorDia[key]  = (ventasPorDia[key]  ?? 0) + p.total;
          }
        }

        // Productos
        final Map<String, Map<String, dynamic>> prodStats = {};
        for (final p in entregados) {
          for (final item in p.items) {
            final nombre = item['productoNombre'] ?? item['nombre'] ?? '?';
            final cant   = (item['cantidad'] as int?) ?? 1;
            final precio = ((item['precio'] ?? item['precioUnitario'] ?? 0) as num).toDouble();
            if (!prodStats.containsKey(nombre)) {
              prodStats[nombre] = {'cant': 0, 'ing': 0.0};
            }
            prodStats[nombre]!['cant'] = prodStats[nombre]!['cant'] + cant;
            prodStats[nombre]!['ing']  = prodStats[nombre]!['ing'] + cant * precio;
          }
        }
        final topProd = prodStats.entries.toList()
          ..sort((a, b) => (b.value['cant'] as int).compareTo(a.value['cant'] as int));

        // Tipos y métodos
        final cntMesa      = entregados.where((p) => p.tipoPedido == 'mesa').length;
        final cntDomicilio = entregados.where((p) => p.tipoPedido == 'domicilio').length;
        final cntRetirar   = entregados.where((p) => p.tipoPedido == 'retirar').length;
        final ingEfectivo  = entregados.where((p) => p.metodoPago == 'efectivo')
            .fold(0.0, (s,p) => s + p.total);
        final ingTarjeta   = entregados.where((p) => p.metodoPago == 'tarjeta')
            .fold(0.0, (s,p) => s + p.total);
        final ingTransfer  = entregados.where((p) => p.metodoPago == 'transferencia')
            .fold(0.0, (s,p) => s + p.total);

        // Hora pico
        final horaPico = ventasPorHora.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;
        final ventaHoraPico = ventasPorHora[horaPico] ?? 0;

        return Column(children: [
          // ── Header con período y tabs ────────────────────────────────────
          _Header(
            periodo: _periodo,
            periodos: _periodos,
            onPeriodo: (p) => setState(() => _periodo = p),
            tabs: _tabs,
          ),

          // ── Contenido por tab ────────────────────────────────────────────
          Expanded(child: snap.connectionState == ConnectionState.waiting &&
              !snap.hasData
              ? const Center(child: CircularProgressIndicator(color: _kNar))
              : TabBarView(controller: _tabs, children: [

                // ── Tab 1: Resumen ─────────────────────────────────────────
                ListView(padding: const EdgeInsets.all(14), children: [

                  // KPIs principales
                  _SecTit('📊 Resumen'),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _KpiCard('💰', 'Ventas', '\$${ventas.toStringAsFixed(2)}',
                          _kVerde, sub: '${entregados.length} pedidos'),
                      _KpiCard('🎯', 'Ticket prom.', '\$${ticket.toStringAsFixed(2)}',
                          _kNar, sub: 'por pedido'),
                      _KpiCard('🔄', 'Activos', '${activos.length}',
                          _kAzul, sub: 'en este momento'),
                      _KpiCard('📉', 'Cancelación', '${tasaCancelacion.toStringAsFixed(1)}%',
                          tasaCancelacion > 15 ? _kRojo : _kAmb,
                          sub: '${cancelados.length} pedidos'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Alerta si hay activos urgentes
                  if (activos.any((p) => DateTime.now().difference(p.fecha).inMinutes >= 20))
                    _AlertaUrgente(activos: activos),

                  // Hora pico del día
                  if (ventaHoraPico > 0)
                    _HoraPicoCard(hora: horaPico, ventas: ventaHoraPico),
                  const SizedBox(height: 16),

                  // Distribución tipo pedido
                  _SecTit('🍽️ Por tipo de pedido'),
                  _DistribucionBar(items: [
                    _DistItem('Mesa', cntMesa, entregados.length, Colors.purple),
                    _DistItem('Domicilio', cntDomicilio, entregados.length, _kNar),
                    _DistItem('Retirar', cntRetirar, entregados.length, Colors.teal),
                  ]),
                  const SizedBox(height: 16),

                  // Distribución método pago con montos
                  _SecTit('💳 Ingresos por método'),
                  _MetodosPagoCard(
                    efectivo: ingEfectivo,
                    tarjeta: ingTarjeta,
                    transferencia: ingTransfer,
                    total: ventas,
                  ),
                  const SizedBox(height: 30),
                ]),

                // ── Tab 2: Gráficas ────────────────────────────────────────
                ListView(padding: const EdgeInsets.all(14), children: [

                  _SecTit('⏰ Ventas por hora'),
                  _GraficaBarras(
                    data: ventasPorHora,
                    color: _kNar,
                    labelFn: (v) => '\$${v.toStringAsFixed(0)}',
                    esDouble: true,
                  ),
                  const SizedBox(height: 16),

                  _SecTit('📅 Pedidos por día (7 días)'),
                  _GraficaLinea(
                    dataInt: pedidosPorDia,
                    color: _kAzul,
                    label: 'pedidos',
                  ),
                  const SizedBox(height: 16),

                  _SecTit('💰 Ventas por día (\$)'),
                  _GraficaLinea(
                    dataDouble: ventasPorDia,
                    color: _kVerde,
                    label: 'ventas',
                    labelFn: (v) => '\$${v.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 30),
                ]),

                // ── Tab 3: Productos ───────────────────────────────────────
                ListView(padding: const EdgeInsets.all(14), children: [

                  _SecTit('🏆 Top productos'),
                  if (topProd.isEmpty)
                    _Empty('Sin datos de productos')
                  else
                    _TablaProductos(productos: topProd.take(10).toList()),
                  const SizedBox(height: 16),

                  _SecTit('📦 Pedidos recientes'),
                  _PedidosRecientes(pedidos: todos.take(10).toList()),
                  const SizedBox(height: 30),
                ]),
              ])),
        ]);
      },
    );
  }
}

// ── Header con período + TabBar ───────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String periodo;
  final List<(String, String)> periodos;
  final ValueChanged<String> onPeriodo;
  final TabController tabs;
  const _Header({required this.periodo, required this.periodos,
      required this.onPeriodo, required this.tabs});

  @override
  Widget build(BuildContext context) => Container(
    color: _kBg,
    child: Column(children: [
      // Selector período
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Row(children: [
          const Text('📊 Dashboard', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          ...periodos.map((p) {
            final sel = periodo == p.$1;
            return GestureDetector(
              onTap: () => onPeriodo(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      // Tabs
      TabBar(
        controller: tabs,
        labelColor: _kNar,
        unselectedLabelColor: Colors.white38,
        indicatorColor: _kNar,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: const [
          Tab(text: 'Resumen'),
          Tab(text: 'Gráficas'),
          Tab(text: 'Productos'),
        ],
      ),
    ]),
  );
}

// ── Alerta pedidos urgentes ───────────────────────────────────────────────────
class _AlertaUrgente extends StatelessWidget {
  final List<PedidoModel> activos;
  const _AlertaUrgente({required this.activos});
  @override
  Widget build(BuildContext context) {
    final urgentes = activos.where((p) =>
        DateTime.now().difference(p.fecha).inMinutes >= 20).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kRojo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRojo.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('$urgentes pedido${urgentes == 1 ? '' : 's'} urgente${urgentes == 1 ? '' : 's'}',
              style: const TextStyle(color: _kRojo, fontWeight: FontWeight.w800,
                  fontSize: 13)),
          Text('Llevan más de 20 minutos esperando',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kRojo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$urgentes', style: const TextStyle(
              color: _kRojo, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ]),
    );
  }
}

// ── Hora pico ─────────────────────────────────────────────────────────────────
class _HoraPicoCard extends StatelessWidget {
  final int hora;
  final double ventas;
  const _HoraPicoCard({required this.hora, required this.ventas});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kAmb.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kAmb.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      const Text('⚡', style: TextStyle(fontSize: 24)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Hora pico del día', style: TextStyle(
            color: Colors.white54, fontSize: 11)),
        Text('${hora.toString().padLeft(2,'0')}:00 — ${(hora+1).toString().padLeft(2,'0')}:00',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 16)),
      ])),
      Text('\$${ventas.toStringAsFixed(2)}', style: const TextStyle(
          color: _kAmb, fontWeight: FontWeight.w900, fontSize: 18)),
    ]),
  );
}

// ── Barra de distribución ─────────────────────────────────────────────────────
class _DistItem {
  final String label;
  final int count, total;
  final Color color;
  const _DistItem(this.label, this.count, this.total, this.color);
}

class _DistribucionBar extends StatelessWidget {
  final List<_DistItem> items;
  const _DistribucionBar({required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (s, i) => s + i.count);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        // Barra segmentada
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: items.map((item) {
              final pct = total > 0 ? item.count / total : 0.0;
              return Expanded(
                flex: (pct * 1000).round().clamp(0, 1000),
                child: Container(color: item.color,
                    margin: const EdgeInsets.symmetric(horizontal: 1)),
              );
            }).toList()),
          ),
        ),
        const SizedBox(height: 12),
        // Leyenda
        Row(children: items.map((item) {
          final pct = total > 0 ? item.count / total * 100 : 0.0;
          return Expanded(child: Column(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: item.color,
                    shape: BoxShape.circle)),
            const SizedBox(height: 4),
            Text(item.label, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            Text('${item.count}', style: TextStyle(
                color: item.color, fontWeight: FontWeight.w800, fontSize: 14)),
            Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
          ]));
        }).toList()),
      ]),
    );
  }
}

// ── Métodos de pago con montos ────────────────────────────────────────────────
class _MetodosPagoCard extends StatelessWidget {
  final double efectivo, tarjeta, transferencia, total;
  const _MetodosPagoCard({required this.efectivo, required this.tarjeta,
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
      child: Column(children: items.map((item) {
        final pct = total > 0 ? item.$2 / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 110, child: Text(item.$1, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12))),
            Expanded(child: Stack(children: [
              Container(height: 8, decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 8, decoration: BoxDecoration(
                    color: item.$3,
                    borderRadius: BorderRadius.circular(4))),
              ),
            ])),
            const SizedBox(width: 10),
            SizedBox(width: 65, child: Text(
                '\$${item.$2.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(color: item.$3,
                    fontWeight: FontWeight.w700, fontSize: 12))),
            SizedBox(width: 36, child: Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 10))),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Gráfica de barras ─────────────────────────────────────────────────────────
class _GraficaBarras extends StatelessWidget {
  final Map<int, double> data;
  final Color color;
  final String Function(double) labelFn;
  final bool esDouble;
  const _GraficaBarras({required this.data, required this.color,
      required this.labelFn, this.esDouble = false});

  @override
  Widget build(BuildContext context) {
    final maxV = data.values.isEmpty ? 1.0
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
          final horas = data.keys.toList()..sort();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: horas.map((h) {
              final val  = data[h] ?? 0.0;
              final pct  = maxV > 0 ? val / maxV : 0.0;
              final barH = (pct * (box.maxHeight - 18)).clamp(2.0, box.maxHeight - 18);
              final hasVal = val > 0;
              return Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.end, children: [
                if (hasVal)
                  Text(labelFn(val), style: TextStyle(
                      color: color.withValues(alpha: 0.8), fontSize: 6,
                      fontWeight: FontWeight.bold)),
                const SizedBox(height: 1),
                Container(
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: hasVal ? color : Colors.white.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
                ),
              ]));
            }).toList(),
          );
        })),
        const SizedBox(height: 4),
        Row(children: (data.keys.toList()..sort()).map<Widget>((h) => Expanded(
          child: Text(h % 6 == 0 ? '${h}h' : '',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2), fontSize: 7)),
        )).toList()),
      ]),
    );
  }
}

// ── Gráfica de línea (días) ───────────────────────────────────────────────────
class _GraficaLinea extends StatelessWidget {
  final Map<String, int>? dataInt;
  final Map<String, double>? dataDouble;
  final Color color;
  final String label;
  final String Function(double)? labelFn;
  const _GraficaLinea({this.dataInt, this.dataDouble, required this.color,
      required this.label, this.labelFn});

  @override
  Widget build(BuildContext context) {
    final keys = (dataInt ?? dataDouble)!.keys.toList();
    final vals = keys.map((k) =>
        dataInt != null ? (dataInt![k] ?? 0).toDouble()
            : (dataDouble![k] ?? 0.0)).toList();
    final maxV = vals.isEmpty ? 1.0 : vals.reduce((a, b) => a > b ? a : b);
    final total = vals.fold(0.0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Total: ', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
          Text(labelFn != null ? labelFn!(total)
              : '${total.toInt()} $label',
              style: TextStyle(color: color, fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: LayoutBuilder(builder: (_, box) {
            if (keys.length < 2) return Center(child: Text('Sin datos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3))));
            final w = box.maxWidth;
            final h = box.maxHeight;
            final n = keys.length;
            final points = List.generate(n, (i) => Offset(
              i * w / (n - 1),
              maxV > 0 ? h - (vals[i] / maxV * (h - 16)) - 8 : h / 2,
            ));
            return Stack(children: [
              CustomPaint(size: Size(w, h),
                  painter: _AreaPainter(points: points, color: color, h: h)),
              ...List.generate(n, (i) => Positioned(
                left: points[i].dx - 4, top: points[i].dy - 4,
                child: Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kCard, width: 1.5))),
              )),
            ]);
          }),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: keys.map((k) => Text(k, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 9))).toList()),
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
    final linePaint = Paint()..color = color..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()..moveTo(points.first.dx, h)
      ..lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i-1]; final p1 = points[i];
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

// ── Tabla de productos ────────────────────────────────────────────────────────
class _TablaProductos extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> productos;
  const _TablaProductos({required this.productos});

  @override
  Widget build(BuildContext context) {
    final maxCant = productos.isEmpty ? 1
        : productos.map((e) => e.value['cant'] as int)
            .reduce((a, b) => a > b ? a : b);
    final colors = [_kNar, _kAzul, _kVerde, _kMor, _kAmb,
        Colors.pink, Colors.teal, Colors.orange, Colors.cyan, Colors.lime];

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(children: [
            const SizedBox(width: 28),
            const Expanded(child: Text('Producto', style: TextStyle(
                color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700))),
            SizedBox(width: 50, child: Text('Uds', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w700))),
            SizedBox(width: 70, child: Text('Ingreso', textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w700))),
          ]),
        ),
        ...productos.asMap().entries.map((entry) {
          final i    = entry.key;
          final prod = entry.value;
          final cant = prod.value['cant'] as int;
          final ing  = prod.value['ing'] as double;
          final pct  = maxCant > 0 ? cant / maxCant : 0.0;
          final color = colors[i % colors.length];
          final isLast = i == productos.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: isLast ? null : BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04)))),
            child: Row(children: [
              Container(width: 22, height: 22,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Center(child: Text('${i+1}', style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 8),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prod.key, style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                ClipRRect(borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: pct, minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation(color))),
              ])),
              SizedBox(width: 50, child: Text('$cant',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.w800, fontSize: 13))),
              SizedBox(width: 70, child: Text('\$${ing.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white54, fontSize: 11))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Pedidos recientes ─────────────────────────────────────────────────────────
class _PedidosRecientes extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _PedidosRecientes({required this.pedidos});

  Color _col(String e) {
    switch (e) {
      case 'Entregado':  return _kVerde;
      case 'Cancelado':  return _kRojo;
      case 'En camino':  return _kAzul;
      case 'Listo':      return _kAmb;
      case 'Preparando': return _kNar;
      default:           return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) return _Empty('Sin pedidos en este período');
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: pedidos.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final color = _col(p.estado);
        final hora  = '${p.fecha.hour.toString().padLeft(2,'0')}:'
            '${p.fecha.minute.toString().padLeft(2,'0')}';
        final isLast = i == pedidos.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: isLast ? null : BoxDecoration(
            border: Border(bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.04)))),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.clienteNombre, style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${p.tipoPedido} · $hora', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${p.total.toStringAsFixed(2)}', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(p.estado, style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w700))),
            ]),
          ]),
        );
      }).toList()),
    );
  }
}

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
      color: _kCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Expanded(child: Text(titulo, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const Spacer(),
      Text(valor, style: TextStyle(color: color,
          fontWeight: FontWeight.w900, fontSize: 20)),
      if (sub != null) Text(sub!, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Widget _SecTit(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t, style: const TextStyle(color: Colors.white,
      fontWeight: FontWeight.w700, fontSize: 14)),
);

Widget _Empty(String msg) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: _kCard, borderRadius: BorderRadius.circular(14)),
  child: Center(child: Text(msg, style: TextStyle(
      color: Colors.white.withValues(alpha: 0.3), fontSize: 13))),
);
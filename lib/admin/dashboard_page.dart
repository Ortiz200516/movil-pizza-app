import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: const [
        _KpiRow(),
        SizedBox(height: 14),
        _PedidosActivos(),
        SizedBox(height: 14),
        _CocinaStatus(),
        SizedBox(height: 14),
        _RepartidoresActivos(),
        SizedBox(height: 20),
      ],
    );
  }
}

// ── KPIs en tiempo real ───────────────────────────────────────
class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const _LoadingCard(height: 90);

        final pedidos = snap.data!.docs
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        final now      = DateTime.now();
        final hoy      = pedidos.where((p) =>
            p.fecha.year == now.year &&
            p.fecha.month == now.month &&
            p.fecha.day == now.day).toList();

        final activos   = pedidos.where((p) =>
            ['Pendiente','Preparando','Listo','En camino']
                .contains(p.estado)).length;
        final entregadosHoy = hoy.where((p) => p.estado == 'Entregado').length;
        final ventasHoy = hoy.where((p) => p.estado == 'Entregado')
            .fold(0.0, (s, p) => s + p.total);

        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _KpiCard('🔴', 'Pedidos activos', '$activos',
                Colors.orange, subtitle: 'en este momento'),
            _KpiCard('📦', 'Entregados hoy', '$entregadosHoy',
                Colors.green, subtitle: 'pedidos completados'),
            _KpiCard('💰', 'Ventas hoy',
                '\$${ventasHoy.toStringAsFixed(2)}',
                const Color(0xFFFF6B00), subtitle: 'ingresos del día'),
            _KpiCard('📋', 'Total pedidos', '${pedidos.length}',
                Colors.blue, subtitle: 'histórico total'),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String emoji, titulo, valor;
  final Color color;
  final String? subtitle;
  const _KpiCard(this.emoji, this.titulo, this.valor, this.color,
      {this.subtitle});

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
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const Spacer(),
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(
            color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(titulo, style: const TextStyle(
            color: Colors.white54, fontSize: 11)),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(
              color: Colors.white24, fontSize: 10)),
      ]),
    ]),
  );
}

// ── Feed de pedidos activos ───────────────────────────────────
class _PedidosActivos extends StatelessWidget {
  const _PedidosActivos();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Pendiente','Preparando','Listo','En camino'])
          .orderBy('fecha', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const _LoadingCard(height: 120);

        final pedidos = snap.data!.docs
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        return _SeccionCard(
          titulo: '🔴 Pedidos activos',
          badge: pedidos.length,
          child: pedidos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('✅  Todo tranquilo',
                      style: TextStyle(color: Colors.white38))),
                )
              : Column(
                  children: pedidos.map((p) {
                    final color = _colorEstado(p.estado);
                    final mins  = DateTime.now().difference(p.fecha).inMinutes;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Text(p.iconoEstado,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Text(
                              p.tipoPedido == 'mesa'
                                  ? '🍽️ Mesa ${p.numeroMesa}'
                                  : '🛵 Domicilio',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6)),
                              child: Text(p.estado, style: TextStyle(
                                  color: color, fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          Text('${p.clienteNombre}  •  '
                              '${p.items.length} item(s)  •  '
                              '\$${p.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          Text('${mins}m', style: TextStyle(
                              color: mins > 30 ? Colors.red : Colors.white38,
                              fontSize: 12,
                              fontWeight: mins > 30
                                  ? FontWeight.bold : FontWeight.normal)),
                          if (mins > 30)
                            const Text('⚠️ Demorado',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 9)),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

// ── Estado cocina ─────────────────────────────────────────────
class _CocinaStatus extends StatelessWidget {
  const _CocinaStatus();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Pendiente', 'Preparando'])
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const _LoadingCard(height: 80);
        final pendientes = snap.data!.docs
            .where((d) => d['estado'] == 'Pendiente').length;
        final preparando = snap.data!.docs
            .where((d) => d['estado'] == 'Preparando').length;

        return _SeccionCard(
          titulo: '👨‍🍳 Cocina',
          child: Row(children: [
            Expanded(child: _MiniStat('⏳', 'Pendientes',
                '$pendientes', Colors.orange)),
            Container(width: 1, height: 50, color: Colors.white10),
            Expanded(child: _MiniStat('🔥', 'Preparando',
                '$preparando', Colors.blue)),
            Container(width: 1, height: 50, color: Colors.white10),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .where('estado', isEqualTo: 'Listo')
                  .snapshots(),
              builder: (_, s) => _MiniStat('✅', 'Listos',
                  '${s.data?.docs.length ?? 0}', Colors.green),
            )),
          ]),
        );
      },
    );
  }
}

// ── Repartidores activos ──────────────────────────────────────
class _RepartidoresActivos extends StatelessWidget {
  const _RepartidoresActivos();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ubicaciones')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const _LoadingCard(height: 80);

        final reps = snap.data!.docs;

        return _SeccionCard(
          titulo: '🛵 Repartidores en ruta',
          badge: reps.length,
          child: reps.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('Sin repartidores activos',
                      style: TextStyle(color: Colors.white38))),
                )
              : Column(
                  children: reps.map((doc) {
                    final d       = doc.data() as Map<String, dynamic>;
                    final ts      = d['actualizadoEn'] as dynamic;
                    String tiempo = '';
                    if (ts != null) {
                      try {
                        final dt   = (ts as dynamic).toDate() as DateTime;
                        final diff = DateTime.now().difference(dt);
                        tiempo = 'Actualizado hace ${diff.inMinutes}m';
                      } catch (_) {}
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                              child: Text('🛵',
                                  style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Repartidor activo',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          if (tiempo.isNotEmpty)
                            Text(tiempo, style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        ])),
                        Row(children: [
                          Container(width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('En línea',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 11)),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────
class _SeccionCard extends StatelessWidget {
  final String titulo; final Widget child; final int? badge;
  const _SeccionCard({required this.titulo, required this.child, this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(titulo, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$badge', style: const TextStyle(
                color: Color(0xFFFF6B00), fontSize: 11,
                fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _MiniStat extends StatelessWidget {
  final String emoji, label, valor; final Color color;
  const _MiniStat(this.emoji, this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(valor, style: TextStyle(
        color: color, fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(
        color: Colors.white38, fontSize: 11)),
  ]);
}

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14)),
    child: const Center(child: CircularProgressIndicator(
        color: Color(0xFFFF6B00), strokeWidth: 2)),
  );
}

Color _colorEstado(String estado) {
  switch (estado) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return Colors.blue;
    case 'Listo':      return Colors.green;
    case 'En camino':  return Colors.indigo;
    default:           return Colors.grey;
  }
}
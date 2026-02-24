import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/notificacion_service.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeMesero extends StatefulWidget {
  const HomeMesero({super.key});
  @override
  State<HomeMesero> createState() => _HomeMeseroState();
}

class _HomeMeseroState extends State<HomeMesero> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('🍽️ Panel Mesero'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            NotifBadgeBtn(
              uid: FirebaseAuth.instance.currentUser?.uid ?? '',
              rol: 'mesero',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.table_restaurant, size: 20), text: 'Mesas'),
              Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Pedidos'),
              Tab(icon: Icon(Icons.history, size: 20), text: 'Historial'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabMesas(),
            _TabPedidos(),
            _TabHistorial(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ TAB 1: MESAS EN GRID ═══════════════════
class _TabMesas extends StatelessWidget {
  const _TabMesas();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesas')
          .where('activa', isEqualTo: true)
          .orderBy('numero')
          .snapshots(),
      builder: (context, mesasSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pedidos')
              .where('tipoPedido', isEqualTo: 'mesa')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
              .snapshots(),
          builder: (context, pedidosSnap) {
            final mesas = mesasSnap.data?.docs ?? [];
            final pedidosDocs = pedidosSnap.data?.docs ?? [];

            // Mapa: numeroMesa → pedido
            final Map<int, Map<String, dynamic>> mesaConPedido = {};
            for (final doc in pedidosDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final num = data['numeroMesa'];
              if (num != null) mesaConPedido[num as int] = {'id': doc.id, ...data};
            }

            final libres   = mesas.where((m) { final d = m.data() as Map<String, dynamic>; return !mesaConPedido.containsKey(d['numero']); }).length;
            final ocupadas = mesaConPedido.length;
            final listas   = mesaConPedido.values.where((p) => p['estado'] == 'Listo').length;

            return Column(children: [
              // Resumen superior
              Container(
                color: Colors.teal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  _ResumenChip('Libres', libres, Colors.green),
                  const SizedBox(width: 10),
                  _ResumenChip('Ocupadas', ocupadas, Colors.orange),
                  const SizedBox(width: 10),
                  _ResumenChip('¡Listas!', listas, Colors.purple),
                ]),
              ),

              if (mesas.isEmpty)
                const Expanded(child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('🍽️', style: TextStyle(fontSize: 60)),
                    SizedBox(height: 12),
                    Text('No hay mesas activas', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ]),
                ))
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82),
                    itemCount: mesas.length,
                    itemBuilder: (_, i) {
                      final data = mesas[i].data() as Map<String, dynamic>;
                      final numero = data['numero'] as int;
                      final capacidad = data['capacidad'] as int? ?? 4;
                      final pedido = mesaConPedido[numero];
                      return _MesaGridCard(
                        numero: numero,
                        capacidad: capacidad,
                        pedido: pedido,
                        onTap: pedido != null ? () => _verDetalleMesa(context, pedido) : null,
                      );
                    },
                  ),
                ),
            ]);
          },
        );
      },
    );
  }

  void _verDetalleMesa(BuildContext context, Map<String, dynamic> pedido) {
    final estado = pedido['estado'] as String? ?? '';
    final mesa = pedido['numeroMesa'];
    final items = (pedido['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (pedido['total'] as num?)?.toDouble() ?? 0;
    final listo = estado == 'Listo';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            CircleAvatar(backgroundColor: listo ? Colors.green : Colors.orange, radius: 24,
                child: Text('$mesa', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mesa $mesa', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: listo ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(estado, style: TextStyle(fontWeight: FontWeight.bold,
                    color: listo ? Colors.green.shade800 : Colors.orange.shade800)),
              ),
            ]),
            const Spacer(),
            Text('\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
          const Divider(height: 24),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${item['cantidad']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item['productoNombre'] ?? '', style: const TextStyle(fontSize: 14))),
            ]),
          )),
          const SizedBox(height: 16),
          if (listo)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final ok = await PedidoService().actualizarEstado(pedido['id'], 'Entregado');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ Mesa $mesa marcada como entregada' : '❌ Error'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ));
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('MARCAR COMO ENTREGADO', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MesaGridCard extends StatelessWidget {
  final int numero, capacidad;
  final Map<String, dynamic>? pedido;
  final VoidCallback? onTap;
  const _MesaGridCard({required this.numero, required this.capacidad, this.pedido, this.onTap});

  @override
  Widget build(BuildContext context) {
    final libre  = pedido == null;
    final estado = pedido?['estado'] as String? ?? '';
    final listo  = estado == 'Listo';

    final Color color = libre ? Colors.green : listo ? Colors.purple : Colors.orange;
    final String emoji = libre ? '🟢' : listo ? '✅' : '🟡';
    final String label = libre ? 'Libre' : listo ? '¡Listo!' : estado;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: listo ? 3 : 1.5),
          boxShadow: [BoxShadow(
            color: listo ? Colors.purple.withOpacity(0.2) : Colors.black.withOpacity(0.05),
            blurRadius: listo ? 12 : 4, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (listo)
            const _PulseBadge(),
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('$numero', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people, size: 11, color: Colors.grey.shade400),
            const SizedBox(width: 2),
            Text('$capacidad', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ]),
        ]),
      ),
    );
  }
}

class _PulseBadge extends StatefulWidget {
  const _PulseBadge();
  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.6, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(10)),
      child: const Text('NUEVO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    ),
  );
}

class _ResumenChip extends StatelessWidget {
  final String label; final int count; final Color color;
  const _ResumenChip(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    ),
  );
}

// ═══════════════════ TAB 2: PEDIDOS LISTA ═══════════════════
class _TabPedidos extends StatelessWidget {
  const _TabPedidos();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosMesa(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        final todos      = snap.data ?? [];
        final listos     = todos.where((p) => p.estado == 'Listo').toList();
        final enCocina   = todos.where((p) => p.estado == 'Preparando').toList();
        final pendientes = todos.where((p) => p.estado == 'Pendiente').toList();

        if (todos.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🍽️', style: TextStyle(fontSize: 70)),
            SizedBox(height: 16),
            Text('No hay pedidos activos', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
          ]));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (listos.isNotEmpty) ...[
              _SeccionHeader('✅ Listos para servir', listos.length, Colors.green),
              ...listos.map((p) => _PedidoCard(pedido: p)),
              const SizedBox(height: 12),
            ],
            if (enCocina.isNotEmpty) ...[
              _SeccionHeader('👨‍🍳 En cocina', enCocina.length, Colors.blue),
              ...enCocina.map((p) => _PedidoCard(pedido: p)),
              const SizedBox(height: 12),
            ],
            if (pendientes.isNotEmpty) ...[
              _SeccionHeader('⏳ Pendientes', pendientes.length, Colors.orange),
              ...pendientes.map((p) => _PedidoCard(pedido: p)),
            ],
          ],
        );
      },
    );
  }
}

class _SeccionHeader extends StatelessWidget {
  final String title; final int count; final Color color;
  const _SeccionHeader(this.title, this.count, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

class _PedidoCard extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoCard({required this.pedido});

  Color get _color {
    switch (pedido.estado) {
      case 'Listo':      return Colors.green;
      case 'Preparando': return Colors.blue;
      default:           return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final listo = pedido.estado == 'Listo';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: listo ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(listo ? 0.8 : 0.3), width: listo ? 2 : 1)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: color, radius: 20,
              child: Text('${pedido.numeroMesa ?? "?"}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mesa ${pedido.numeroMesa ?? "Sin número"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(_tiempoTranscurrido(pedido.fecha),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(pedido.estado, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            ),
          ]),
          const Divider(height: 16),
          ...pedido.items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${i['cantidad']}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)))),
              const SizedBox(width: 8),
              Expanded(child: Text(i['productoNombre'] ?? '', style: const TextStyle(fontSize: 13))),
            ]),
          )),
          if (pedido.notasEspeciales?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade300)),
              child: Row(children: [
                const Icon(Icons.note, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(pedido.notasEspeciales!,
                    style: const TextStyle(fontSize: 12, color: Colors.black87))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Spacer(),
            if (listo)
              ElevatedButton.icon(
                onPressed: () => _marcarEntregado(context),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('ENTREGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('En cocina...', style: TextStyle(color: color, fontSize: 13)),
              ),
          ]),
        ]),
      ),
    );
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours}h';
  }

  Future<void> _marcarEntregado(BuildContext context) async {
    final ok = await PedidoService().actualizarEstado(pedido.id, 'Entregado');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Mesa ${pedido.numeroMesa} entregada' : '❌ Error'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }
}

// ═══════════════════ TAB 3: HISTORIAL DEL TURNO ═══════════════════
class _TabHistorial extends StatelessWidget {
  const _TabHistorial();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioTurno = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('tipoPedido', isEqualTo: 'mesa')
          .where('estado', isEqualTo: 'Entregado')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioTurno))
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('📋', style: TextStyle(fontSize: 70)),
            SizedBox(height: 16),
            Text('Sin entregas hoy aún', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
          ]));
        }

        final pedidos = docs.map((d) =>
            PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();
        final totalVentas = pedidos.fold(0.0, (s, p) => s + p.total);
        final mesasServidas = pedidos.map((p) => p.numeroMesa).toSet().length;

        return Column(children: [
          // Stats del turno
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              _TurnoStat('Pedidos', '${pedidos.length}', Icons.receipt_long),
              const SizedBox(width: 10),
              _TurnoStat('Mesas', '$mesasServidas', Icons.table_restaurant),
              const SizedBox(width: 10),
              _TurnoStat('Ventas', '\$${totalVentas.toStringAsFixed(0)}', Icons.attach_money),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pedidos.length,
              itemBuilder: (_, i) {
                final p = pedidos[i];
                final hora = '${p.fecha.hour.toString().padLeft(2, '0')}:${p.fecha.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100, radius: 22,
                      child: Text('${p.numeroMesa ?? "?"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mesa ${p.numeroMesa}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${p.items.length} productos · $hora',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('\$${p.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Text('✅ Entregado',
                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

class _TurnoStat extends StatelessWidget {
  final String label, value; final IconData icon;
  const _TurnoStat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    ),
  );
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/notificacion_service.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeCocinero extends StatelessWidget {
  const HomeCocinero({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: _CocinaAppBar(authService: AuthService()),
        body: const TabBarView(children: [
          _TabEnVivo(),
          _TabHistorial(),
          _TabMiTurno(),
        ]),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────
class _CocinaAppBar extends StatefulWidget implements PreferredSizeWidget {
  final AuthService authService;
  const _CocinaAppBar({required this.authService});
  @override
  Size get preferredSize => const Size.fromHeight(100);
  @override
  State<_CocinaAppBar> createState() => _CocinaAppBarState();
}

class _CocinaAppBarState extends State<_CocinaAppBar> {
  late DateTime _ahora;
  @override
  void initState() { super.initState(); _ahora = DateTime.now(); _tick(); }
  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() { _ahora = DateTime.now(); _tick(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _ahora.hour.toString().padLeft(2, '0');
    final m = _ahora.minute.toString().padLeft(2, '0');
    final s = _ahora.second.toString().padLeft(2, '0');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
          ),
          child: const Row(children: [
            Text('👨‍🍳', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('COCINA', style: TextStyle(color: Color(0xFFFF6B00),
                fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(width: 16),
        Text('$h:$m:$s', style: const TextStyle(color: Colors.white24,
            fontSize: 15, fontFamily: 'monospace', letterSpacing: 2)),
      ]),
      actions: [
        // Badge pedidos activos
        StreamBuilder<List<PedidoModel>>(
          stream: PedidoService().obtenerPedidosActivos(),
          builder: (_, snap) {
            final n = snap.data?.length ?? 0;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: n > 3 ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: n > 3
                    ? Colors.red.withOpacity(0.5) : Colors.orange.withOpacity(0.4)),
              ),
              child: Text('$n activos', style: TextStyle(
                  color: n > 3 ? Colors.red.shade300 : Colors.orange,
                  fontWeight: FontWeight.bold, fontSize: 12)),
          );},
        ),
        NotifBadgeBtn(uid: uid, rol: 'cocinero'),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
          onPressed: () async {
            await widget.authService.logout();
            if (context.mounted) Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginPage()));
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: const TabBar(
        indicatorColor: Color(0xFFFF6B00),
        indicatorWeight: 3,
        labelColor: Color(0xFFFF6B00),
        unselectedLabelColor: Colors.white38,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(icon: Icon(Icons.local_fire_department, size: 18), text: 'En vivo'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'Historial'),
          Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Mi turno'),
        ],
      ),
    );
  }
}

// ── TAB 1: EN VIVO (Kanban 3 columnas) ───────────────────────
class _TabEnVivo extends StatelessWidget {
  const _TabEnVivo();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosActivos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }
        final todos      = snap.data ?? [];
        final pendientes = todos.where((p) => p.estado == 'Pendiente').toList();
        final preparando = todos.where((p) => p.estado == 'Preparando').toList();
        final listos     = todos.where((p) => p.estado == 'Listo').toList();

        if (todos.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🍳', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('COCINA LIBRE', style: TextStyle(color: Colors.white24,
                fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6)),
            const SizedBox(height: 8),
            Text('No hay pedidos activos', style: TextStyle(
                color: Colors.white.withOpacity(0.2), fontSize: 15)),
          ]));
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Columna(titulo: 'NUEVOS', icono: '🔴', count: pendientes.length,
                color: const Color(0xFFFF6B35), pedidos: pendientes,
                emptyMsg: 'Sin pedidos nuevos', emptyIcon: '✅',
                accionEstado: 'Preparando', accionLabel: 'PREPARAR')),
            const SizedBox(width: 10),
            Expanded(child: _Columna(titulo: 'EN COCINA', icono: '🔵', count: preparando.length,
                color: const Color(0xFF38BDF8), pedidos: preparando,
                emptyMsg: 'Nada en preparación', emptyIcon: '⏳',
                accionEstado: 'Listo', accionLabel: 'LISTO ✅')),
            const SizedBox(width: 10),
            Expanded(child: _Columna(titulo: 'LISTOS', icono: '✅', count: listos.length,
                color: const Color(0xFF4ADE80), pedidos: listos,
                emptyMsg: 'Sin pedidos listos', emptyIcon: '🍽️',
                accionEstado: null, accionLabel: '')),
          ]),
        );
      },
    );
  }
}

// ── TAB 2: HISTORIAL DEL DÍA ──────────────────────────────────
class _TabHistorial extends StatelessWidget {
  const _TabHistorial();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Entregado', 'Cancelado'])
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }
        final docs = snap.data?.docs ?? [];
        final pedidos = docs
            .map((d) => PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

        if (pedidos.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📋', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            Text('Sin historial hoy', style: TextStyle(
                color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pedidos.length,
          itemBuilder: (_, i) {
            final p = pedidos[i];
            final hora = '${p.fecha.hour.toString().padLeft(2,'0')}:${p.fecha.minute.toString().padLeft(2,'0')}';
            final cancelado = p.estado == 'Cancelado';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cancelado
                    ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
              ),
              child: Row(children: [
                Text(cancelado ? '❌' : '✅', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(p.clienteNombre, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    _TimerBadge(fecha: p.fecha),
                  ]),
                  Text(
                    '${p.tipoPedido == 'mesa' ? 'Mesa ${p.numeroMesa}' : 'Domicilio'} · '
                    '${p.items.length} producto(s)',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(hora, style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('\$${p.total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: cancelado ? Colors.red.shade300 : Colors.green,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── TAB 3: MI TURNO (estadísticas) ───────────────────────────
class _TabMiTurno extends StatelessWidget {
  const _TabMiTurno();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList();

        final entregados  = todos.where((p) => p.estado == 'Entregado').toList();
        final cancelados  = todos.where((p) => p.estado == 'Cancelado').length;
        final activos     = todos.where((p) =>
            !['Entregado','Cancelado'].contains(p.estado)).length;
        final totalVentas = entregados.fold(0.0, (s, p) => s + p.total);
        final mesas       = entregados.where((p) => p.tipoPedido == 'mesa').length;
        final domicilios  = entregados.where((p) => p.tipoPedido == 'domicilio').length;

        // Productos más preparados hoy
        final Map<String, int> contador = {};
        for (final p in entregados) {
          for (final item in p.items) {
            final nombre = item['productoNombre'] ?? item['nombre'] ?? '';
            final cant   = (item['cantidad'] ?? 1) as int;
            contador[nombre] = (contador[nombre] ?? 0) + cant;
          }
        }
        final top = (contador.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

        final turnoInicio = '${inicioHoy.hour.toString().padLeft(2,'0')}:00';
        final ahora       = '${hoy.hour.toString().padLeft(2,'0')}:${hoy.minute.toString().padLeft(2,'0')}';

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Encabezado turno
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFFFF6B00).withOpacity(0.2),
                  const Color(0xFFFF6B00).withOpacity(0.05),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Text('👨‍🍳', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mi turno de hoy', style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
                  Text('$turnoInicio — $ahora', style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${todos.length} pedidos en total',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            // KPIs
            Row(children: [
              _KpiCard('✅ Completados', '${entregados.length}', Colors.green),
              const SizedBox(width: 10),
              _KpiCard('🔄 En curso', '$activos', const Color(0xFFFF6B00)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _KpiCard('❌ Cancelados', '$cancelados', Colors.red),
              const SizedBox(width: 10),
              _KpiCard('💰 Producción', '\$${totalVentas.toStringAsFixed(2)}', Colors.teal),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _KpiCard('🍽️ Mesa', '$mesas', Colors.purple),
              const SizedBox(width: 10),
              _KpiCard('🛵 Domicilio', '$domicilios', Colors.indigo),
            ]),

            const SizedBox(height: 18),

            // Top productos
            if (top.isNotEmpty) ...[
              const Text('🏆 Más preparados hoy', style: TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              ...top.asMap().entries.map((e) {
                final idx    = e.key;
                final nombre = e.value.key;
                final cant   = e.value.value;
                final max    = top.first.value;
                final pct    = cant / max;
                final medallas = ['🥇','🥈','🥉','4°','5°'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(medallas[idx], style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(nombre, style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('$cant uds', style: const TextStyle(
                          color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B00)),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value; final Color color;
  const _KpiCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ── COLUMNA KANBAN ────────────────────────────────────────────
class _Columna extends StatelessWidget {
  final String titulo, icono, emptyMsg, emptyIcon;
  final String? accionEstado;
  final String accionLabel;
  final int count;
  final Color color;
  final List<PedidoModel> pedidos;
  const _Columna({required this.titulo, required this.icono, required this.count,
      required this.color, required this.pedidos, required this.emptyMsg,
      required this.emptyIcon, required this.accionEstado, required this.accionLabel});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(icono, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(titulo, style: TextStyle(color: color,
                fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(color: color,
                fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: pedidos.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(emptyIcon, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(emptyMsg, style: TextStyle(color: Colors.white.withOpacity(0.2),
                    fontSize: 11), textAlign: TextAlign.center),
              ]))
            : ListView.builder(
                itemCount: pedidos.length,
                itemBuilder: (_, i) => _PedidoCard(
                  pedido: pedidos[i], color: color,
                  accionEstado: accionEstado, accionLabel: accionLabel),
              ),
      ),
    ],
  );
}

// ── TARJETA DE PEDIDO ─────────────────────────────────────────
class _PedidoCard extends StatelessWidget {
  final PedidoModel pedido;
  final Color color;
  final String? accionEstado;
  final String accionLabel;
  const _PedidoCard({required this.pedido, required this.color,
      required this.accionEstado, required this.accionLabel});

  String get _tiempoTranscurrido {
    final diff = DateTime.now().difference(pedido.fecha);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final esMesa = pedido.tipoPedido == 'mesa';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(esMesa ? '🍽️ Mesa ${pedido.numeroMesa}' : '🛵 Domicilio',
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Text(_tiempoTranscurrido, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        Text(pedido.clienteNombre, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // Items
        ...pedido.items.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            Container(width: 18, height: 18,
              decoration: BoxDecoration(color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Center(child: Text('${item['cantidad']}',
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 5),
            Expanded(child: Text(item['productoNombre'] ?? item['nombre'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        if (pedido.items.length > 3)
          Text('+${pedido.items.length - 3} más',
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        if (pedido.notasEspeciales?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.yellow.withOpacity(0.2)),
            ),
            child: Text('📝 ${pedido.notasEspeciales}',
                style: const TextStyle(color: Colors.yellow, fontSize: 10),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
        if (accionEstado != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => PedidoService().actualizarEstado(pedido.id, accionEstado!),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(accionLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ]),
    );
  }
}
// ── Timer badge por pedido ────────────────────────────────────
class _TimerBadge extends StatefulWidget {
  final DateTime fecha;
  const _TimerBadge({required this.fecha});
  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge> {
  late DateTime _ahora;
  @override
  void initState() { super.initState(); _ahora = DateTime.now(); _tick(); }
  void _tick() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) setState(() { _ahora = DateTime.now(); _tick(); });
    });
  }
  @override
  Widget build(BuildContext context) {
    final mins = _ahora.difference(widget.fecha).inMinutes;
    final urgente = mins >= 15;
    final color = urgente ? Colors.red : mins >= 8 ? Colors.orange : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(urgente ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        mins == 0 ? 'Ahora' : '${mins}m',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
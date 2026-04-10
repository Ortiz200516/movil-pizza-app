import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/pedido_model.dart';
import '../carrito/carrito_provider.dart';
import '../widgets/skeleton_widgets.dart';
import 'calificacion_page.dart';
import 'tracking_page.dart';

// ── Colores ───────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF0F172A);
const _kCard     = Color(0xFF1E293B);
const _kCard2    = Color(0xFF263348);
const _kNaranja  = Color(0xFFFF6B35);
const _kNaranja2 = Color(0xFFFF6B00);

Color _colorEstado(String e) {
  switch (e) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return Colors.blue;
    case 'Listo':      return Colors.teal;
    case 'En camino':  return Colors.indigo;
    case 'Entregado':  return Colors.green;
    case 'Cancelado':  return Colors.red;
    default:           return Colors.white38;
  }
}

String _emojiEstado(String e) {
  switch (e) {
    case 'Pendiente':  return '⏳';
    case 'Preparando': return '👨‍🍳';
    case 'Listo':      return '✅';
    case 'En camino':  return '🛵';
    case 'Entregado':  return '📦';
    case 'Cancelado':  return '❌';
    default:           return '📋';
  }
}

const _kPasos = ['Pendiente', 'Preparando', 'Listo', 'En camino', 'Entregado'];

// ─────────────────────────────────────────────────────────────────────────────
class MisPedidosPage extends StatefulWidget {
  const MisPedidosPage({super.key});
  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
          child: Text('Debes iniciar sesión',
              style: TextStyle(color: Colors.white)));
    }
    return Column(children: [
      Container(
        color: _kBg,
        child: TabBar(
          controller: _tab,
          indicatorColor: _kNaranja,
          indicatorWeight: 3,
          labelColor: _kNaranja,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '📦 En proceso'),
            Tab(text: '📋 Historial'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            _TabEnProceso(uid: user.uid),
            _TabHistorial(uid: user.uid),
          ],
        ),
      ),
    ]);
  }
}

// ── TAB EN PROCESO ────────────────────────────────────────────────────────────
class _TabEnProceso extends StatelessWidget {
  final String uid;
  const _TabEnProceso({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('clienteId', isEqualTo: uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: const [SkeletonPedidosList(cantidad: 3)],
          );
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .where((p) =>
                p.estado != 'Entregado' && p.estado != 'Cancelado')
            .toList();

        if (todos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🍕', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('Sin pedidos activos',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('¡Todo entregado!',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          itemCount: todos.length,
          itemBuilder: (_, i) => _TarjetaActiva(pedido: todos[i]),
        );
      },
    );
  }
}

// ── Tarjeta pedido ACTIVO con timeline ────────────────────────────────────────
class _TarjetaActiva extends StatelessWidget {
  final PedidoModel pedido;
  const _TarjetaActiva({required this.pedido});

  int get _paso {
    if (pedido.estado == 'Cancelado') return -1;
    final idx = _kPasos.indexOf(pedido.estado);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final p     = pedido;
    final color = _colorEstado(p.estado);
    final hora  = '${p.fecha.hour.toString().padLeft(2, '0')}:'
        '${p.fecha.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _DetalleSheet.show(context, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Cabecera
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Center(child: Text(_emojiEstado(p.estado),
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.estado,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                  Text(
                    p.tipoPedido == 'mesa'
                        ? '🍽️ Mesa ${p.numeroMesa} · $hora'
                        : '🛵 Domicilio · $hora',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                Text('${p.items.length} items',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ]),
          ),

          // Timeline
          if (p.estado != 'Cancelado')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _Timeline(pasoActual: _paso),
            ),

          if (p.estado == 'Cancelado')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: const Row(children: [
                  Text('❌', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Text('Pedido cancelado',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
            ),

          // Botones
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _DetalleSheet.show(context, p),
                  icon: const Icon(Icons.receipt_long_outlined,
                      size: 15, color: Colors.white38),
                  label: const Text('Ver detalle',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (p.estado == 'En camino' &&
                  p.tipoPedido == 'domicilio' &&
                  p.repartidorId != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TrackingClientePage(pedido: p))),
                    icon: const Text('🛵',
                        style: TextStyle(fontSize: 14)),
                    label: const Text('Seguir',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Timeline de pasos ─────────────────────────────────────────────────────────
class _Timeline extends StatelessWidget {
  final int pasoActual;
  const _Timeline({required this.pasoActual});

  static const _labels = [
    'Recibido', 'Cocina', 'Listo', 'En camino', 'Entregado'
  ];
  static const _iconos = ['⏳', '👨‍🍳', '✅', '🛵', '📦'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_kPasos.length * 2 - 1, (i) {
        if (i.isOdd) {
          final pasado = (i ~/ 2) < pasoActual;
          return Expanded(
            child: Container(
              height: 2,
              color: pasado
                  ? _kNaranja.withValues(alpha: 0.7)
                  : Colors.white12,
            ),
          );
        }
        final idx    = i ~/ 2;
        final activo = idx == pasoActual;
        final pasado = idx < pasoActual;
        final color  = activo || pasado ? _kNaranja : Colors.white12;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: activo ? 36 : 28,
            height: activo ? 36 : 28,
            decoration: BoxDecoration(
              color: activo
                  ? _kNaranja.withValues(alpha: 0.2)
                  : pasado
                      ? _kNaranja.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: activo ? 2 : 1),
            ),
            child: Center(
                child: Text(_iconos[idx],
                    style: TextStyle(fontSize: activo ? 16 : 12))),
          ),
          const SizedBox(height: 4),
          Text(_labels[idx],
              style: TextStyle(
                  color: activo
                      ? _kNaranja
                      : pasado
                          ? Colors.white38
                          : Colors.white12,
                  fontSize: 8,
                  fontWeight: activo
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ]);
      }),
    );
  }
}

// ── TAB HISTORIAL ─────────────────────────────────────────────────────────────
class _TabHistorial extends StatefulWidget {
  final String uid;
  const _TabHistorial({required this.uid});
  @override
  State<_TabHistorial> createState() => _TabHistorialState();
}

class _TabHistorialState extends State<_TabHistorial> {
  String _filtro   = 'Todos';
  String _busqueda = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, List<PedidoModel>> _agrupar(List<PedidoModel> lista) {
    final Map<String, List<PedidoModel>> grupos = {};
    final hoy = DateTime.now();
    for (final p in lista) {
      final diff = DateTime(hoy.year, hoy.month, hoy.day)
          .difference(
              DateTime(p.fecha.year, p.fecha.month, p.fecha.day))
          .inDays;
      String clave;
      if (diff == 0)
        clave = 'Hoy';
      else if (diff == 1)
        clave = 'Ayer';
      else if (diff < 7)
        clave = 'Esta semana';
      else if (diff < 30)
        clave = 'Este mes';
      else
        clave = 'Anterior';
      grupos.putIfAbsent(clave, () => []).add(p);
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('clienteId', isEqualTo: widget.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              sliver: SliverToBoxAdapter(
                child: SkeletonPedidosList(cantidad: 5)),
            ),
          ]);
        }

        final todosFin = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .where((p) =>
                p.estado == 'Entregado' || p.estado == 'Cancelado')
            .toList();

        var pedidos = todosFin;
        if (_filtro != 'Todos') {
          pedidos =
              pedidos.where((p) => p.estado == _filtro).toList();
        }
        if (_busqueda.isNotEmpty) {
          pedidos = pedidos
              .where((p) =>
                  p.id.toLowerCase().contains(_busqueda) ||
                  p.items.any((i) =>
                      (i['productoNombre'] ?? i['nombre'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_busqueda)))
              .toList();
        }

        final entregados =
            todosFin.where((p) => p.estado == 'Entregado');
        final cancelados =
            todosFin.where((p) => p.estado == 'Cancelado').length;
        final gastado =
            entregados.fold(0.0, (s, p) => s + p.total);

        // Gasto por mes (últimos 6)
        final Map<String, double> porMes = {};
        final ahora = DateTime.now();
        for (int i = 5; i >= 0; i--) {
          final mes = DateTime(ahora.year, ahora.month - i, 1);
          final k =
              '${mes.month.toString().padLeft(2, '0')}/${mes.year % 100}';
          porMes[k] = 0;
        }
        for (final p in entregados) {
          final k =
              '${p.fecha.month.toString().padLeft(2, '0')}/${p.fecha.year % 100}';
          if (porMes.containsKey(k)) {
            porMes[k] = (porMes[k] ?? 0) + p.total;
          }
        }

        final grupos = _agrupar(pedidos);
        final ordenGrupos = [
          'Hoy', 'Ayer', 'Esta semana', 'Este mes', 'Anterior'
        ].where((g) => grupos.containsKey(g)).toList();

        return CustomScrollView(
          slivers: [
            // Stats
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(children: [
                  _StatItem('📦', '${entregados.length}',
                      'Pedidos', Colors.green),
                  _Div(),
                  _StatItem('💰', '\$${gastado.toStringAsFixed(0)}',
                      'Gastado', _kNaranja),
                  _Div(),
                  _StatItem('❌', '$cancelados',
                      'Cancelados', Colors.red),
                ]),
              ),
            ),

            // Gráfica mensual
            if (gastado > 0)
              SliverToBoxAdapter(
                  child: _GraficaMensual(porMes: porMes)),

            // Buscador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) =>
                      setState(() => _busqueda = v.toLowerCase()),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto o código...',
                    hintStyle: const TextStyle(
                        color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white24, size: 20),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white38, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _busqueda = '');
                            })
                        : null,
                    filled: true,
                    fillColor: _kCard,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color:
                                Colors.white.withValues(alpha: 0.08))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _kNaranja, width: 1.5)),
                  ),
                ),
              ),
            ),

            // Filtros
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Entregado', 'Cancelado']
                        .map((f) {
                      final sel = _filtro == f;
                      final color = f == 'Entregado'
                          ? Colors.green
                          : f == 'Cancelado'
                              ? Colors.red
                              : _kNaranja;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _filtro = f),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : _kCard,
                            borderRadius:
                                BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? color.withValues(alpha: 0.6)
                                  : Colors.white
                                      .withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(f,
                              style: TextStyle(
                                  color: sel
                                      ? color
                                      : Colors.white38,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Lista agrupada
            if (pedidos.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📋',
                        style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    Text(
                      _busqueda.isNotEmpty
                          ? 'Sin resultados para "$_busqueda"'
                          : 'Sin historial aún',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 15),
                    ),
                    if (_busqueda.isEmpty) ...[
                      const SizedBox(height: 6),
                      const Text(
                          'Tus pedidos entregados aparecerán aquí',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12)),
                    ],
                  ],
                )),
              )
            else
              ...ordenGrupos.expand((grupo) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(children: [
                          Text(grupo,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Container(
                                  height: 1,
                                  color: Colors.white
                                      .withValues(alpha: 0.06))),
                          const SizedBox(width: 8),
                          Text('${grupos[grupo]!.length}',
                              style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 11)),
                        ]),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: _TarjetaHistorial(
                              pedido: grupos[grupo]![i]),
                        ),
                        childCount: grupos[grupo]!.length,
                      ),
                    ),
                  ]),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

// ── Gráfica de gasto mensual ──────────────────────────────────────────────────
class _GraficaMensual extends StatelessWidget {
  final Map<String, double> porMes;
  const _GraficaMensual({required this.porMes});

  String get _mesActual {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = porMes.values.isEmpty
        ? 1.0
        : porMes.values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Text('📊', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          const Text('Gasto mensual',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          Text(
              'Total: \$${porMes.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}',
              style: const TextStyle(
                  color: _kNaranja,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: porMes.entries.map((e) {
              final pct = maxVal > 0 ? e.value / maxVal : 0.0;
              final esActual = e.key == _mesActual;
              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (e.value > 0)
                        Text(
                            '\$${e.value.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: esActual
                                    ? _kNaranja
                                    : Colors.white38,
                                fontSize: 7)),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 600),
                        height: (pct * 44).clamp(2.0, 44.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: esActual
                                ? [_kNaranja2, _kNaranja]
                                : [
                                    Colors.white12,
                                    Colors.white12
                                  ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(e.key,
                          style: TextStyle(
                              color: esActual
                                  ? _kNaranja
                                  : Colors.white24,
                              fontSize: 8)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Tarjeta HISTORIAL ─────────────────────────────────────────────────────────
class _TarjetaHistorial extends StatefulWidget {
  final PedidoModel pedido;
  const _TarjetaHistorial({required this.pedido});
  @override
  State<_TarjetaHistorial> createState() => _TarjetaHistorialState();
}

class _TarjetaHistorialState extends State<_TarjetaHistorial>
    with SingleTickerProviderStateMixin {
  bool _agregando = false;
  bool _agregado  = false;
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _checkCtrl.dispose(); super.dispose(); }

  Future<void> _reordenar() async {
    if (_agregando || _agregado) return;
    setState(() => _agregando = true);
    HapticFeedback.mediumImpact();

    try {
      final carrito = Provider.of<CarritoProvider>(context, listen: false);
      for (final item in widget.pedido.items) {
        final cant = (item['cantidad'] ?? 1) as int;
        final producto = {
          'id':        item['productoId'] ?? item['id'] ?? '',
          'nombre':    item['productoNombre'] ?? item['nombre'] ?? '',
          'precio':    ((item['precioUnitario'] ?? item['precio'] ?? 0.0) as num).toDouble(),
          'categoria': item['productoCategoria'] ?? item['categoria'] ?? '',
          'icono':     item['icono'] ?? '🍕',
          'imagenUrl': item['imagenUrl'] ?? '',
        };
        for (int i = 0; i < cant; i++) {
          carrito.agregarProducto(producto);
        }
      }

      setState(() { _agregando = false; _agregado = true; });
      _checkCtrl.forward();
      HapticFeedback.heavyImpact();

      // Reset después de 2.5s
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        _checkCtrl.reverse();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _agregado = false);
      }
    } catch (_) {
      if (mounted) setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.pedido;
    final color = _colorEstado(p.estado);
    final hora  = '${p.fecha.hour.toString().padLeft(2, '0')}:'
        '${p.fecha.minute.toString().padLeft(2, '0')}';
    final dia   = '${p.fecha.day.toString().padLeft(2, '0')}/'
        '${p.fecha.month.toString().padLeft(2, '0')}';
    final esEntregado = p.estado == 'Entregado';

    return GestureDetector(
      onTap: () => _DetalleSheet.show(context, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _agregado
              ? Colors.green.withValues(alpha: 0.5)
              : color.withValues(alpha: 0.2),
              width: _agregado ? 1.5 : 1),
        ),
        child: Column(children: [

          // ── Fila principal ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(_emojiEstado(p.estado),
                    style: const TextStyle(fontSize: 21))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(child: Text(
                    p.tipoPedido == 'mesa'
                        ? '🍽️ Mesa ${p.numeroMesa}'
                        : p.tipoPedido == 'retirar'
                            ? '🏃 Retirar' : '🛵 Domicilio',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13))),
                  Text('\$${p.total.toStringAsFixed(2)}',
                      style: TextStyle(color: color,
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5)),
                    child: Text(p.estado, style: TextStyle(
                        color: color, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text('$dia  $hora', style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
                  const Spacer(),
                  Text('${p.items.length} item${p.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11)),
                ]),
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: Colors.white12, size: 18),
            ]),
          ),

          // ── Preview de productos (top 3) ───────────────────────────
          if (p.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                ...p.items.take(3).map((item) {
                  final icono = item['icono'] as String? ?? '🍕';
                  final nombre = (item['productoNombre'] ??
                      item['nombre'] ?? '') as String;
                  return Expanded(child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06))),
                    child: Row(children: [
                      Text(icono, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(nombre,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ));
                }),
                if (p.items.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('+${p.items.length - 3}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),

          // ── Botón Re-order (solo en entregados) ───────────────────
          if (esEntregado)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GestureDetector(
                onTap: _reordenar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _agregado
                        ? Colors.green.withValues(alpha: 0.15)
                        : _kNaranja.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _agregado
                          ? Colors.green.withValues(alpha: 0.4)
                          : _kNaranja.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    if (_agregando)
                      const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    else if (_agregado)
                      ScaleTransition(
                        scale: _checkScale,
                        child: const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 18),
                      )
                    else
                      const Icon(Icons.replay_rounded,
                          color: _kNaranja, size: 16),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _agregando ? 'Agregando...'
                            : _agregado ? '¡Agregado al carrito!'
                            : 'Pedir de nuevo  ·  \$${p.total.toStringAsFixed(2)}',
                        key: ValueKey(_agregado ? 'ok' : _agregando ? 'loading' : 'idle'),
                        style: TextStyle(
                          color: _agregado ? Colors.green : _kNaranja,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Bottom Sheet detalle ──────────────────────────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final PedidoModel pedido;
  const _DetalleSheet({required this.pedido});

  static void show(BuildContext context, PedidoModel p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleSheet(pedido: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p     = pedido;
    final color = _colorEstado(p.estado);
    final fecha = '${p.fecha.day.toString().padLeft(2, '0')}/'
        '${p.fecha.month.toString().padLeft(2, '0')}/'
        '${p.fecha.year}  '
        '${p.fecha.hour.toString().padLeft(2, '0')}:'
        '${p.fecha.minute.toString().padLeft(2, '0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
                child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            )),

            // Encabezado
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Center(child: Text(_emojiEstado(p.estado),
                    style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(p.estado,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const SizedBox(height: 4),
                  Text(fecha,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                Text('${p.items.length} items',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ]),

            const SizedBox(height: 6),
            Text(
                'Pedido #${p.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11)),

            // Timeline si activo
            if (p.estado != 'Cancelado' &&
                p.estado != 'Entregado') ...[
              const SizedBox(height: 16),
              _Timeline(
                  pasoActual: _kPasos.indexOf(p.estado)),
            ],

            const SizedBox(height: 16),

            // Info pedido
            _InfoRow(
                icon: p.tipoPedido == 'mesa'
                    ? Icons.table_restaurant
                    : Icons.delivery_dining,
                label: p.tipoPedido == 'mesa'
                    ? 'Mesa ${p.numeroMesa}'
                    : 'Domicilio'),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.payment,
                label: 'Pago: ${p.metodoPago}'),
            if (p.notasEspeciales?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _InfoRow(
                  icon: Icons.notes,
                  label: p.notasEspeciales!,
                  color: Colors.amber),
            ],

            const SizedBox(height: 16),

            // Items
            const Text('PRODUCTOS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),

            ...p.items.map((item) {
              final nombre =
                  item['productoNombre'] ?? item['nombre'] ?? '';
              final cant   = item['cantidad'] ?? 1;
              final precio = (item['precioTotal'] ??
                  item['precioUnitario'] ?? 0.0) as num;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _kCard2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: _kNaranja.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7)),
                    child: Center(
                        child: Text('$cant',
                            style: const TextStyle(
                                color: _kNaranja,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(nombre,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13))),
                  Text('\$${precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ]),
              );
            }),

            const Divider(color: Colors.white10, height: 20),

            // Totales
            Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
              const Text('Subtotal',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12)),
              Text('\$${p.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ]),
            if (p.impuesto > 0) ...[
              const SizedBox(height: 4),
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                const Text('Impuesto',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 12)),
                Text('\$${p.impuesto.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 6),
            Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
              const Text('TOTAL',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text('\$${p.total.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ]),

            // Código verificación
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kNaranja.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kNaranja.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Text('🔐',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                  const Text('Código de verificación',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  Text(p.codigoVerificacion,
                      style: const TextStyle(
                          color: _kNaranja,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6)),
                ])),
                IconButton(
                  icon: const Icon(Icons.copy,
                      color: Colors.white38, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: p.codigoVerificacion));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Código copiado ✅'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Tracking
            if (p.estado == 'En camino' &&
                p.tipoPedido == 'domicilio' &&
                p.repartidorId != null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TrackingClientePage(pedido: p)));
                },
                icon: const Text('🛵',
                    style: TextStyle(fontSize: 16)),
                label: const Text('Ver repartidor en mapa',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Calificar
            if (p.estado == 'Entregado') ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CalificacionPage(pedido: p)));
                },
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Calificar pedido',
                    style:
                        TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNaranja2,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              // Repetir pedido
              ElevatedButton.icon(
                onPressed: () => _repetirPedido(context, p),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text(
                  'Pedir de nuevo  ·  \$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNaranja,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _repetirPedido(BuildContext ctx, PedidoModel p) {
    try {
      final carrito = Provider.of<CarritoProvider>(ctx, listen: false);
      for (final item in p.items) {
        final cant = (item['cantidad'] ?? 1) as int;
        final producto = {
          'id':        item['productoId'] ?? item['id'] ?? '',
          'nombre':    item['productoNombre'] ?? item['nombre'] ?? '',
          'precio':    ((item['precioUnitario'] ?? item['precio'] ?? 0.0) as num).toDouble(),
          'categoria': item['productoCategoria'] ?? item['categoria'] ?? '',
          'icono':     item['icono'] ?? '🍕',
          'imagenUrl': item['imagenUrl'] ?? '',
        };
        for (int i = 0; i < cant; i++) {
          carrito.agregarProducto(producto);
        }
      }
      HapticFeedback.heavyImpact();
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          const Text('🛒', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            '${p.items.length} item${p.items.length == 1 ? '' : 's'} agregados al carrito',
            style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('No se pudo agregar el pedido'),
          behavior: SnackBarBehavior.floating));
    }
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String icono, valor, label;
  final Color color;
  const _StatItem(this.icono, this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(icono, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 3),
          Text(valor,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ]),
      );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 10));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoRow(
      {required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color ?? Colors.white38, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color ?? Colors.white54,
                    fontSize: 12))),
      ]);
}
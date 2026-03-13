import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/notificacion_service.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

// ── Constantes ────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF111827);
const _kCard   = Color(0xFF1E293B);
const _kCard2  = Color(0xFF263348);
const _kNaranja = Color(0xFFFF6B00);
const _kRojo   = Color(0xFFEF4444);
const _kAzul   = Color(0xFF38BDF8);
const _kVerde  = Color(0xFF4ADE80);

// Tiempo límite en minutos antes de alertar
const _kLimiteAmarillo = 8;
const _kLimiteRojo     = 15;

// ─────────────────────────────────────────────────────────────────────────────
class HomeCocinero extends StatefulWidget {
  const HomeCocinero({super.key});
  @override
  State<HomeCocinero> createState() => _HomeCocineroState();
}

class _HomeCocineroState extends State<HomeCocinero>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _prevCount = -1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _onNuevoPedido(int count) {
    if (_prevCount >= 0 && count > _prevCount) {
      // Vibrar al llegar pedido nuevo
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 300),
          () => HapticFeedback.heavyImpact());
    }
    _prevCount = count;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _CocinaAppBar(
        authService: AuthService(),
        tabController: _tab,
        uid: uid,
        onCount: _onNuevoPedido,
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TabEnVivo(),
          _TabHistorial(),
          _TabMiTurno(),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────
class _CocinaAppBar extends StatefulWidget implements PreferredSizeWidget {
  final AuthService authService;
  final TabController tabController;
  final String uid;
  final void Function(int) onCount;
  const _CocinaAppBar({
    required this.authService, required this.tabController,
    required this.uid, required this.onCount,
  });
  @override
  Size get preferredSize => const Size.fromHeight(104);
  @override
  State<_CocinaAppBar> createState() => _CocinaAppBarState();
}

class _CocinaAppBarState extends State<_CocinaAppBar> {
  late DateTime _ahora;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ahora = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _ahora = DateTime.now()); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = _ahora.hour.toString().padLeft(2, '0');
    final m = _ahora.minute.toString().padLeft(2, '0');
    final s = _ahora.second.toString().padLeft(2, '0');

    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      titleSpacing: 16,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kNaranja.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kNaranja.withValues(alpha: 0.4)),
          ),
          child: const Row(children: [
            Text('👨‍🍳', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('COCINA', style: TextStyle(color: _kNaranja,
                fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(width: 12),
        // Reloj en vivo con segundos
        Text('$h:$m:$s', style: const TextStyle(
            color: Colors.white24, fontSize: 13,
            fontFamily: 'monospace', letterSpacing: 1.5)),
      ]),
      actions: [
        // Badge pedidos urgentes
        StreamBuilder<List<PedidoModel>>(
          stream: PedidoService().obtenerPedidosActivos(),
          builder: (_, snap) {
            final pedidos = snap.data ?? [];
            final n = pedidos.length;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => widget.onCount(n));
            // Contar urgentes (>= límite rojo)
            final urgentes = pedidos.where((p) =>
              DateTime.now().difference(p.fecha).inMinutes >= _kLimiteRojo
            ).length;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: urgentes > 0
                    ? _kRojo.withValues(alpha: 0.2)
                    : _kNaranja.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: urgentes > 0
                    ? _kRojo.withValues(alpha: 0.5)
                    : _kNaranja.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (urgentes > 0) ...[
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                ],
                Text(urgentes > 0 ? '$urgentes urgentes' : '$n activos',
                    style: TextStyle(
                      color: urgentes > 0 ? _kRojo : _kNaranja,
                      fontWeight: FontWeight.bold, fontSize: 11)),
              ]),
            );
          },
        ),
        NotifBadgeBtn(uid: widget.uid, rol: 'cocinero'),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
          onPressed: () async {
            await widget.authService.logout();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          },
        ),
      ],
      bottom: TabBar(
        controller: widget.tabController,
        indicatorColor: _kNaranja,
        indicatorWeight: 3,
        labelColor: _kNaranja,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.local_fire_department, size: 18), text: 'En vivo'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'Historial'),
          Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Mi turno'),
        ],
      ),
    );
  }
}

// ── TAB 1: EN VIVO (Kanban) ───────────────────────────────────────────────────
class _TabEnVivo extends StatelessWidget {
  const _TabEnVivo();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosActivos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kNaranja));
        }
        final todos      = snap.data ?? [];
        final pendientes = todos.where((p) => p.estado == 'Pendiente').toList();
        final preparando = todos.where((p) => p.estado == 'Preparando').toList();
        final listos     = todos.where((p) => p.estado == 'Listo').toList();

        if (todos.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🍳', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('COCINA LIBRE', style: TextStyle(
                color: Colors.white24, fontSize: 26,
                fontWeight: FontWeight.w900, letterSpacing: 6)),
            const SizedBox(height: 8),
            Text('No hay pedidos pendientes',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 14)),
          ]));
        }

        final colW = (MediaQuery.of(context).size.width * 0.76)
            .clamp(240.0, 320.0);

        return Column(children: [
          // ── Barra indicadores ───────────────────────────────────────────────
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ColBadge(color: _kNaranja, label: 'NUEVOS',
                    count: pendientes.length),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right,
                      color: Colors.white12, size: 16),
                ),
                _ColBadge(color: _kAzul, label: 'EN COCINA',
                    count: preparando.length),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right,
                      color: Colors.white12, size: 16),
                ),
                _ColBadge(color: _kVerde, label: 'LISTOS',
                    count: listos.length),
              ],
            ),
          ),

          // ── Kanban horizontal ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              children: [
                SizedBox(width: colW,
                  child: _Columna(
                    titulo: 'NUEVOS', icono: '🔴', color: _kNaranja,
                    pedidos: pendientes, emptyMsg: 'Sin pedidos nuevos',
                    emptyIcon: '✅', accionEstado: 'Preparando',
                    accionLabel: '▶ PREPARAR',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: colW,
                  child: _Columna(
                    titulo: 'EN COCINA', icono: '🔵', color: _kAzul,
                    pedidos: preparando, emptyMsg: 'Nada en preparación',
                    emptyIcon: '⏳', accionEstado: 'Listo',
                    accionLabel: '✅ LISTO',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: colW,
                  child: _Columna(
                    titulo: 'LISTOS', icono: '✅', color: _kVerde,
                    pedidos: listos, emptyMsg: 'Sin pedidos listos',
                    emptyIcon: '🍽️', accionEstado: null,
                    accionLabel: '',
                  ),
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

class _ColBadge extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _ColBadge({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: color, fontSize: 10,
        fontWeight: FontWeight.bold)),
    const SizedBox(width: 5),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ),
  ]);
}

// ── Columna Kanban ────────────────────────────────────────────────────────────
class _Columna extends StatelessWidget {
  final String titulo, icono, emptyMsg, emptyIcon, accionLabel;
  final String? accionEstado;
  final Color color;
  final List<PedidoModel> pedidos;

  const _Columna({
    required this.titulo, required this.icono, required this.color,
    required this.pedidos, required this.emptyMsg, required this.emptyIcon,
    required this.accionEstado, required this.accionLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Cabecera columna
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(icono, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(titulo, style: TextStyle(color: color,
                  fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${pedidos.length}', style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),

      Expanded(
        child: pedidos.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emptyIcon, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(emptyMsg, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 11),
                      textAlign: TextAlign.center),
                ]))
            : ListView.builder(
                itemCount: pedidos.length,
                itemBuilder: (ctx, i) => _PedidoCard(
                  pedido: pedidos[i], color: color,
                  accionEstado: accionEstado, accionLabel: accionLabel,
                ),
              ),
      ),
    ],
  );
}

// ── Tarjeta de pedido ─────────────────────────────────────────────────────────
class _PedidoCard extends StatefulWidget {
  final PedidoModel pedido;
  final Color color;
  final String? accionEstado;
  final String accionLabel;
  const _PedidoCard({
    required this.pedido, required this.color,
    required this.accionEstado, required this.accionLabel,
  });
  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.pedido.fecha);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(widget.pedido.fecha));
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String get _tiempoStr {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    if (m >= 60) {
      return '${_elapsed.inHours}h ${m % 60}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _tiempoColor {
    final m = _elapsed.inMinutes;
    if (m >= _kLimiteRojo)    return _kRojo;
    if (m >= _kLimiteAmarillo) return Colors.amber;
    return Colors.white38;
  }

  bool get _esUrgente => _elapsed.inMinutes >= _kLimiteRojo;

  void _verDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleSheet(
          pedido: widget.pedido, color: widget.color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.pedido;
    final esMesa = p.tipoPedido == 'mesa';
    final tieneNotas = p.notasEspeciales?.isNotEmpty == true;

    return GestureDetector(
      onTap: () => _verDetalle(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _esUrgente
              ? _kRojo.withValues(alpha: 0.06)
              : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _esUrgente
                ? _kRojo.withValues(alpha: 0.5)
                : widget.color.withValues(alpha: 0.2),
            width: _esUrgente ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Cabecera con tipo + timer ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                    esMesa ? '🍽️ Mesa ${p.numeroMesa}' : '🛵 Domicilio',
                    style: TextStyle(color: widget.color,
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              // Timer en vivo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _tiempoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _tiempoColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_esUrgente)
                    const Text('🔥', style: TextStyle(fontSize: 9)),
                  if (_esUrgente) const SizedBox(width: 3),
                  Text(_tiempoStr, style: TextStyle(
                      color: _tiempoColor,
                      fontSize: 10, fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
                ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Cliente
              Row(children: [
                Expanded(child: Text(p.clienteNombre,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.chevron_right,
                    color: Colors.white12, size: 16),
              ]),
              const SizedBox(height: 6),

              // Items (máx 4 visibles)
              ...p.items.take(4).map((item) {
                final nombre = item['productoNombre'] ?? item['nombre'] ?? '';
                final cant   = item['cantidad'] ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text('$cant', style: TextStyle(
                          color: widget.color, fontSize: 9,
                          fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(nombre,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }),
              if (p.items.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('+${p.items.length - 4} más...',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10)),
                ),

              // Notas especiales destacadas
              if (tieneNotas) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('📝', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(p.notasEspeciales!,
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 10,
                            fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ],

              // Botón acción
              if (widget.accionEstado != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _procesando ? null : () async {
                      setState(() => _procesando = true);
                      HapticFeedback.mediumImpact();
                      await PedidoService().actualizarEstado(
                          p.id, widget.accionEstado!);
                      if (mounted) setState(() => _procesando = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          widget.color.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _procesando
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(widget.accionLabel,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom sheet de detalle del pedido ───────────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final PedidoModel pedido;
  final Color color;
  const _DetalleSheet({required this.pedido, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Encabezado
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Text(
                    p.tipoPedido == 'mesa'
                        ? '🍽️ Mesa ${p.numeroMesa}'
                        : '🛵 Domicilio',
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.clienteNombre,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16))),
            ]),

            const SizedBox(height: 6),
            Text('Pedido #${p.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),

            const SizedBox(height: 16),
            const Text('PRODUCTOS', style: TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 10),

            // Todos los items
            ...p.items.map((item) {
              final nombre = item['productoNombre'] ?? item['nombre'] ?? '';
              final cant   = item['cantidad'] ?? 1;
              final precio = item['precioUnitario'] ?? item['precioTotal'] ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('$cant', style: TextStyle(
                        color: color, fontWeight: FontWeight.bold,
                        fontSize: 14))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(nombre,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('\$${(precio as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ]),
              );
            }),

            // Notas
            if (p.notasEspeciales?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('📝 NOTAS ESPECIALES', style: TextStyle(
                      color: Colors.amber, fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(p.notasEspeciales!, style: const TextStyle(
                      color: Colors.amberAccent, fontSize: 14,
                      fontWeight: FontWeight.w500)),
                ]),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(color: Colors.white10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Total', style: TextStyle(
                  color: Colors.white54, fontSize: 13)),
              Text('\$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Pago', style: TextStyle(
                  color: Colors.white38, fontSize: 12)),
              Text(p.metodoPago, style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── TAB 2: HISTORIAL DEL DÍA ─────────────────────────────────────────────────
class _TabHistorial extends StatefulWidget {
  const _TabHistorial();
  @override
  State<_TabHistorial> createState() => _TabHistorialState();
}

class _TabHistorialState extends State<_TabHistorial> {
  String _filtro = 'Todos';

  @override
  Widget build(BuildContext context) {
    final inicioHoy = DateTime.now();
    final hoyInicio = DateTime(inicioHoy.year, inicioHoy.month, inicioHoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Entregado', 'Cancelado'])
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hoyInicio))
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kNaranja));
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

        var pedidos = todos;
        if (_filtro == 'Entregado') {
          pedidos = todos.where((p) => p.estado == 'Entregado').toList();
        } else if (_filtro == 'Cancelado') {
          pedidos = todos.where((p) => p.estado == 'Cancelado').toList();
        }

        final entregados = todos.where((p) => p.estado == 'Entregado').length;
        final cancelados = todos.where((p) => p.estado == 'Cancelado').length;
        final tiempos    = todos
            .where((p) => p.estado == 'Entregado')
            .map((p) => p.fecha)
            .toList();

        return Column(children: [
          // Stats rápidas
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(children: [
              _StatMini('✅', '$entregados', 'Completados', _kVerde),
              Container(width: 1, height: 28, color: Colors.white10),
              _StatMini('❌', '$cancelados', 'Cancelados', _kRojo),
              Container(width: 1, height: 28, color: Colors.white10),
              _StatMini('📋', '${todos.length}', 'Total', _kNaranja),
            ]),
          ),

          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(children: ['Todos', 'Entregado', 'Cancelado'].map((f) {
              final sel   = _filtro == f;
              final color = f == 'Entregado' ? _kVerde
                  : f == 'Cancelado' ? _kRojo : _kNaranja;
              return GestureDetector(
                onTap: () => setState(() => _filtro = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? color.withValues(alpha: 0.15)
                        : _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel
                        ? color.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(f, style: TextStyle(
                      color: sel ? color : Colors.white38,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12)),
                ),
              );
            }).toList()),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: pedidos.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📋', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 12),
                      Text('Sin historial hoy',
                          style: TextStyle(color: Colors.white38,
                              fontSize: 15)),
                    ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    itemCount: pedidos.length,
                    itemBuilder: (_, i) {
                      final p = pedidos[i];
                      final hora = '${p.fecha.hour.toString().padLeft(2,'0')}:'
                          '${p.fecha.minute.toString().padLeft(2,'0')}';
                      final cancelado = p.estado == 'Cancelado';
                      final col = cancelado ? _kRojo : _kVerde;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: col.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: Text(
                                cancelado ? '❌' : '✅',
                                style: const TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(p.clienteNombre,
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '${p.tipoPedido == 'mesa' ? '🍽️ Mesa ${p.numeroMesa}' : '🛵 Domicilio'}'
                              ' · ${p.items.length} producto(s)',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            Text(hora, style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('\$${p.total.toStringAsFixed(2)}',
                                style: TextStyle(color: col,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
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

class _StatMini extends StatelessWidget {
  final String emoji, val, label;
  final Color color;
  const _StatMini(this.emoji, this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 16)),
    const SizedBox(height: 2),
    Text(val, style: TextStyle(color: color,
        fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(
        color: Colors.white38, fontSize: 10)),
  ]));
}

// ── TAB 3: MI TURNO ───────────────────────────────────────────────────────────
class _TabMiTurno extends StatelessWidget {
  const _TabMiTurno();

  @override
  Widget build(BuildContext context) {
    final hoy       = DateTime.now();
    final hoyInicio = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(hoyInicio))
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kNaranja));
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        final entregados = todos.where((p) => p.estado == 'Entregado').toList();
        final cancelados = todos.where((p) => p.estado == 'Cancelado').length;
        final activos    = todos.where((p) =>
            !['Entregado', 'Cancelado'].contains(p.estado)).length;
        final ventas     = entregados.fold(0.0, (s, p) => s + p.total);
        final mesas      = entregados.where((p) => p.tipoPedido == 'mesa').length;
        final domicilios = entregados.where((p) => p.tipoPedido == 'domicilio').length;

        // Top productos
        final Map<String, int> contador = {};
        for (final p in entregados) {
          for (final item in p.items) {
            final n    = item['productoNombre'] ?? item['nombre'] ?? '';
            final cant = (item['cantidad'] ?? 1) as int;
            contador[n] = (contador[n] ?? 0) + cant;
          }
        }
        final top = (contador.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5).toList();

        // Productividad por hora (pedidos entregados)
        final Map<int, int> porHora = {};
        for (final p in entregados) {
          porHora[p.fecha.hour] = (porHora[p.fecha.hour] ?? 0) + 1;
        }
        final maxHora = porHora.values.isEmpty
            ? 1 : porHora.values.reduce((a, b) => a > b ? a : b);

        final ahora  = '${hoy.hour.toString().padLeft(2,'0')}:'
            '${hoy.minute.toString().padLeft(2,'0')}';

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [

            // Banner turno
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _kNaranja.withValues(alpha: 0.2),
                  _kNaranja.withValues(alpha: 0.04),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kNaranja.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Text('👨‍🍳', style: TextStyle(fontSize: 38)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Mi turno de hoy',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('00:00 – $ahora', style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 16)),
                  Text('${todos.length} pedidos recibidos',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            // KPIs en grid 2x3
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _KpiCard('✅ Completados', '${entregados.length}', _kVerde),
                _KpiCard('🔄 En curso',   '$activos',             _kNaranja),
                _KpiCard('❌ Cancelados', '$cancelados',          _kRojo),
                _KpiCard('💰 Producción', '\$${ventas.toStringAsFixed(2)}', Colors.teal),
                _KpiCard('🍽️ Mesa',       '$mesas',               Colors.purple),
                _KpiCard('🛵 Domicilio',  '$domicilios',          Colors.indigo),
              ],
            ),

            const SizedBox(height: 18),

            // Gráfica productividad por hora
            if (porHora.isNotEmpty) ...[
              const Text('📊 Pedidos por hora',
                  style: TextStyle(color: Colors.white70,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (h) {
                      final cnt = porHora[h] ?? 0;
                      if (cnt == 0 && !porHora.containsKey(h)) {
                        // Solo mostrar horas relevantes (rango ±2)
                        final keys = porHora.keys.toList()..sort();
                        if (keys.isEmpty) return const SizedBox.shrink();
                        if (h < (keys.first - 1) || h > (keys.last + 1)) {
                          return const SizedBox.shrink();
                        }
                      }
                      final pct = maxHora > 0 ? cnt / maxHora : 0.0;
                      final esActual = h == hoy.hour;
                      return Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                          if (cnt > 0)
                            Text('$cnt', style: TextStyle(
                                color: esActual ? _kNaranja : Colors.white38,
                                fontSize: 8)),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: (pct * 54).clamp(2.0, 54.0),
                            decoration: BoxDecoration(
                              color: esActual
                                  ? _kNaranja
                                  : _kNaranja.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('$h', style: const TextStyle(
                              color: Colors.white24, fontSize: 7)),
                        ]),
                      ));
                    }).where((w) => w is! SizedBox || true).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Top productos preparados
            if (top.isNotEmpty) ...[
              const Text('🏆 Más preparados hoy',
                  style: TextStyle(color: Colors.white70,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(children: top.asMap().entries.map((e) {
                  final idx    = e.key;
                  final nombre = e.value.key;
                  final cant   = e.value.value;
                  final pct    = cant / top.first.value;
                  final medal  = ['🥇','🥈','🥉','4°','5°'][idx];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text(medal, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(nombre,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('$cant uds', style: const TextStyle(
                            color: _kNaranja, fontWeight: FontWeight.bold,
                            fontSize: 12)),
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct, minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                              _kNaranja.withValues(alpha: 0.7 + 0.3 * pct)),
                        ),
                      ),
                    ]),
                  );
                }).toList()),
              ),
            ],

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      Text(label, style: const TextStyle(
          color: Colors.white38, fontSize: 10)),
      Text(value, style: TextStyle(color: color,
          fontSize: 20, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ── Timer badge (historial) ───────────────────────────────────────────────────
class _TimerBadge extends StatefulWidget {
  final DateTime fecha;
  const _TimerBadge({required this.fecha});
  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge> {
  late Timer _timer;
  late int _mins;

  @override
  void initState() {
    super.initState();
    _mins = DateTime.now().difference(widget.fecha).inMinutes;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(
          () => _mins = DateTime.now().difference(widget.fecha).inMinutes);
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = _mins >= _kLimiteRojo ? _kRojo
        : _mins >= _kLimiteAmarillo ? Colors.amber
        : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(_mins == 0 ? 'Ahora' : '${_mins}m',
          style: TextStyle(color: color,
              fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/launcher_service.dart';
import '../services/ubicacion_service.dart';
import '../services/notificacion_service.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kIndigo = Color(0xFF6366F1);
const _kVerde  = Color(0xFF4ADE80);
const _kAzul   = Color(0xFF38BDF8);
const _kNar    = Color(0xFFFF6B35);
const _kAmb    = Color(0xFFFFD700);

class HomeRepartidor extends StatefulWidget {
  const HomeRepartidor({super.key});
  @override
  State<HomeRepartidor> createState() => _HomeRepartidorState();
}

class _HomeRepartidorState extends State<HomeRepartidor>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(backgroundColor: _kBg,
          body: Center(child: Text('Sin sesión',
              style: TextStyle(color: Colors.white))));
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _RepartidorAppBar(
          uid: user!.uid, tabController: _tab),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabDisponibles(repartidorId: user!.uid),
          _TabMisEntregas(repartidorId: user!.uid),
          _TabMiDia(repartidorId: user!.uid),
        ],
      ),
    );
  }
}

// ── AppBar mejorado ───────────────────────────────────────────────────────────
class _RepartidorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String uid;
  final TabController tabController;
  const _RepartidorAppBar(
      {required this.uid, required this.tabController});

  @override
  Size get preferredSize => const Size.fromHeight(106);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      titleSpacing: 16,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kIndigo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _kIndigo.withValues(alpha: 0.4)),
          ),
          child: const Row(children: [
            Text('🛵', style: TextStyle(fontSize: 16)),
            SizedBox(width: 6),
            Text('REPARTIDOR', style: TextStyle(
                color: _kIndigo, fontWeight: FontWeight.w900,
                fontSize: 13, letterSpacing: 1.5)),
          ]),
        ),
        const SizedBox(width: 10),
        _ToggleDisponible(uid: uid),
      ]),
      actions: [
        // Badge pedidos disponibles
        StreamBuilder<List<PedidoModel>>(
          stream: PedidoService().obtenerPedidosDomicilio(),
          builder: (_, snap) {
            final disponibles = (snap.data ?? [])
                .where((p) => p.estado == 'Listo' &&
                    (p.repartidorId == null ||
                        p.repartidorId!.isEmpty))
                .length;
            if (disponibles == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kVerde.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _kVerde.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('📦', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text('$disponibles',
                    style: const TextStyle(
                        color: _kVerde,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ]),
            );
          },
        ),
        NotifBadgeBtn(uid: uid, rol: 'repartidor'),
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: Colors.white38, size: 20),
          onPressed: () async {
            await AuthService().logout();
            if (context.mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (_) => false);
            }
          },
        ),
      ],
      bottom: TabBar(
        controller: tabController,
        indicatorColor: _kIndigo,
        indicatorWeight: 3,
        labelColor: _kIndigo,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.inbox_outlined, size: 18),
              text: 'Disponibles'),
          Tab(icon: Icon(Icons.delivery_dining, size: 18),
              text: 'En camino'),
          Tab(icon: Icon(Icons.bar_chart_rounded, size: 18),
              text: 'Mi día'),
        ],
      ),
    );
  }
}

// ── Toggle disponibilidad ─────────────────────────────────────────────────────
class _ToggleDisponible extends StatelessWidget {
  final String uid;
  const _ToggleDisponible({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final disponible = data?['disponible'] as bool? ?? true;
        return GestureDetector(
          onTap: () async {
            HapticFeedback.mediumImpact();
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'disponible': !disponible});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: disponible
                  ? _kVerde.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: disponible
                    ? _kVerde.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.4),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: disponible ? _kVerde : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                disponible ? 'En servicio' : 'No disponible',
                style: TextStyle(
                  color: disponible ? _kVerde : Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════ TAB 1: DISPONIBLES ═══════════════════════════════════
class _TabDisponibles extends StatelessWidget {
  final String repartidorId;
  const _TabDisponibles({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: _kIndigo));
        }
        final disponibles = (snap.data ?? [])
            .where((p) =>
                p.estado == 'Listo' &&
                (p.repartidorId == null ||
                    p.repartidorId!.isEmpty))
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

        if (disponibles.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Text('📦',
                style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Sin pedidos disponibles',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Los pedidos listos aparecerán aquí',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: disponibles.length,
          itemBuilder: (_, i) => _CardDisponible(
              pedido: disponibles[i],
              repartidorId: repartidorId),
        );
      },
    );
  }
}

class _CardDisponible extends StatefulWidget {
  final PedidoModel pedido;
  final String repartidorId;
  const _CardDisponible(
      {required this.pedido, required this.repartidorId});
  @override
  State<_CardDisponible> createState() => _CardDisponibleState();
}

class _CardDisponibleState extends State<_CardDisponible> {
  bool _tomando = false;

  String _tiempoStr(DateTime f) {
    final diff = DateTime.now().difference(f);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min esperando';
    return '${diff.inHours}h ${diff.inMinutes % 60}m esperando';
  }

  Color _tiempoColor(DateTime f) {
    final mins = DateTime.now().difference(f).inMinutes;
    if (mins >= 20) return Colors.red;
    if (mins >= 10) return Colors.orange;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    final p       = widget.pedido;
    final dir     = p.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref     = p.direccionEntrega?['referencia'] ?? '';
    final metodo  = p.metodoPago;
    final esTrans = metodo == 'transferencia';
    final tColor  = _tiempoColor(p.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kVerde.withValues(alpha: 0.25),
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kVerde.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kVerde.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _kVerde.withValues(alpha: 0.4)),
              ),
              child: const Text('✅ LISTO PARA ENTREGAR',
                  style: TextStyle(color: _kVerde,
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
            ),
            const Spacer(),
            Icon(Icons.timer_outlined, size: 12, color: tColor),
            const SizedBox(width: 4),
            Text(_tiempoStr(p.fecha),
                style: TextStyle(color: tColor, fontSize: 11)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Cliente + teléfono
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 16, color: _kIndigo),
              const SizedBox(width: 6),
              Expanded(child: Text(p.clienteNombre,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15))),
              if (p.clienteTelefono != null)
                GestureDetector(
                  onTap: () => LauncherService.llamar(p.clienteTelefono!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kVerde.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(Icons.call_outlined,
                          size: 13, color: _kVerde),
                      SizedBox(width: 4),
                      Text('Llamar', style: TextStyle(
                          color: _kVerde, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 10),

            // Dirección
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 15, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(dir,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
                ]),
                if (ref.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: Colors.white24),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ref.toString(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 10),

            // Productos (top 3)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kCard2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('📦 ${p.items.length} producto${p.items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...p.items.take(3).map((i) => Text(
                    '  ${i['cantidad']}× ${i['productoNombre'] ?? i['nombre'] ?? ''}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12))),
                if (p.items.length > 3)
                  Text('  +${p.items.length - 3} más',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 12),

            // Total + método + botón tomar
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: _kVerde,
                        fontWeight: FontWeight.w900, fontSize: 22)),
                Row(children: [
                  Icon(
                    esTrans ? Icons.account_balance_outlined
                        : metodo == 'tarjeta'
                            ? Icons.credit_card_outlined
                            : Icons.payments_outlined,
                    size: 12,
                    color: esTrans ? _kAmb : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(metodo.toUpperCase(),
                      style: TextStyle(
                          color: esTrans ? _kAmb : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _tomando ? null
                    : () => _tomarPedido(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _tomando
                        ? _kIndigo.withValues(alpha: 0.3)
                        : _kIndigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _tomando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(children: [
                          Icon(Icons.delivery_dining,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('TOMAR PEDIDO',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ]),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Future<void> _tomarPedido(BuildContext context) async {
    setState(() => _tomando = true);
    final ok = await PedidoService()
        .asignarRepartidor(widget.pedido.id, widget.repartidorId);
    if (!mounted) return;
    setState(() => _tomando = false);
    if (ok) {
      UbicacionService().iniciarTracking();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Pedido asignado — GPS activado 📍'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ Error al tomar el pedido'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ══════════════════════ TAB 2: EN CAMINO ═════════════════════════════════════
class _TabMisEntregas extends StatelessWidget {
  final String repartidorId;
  const _TabMisEntregas({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio()
          .map((list) => list
              .where((p) => p.repartidorId == repartidorId)
              .toList()),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: _kIndigo));
        }
        final activos = (snap.data ?? [])
            .where((p) => p.estado == 'En camino')
            .toList();

        if (activos.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Text('🛵', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Sin entregas activas',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Toma un pedido disponible para empezar',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: activos.length,
          itemBuilder: (_, i) =>
              _CardEnCamino(pedido: activos[i]),
        );
      },
    );
  }
}

class _CardEnCamino extends StatefulWidget {
  final PedidoModel pedido;
  const _CardEnCamino({required this.pedido});
  @override
  State<_CardEnCamino> createState() => _CardEnCaminoState();
}

class _CardEnCaminoState extends State<_CardEnCamino> {
  final _codigoCtrl = TextEditingController();
  bool _verificando = false;
  bool _expandido   = true;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.pedido.fecha);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() =>
          _elapsed = DateTime.now().difference(widget.pedido.fecha));
    });
  }

  @override
  void dispose() { _timer?.cancel(); _codigoCtrl.dispose(); super.dispose(); }

  String get _tiempoStr {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  Color get _tiempoColor {
    if (_elapsed.inMinutes >= 30) return Colors.red;
    if (_elapsed.inMinutes >= 20) return Colors.orange;
    return _kAzul;
  }

  @override
  Widget build(BuildContext context) {
    final p   = widget.pedido;
    final dir = p.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final ref = p.direccionEntrega?['referencia'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kIndigo.withValues(alpha: 0.5),
            width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header con timer en vivo
        GestureDetector(
          onTap: () =>
              setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kIndigo.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kIndigo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🛵 EN CAMINO',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined,
                  size: 13, color: _tiempoColor),
              const SizedBox(width: 4),
              Text(_tiempoStr, style: TextStyle(
                  color: _tiempoColor, fontWeight: FontWeight.bold,
                  fontSize: 13, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Icon(_expandido
                  ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white24, size: 18),
            ]),
          ),
        ),

        if (_expandido)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Cliente
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 16, color: _kIndigo),
                const SizedBox(width: 6),
                Expanded(child: Text(p.clienteNombre,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 15))),
                if (p.clienteTelefono != null)
                  _BtnAccion(
                    icon: Icons.call_outlined,
                    label: 'Llamar',
                    color: _kVerde,
                    onTap: () => LauncherService.llamar(p.clienteTelefono!),
                  ),
                const SizedBox(width: 8),
                _BtnAccion(
                  icon: Icons.map_outlined,
                  label: 'Mapa',
                  color: _kAzul,
                  onTap: () => LauncherService.abrirMaps(dir),
                ),
              ]),
              const SizedBox(height: 10),

              // Dirección
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Icon(Icons.location_on,
                        size: 15, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(dir,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                  ]),
                  if (ref.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: Colors.white24),
                      const SizedBox(width: 6),
                      Expanded(child: Text(ref.toString(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11))),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 10),

              // Total + método
              Row(children: [
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: _kVerde,
                        fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kCard2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(p.metodoPago.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10)),
                ),
              ]),
              const SizedBox(height: 14),

              // Campo código verificación
              const Text('CÓDIGO DE ENTREGA',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: _codigoCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.bold,
                      letterSpacing: 6),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '_ _ _ _ _ _',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        letterSpacing: 6, fontSize: 20),
                    filled: true,
                    fillColor: _kCard2,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _kIndigo.withValues(alpha: 0.6),
                            width: 2)),
                  ),
                )),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _verificando ? null : () => _verificar(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kVerde.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kVerde.withValues(alpha: 0.4)),
                    ),
                    child: _verificando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: _kVerde, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline,
                            color: _kVerde, size: 24),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Pide el código al cliente para confirmar la entrega',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 11)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _verificar(BuildContext context) async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ El código tiene 6 dígitos'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _verificando = true);
    try {
      final ok = await PedidoService()
          .marcarEntregadoDomicilio(widget.pedido.id, codigo);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 ¡Entrega confirmada!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Código incorrecto'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }
}

// ── Botón de acción ───────────────────────────────────────────────────────────
class _BtnAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BtnAccion({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// ══════════════════════ TAB 3: MI DÍA ════════════════════════════════════════
class _TabMiDia extends StatelessWidget {
  final String repartidorId;
  const _TabMiDia({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('repartidorId', isEqualTo: repartidorId)
          .where('fecha', isGreaterThanOrEqualTo:
              Timestamp.fromDate(inicioHoy))
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: _kIndigo));
        }
        final pedidos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        final entregados  = pedidos
            .where((p) => p.estado == 'Entregado').toList();
        final enCamino    = pedidos
            .where((p) => p.estado == 'En camino').length;
        final cancelados  = pedidos
            .where((p) => p.estado == 'Cancelado').length;
        final ventas      = entregados.fold(0.0, (s, p) => s + p.total);
        final promedio    = entregados.isEmpty ? 0.0
            : ventas / entregados.length;

        // Gráfica por hora
        final Map<int, int> porHora = {};
        for (final p in entregados) {
          porHora[p.fecha.hour] = (porHora[p.fecha.hour] ?? 0) + 1;
        }
        final maxH = porHora.values.isEmpty ? 1
            : porHora.values.reduce((a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── Banner resumen ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _kIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _kIndigo.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(children: [
                Row(children: [
                  const Text('🛵', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Mi resumen de hoy',
                        style: TextStyle(color: Colors.white54,
                            fontSize: 12)),
                    Text('${hoy.hour.toString().padLeft(2,'0')}:${hoy.minute.toString().padLeft(2,'0')} hs',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900, fontSize: 18)),
                  ]),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _DayStat('✅', '${entregados.length}',
                      'Entregas', _kVerde),
                  _DayStat('🛵', '$enCamino',
                      'En camino', _kIndigo),
                  _DayStat('❌', '$cancelados',
                      'Cancelados', Colors.red),
                  _DayStat('💰', '\$${ventas.toStringAsFixed(0)}',
                      'Total', _kAmb),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Ticket promedio ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text('Ticket promedio',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13))),
                Text('\$${promedio.toStringAsFixed(2)}',
                    style: const TextStyle(color: _kVerde,
                        fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Gráfica actividad ──────────────────────────────────────
            if (porHora.isNotEmpty) ...[
              Text('ACTIVIDAD POR HORA',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: SizedBox(
                  height: 70,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (h) {
                      final cnt = porHora[h] ?? 0;
                      final pct = maxH > 0 ? cnt / maxH : 0.0;
                      final esActual = h == hoy.hour;
                      if (cnt == 0 && !esActual) {
                        final keys = porHora.keys.toList()..sort();
                        if (keys.isEmpty) return const SizedBox.shrink();
                        if (h < (keys.first - 1) || h > (keys.last + 1)) {
                          return const SizedBox.shrink();
                        }
                      }
                      return Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                          if (cnt > 0)
                            Text('$cnt', style: TextStyle(
                                color: esActual
                                    ? _kIndigo : Colors.white38,
                                fontSize: 8)),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: (pct * 45).clamp(2.0, 45.0),
                            decoration: BoxDecoration(
                              color: esActual
                                  ? _kIndigo
                                  : _kIndigo.withValues(alpha: 0.4),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('$h', style: const TextStyle(
                              color: Colors.white24, fontSize: 7)),
                        ]),
                      ));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Historial del día ──────────────────────────────────────
            if (pedidos.isNotEmpty) ...[
              Text('HISTORIAL DE HOY',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              ...pedidos.map((p) {
                final color = p.estado == 'Entregado' ? _kVerde
                    : p.estado == 'En camino' ? _kIndigo
                    : Colors.red;
                final hora = '${p.fecha.hour.toString().padLeft(2,'0')}:'
                    '${p.fecha.minute.toString().padLeft(2,'0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Text(
                      p.estado == 'Entregado' ? '✅'
                          : p.estado == 'En camino' ? '🛵' : '❌',
                      style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(p.clienteNombre,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(p.direccionEntrega?['direccion'] ?? '',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('\$${p.total.toStringAsFixed(2)}',
                          style: TextStyle(color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      Text(hora, style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10)),
                    ]),
                  ]),
                );
              }),
            ] else
              Center(child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(children: [
                  const Text('📊', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text('Sin entregas hoy aún',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                ]),
              )),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ── Stat del día ──────────────────────────────────────────────────────────────
class _DayStat extends StatelessWidget {
  final String emoji, valor, label;
  final Color color;
  const _DayStat(this.emoji, this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 2),
    Text(valor, style: TextStyle(color: color,
        fontWeight: FontWeight.w900, fontSize: 16)),
    Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}
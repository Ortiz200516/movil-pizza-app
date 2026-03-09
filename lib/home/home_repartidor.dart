import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/launcher_service.dart';
import '../services/auth_services.dart';
import '../services/ubicacion_service.dart';
import '../services/notificacion_service.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

// Colores del tema
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kAccent = Color(0xFF6366F1); // índigo moderno

class HomeRepartidor extends StatefulWidget {
  const HomeRepartidor({super.key});
  @override State<HomeRepartidor> createState() => _HomeRepartidorState();
}

class _HomeRepartidorState extends State<HomeRepartidor> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Error: sin sesión')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _RepartidorAppBar(uid: user!.uid),
        body: TabBarView(children: [
          _TabDisponibles(repartidorId: user!.uid),
          _TabMisEntregas(repartidorId: user!.uid),
          _TabMiDia(repartidorId: user!.uid),
        ]),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────
class _RepartidorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String uid;
  const _RepartidorAppBar({required this.uid});
  @override Size get preferredSize => const Size.fromHeight(110);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final disponible = data['disponible'] as bool? ?? false;
        final nombre = (data['nombre'] as String? ?? 'Repartidor').split(' ').first;

        return AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          titleSpacing: 16,
          title: Row(children: [
            // Avatar + nombre
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _kAccent.withOpacity(0.5)),
              ),
              child: const Center(child: Text('🛵', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Row(children: [
                Container(width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: disponible ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(disponible ? 'En línea' : 'Fuera de línea',
                    style: TextStyle(
                      color: disponible ? Colors.green : Colors.red.shade300,
                      fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ]),
          actions: [
            // Toggle disponibilidad
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                FirebaseFirestore.instance.collection('users').doc(uid)
                    .update({'disponible': !disponible});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: disponible
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: disponible ? Colors.green : Colors.red.shade400,
                    width: 1.5,
                  ),
                ),
                child: Text(disponible ? '● Activo' : '○ Inactivo',
                    style: TextStyle(
                      color: disponible ? Colors.green : Colors.red.shade300,
                      fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            NotifBadgeBtn(uid: uid, rol: 'repartidor'),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const LoginPage()));
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: _kAccent,
            indicatorWeight: 3,
            labelColor: _kAccent,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.inbox_rounded, size: 18), text: 'Disponibles'),
              Tab(icon: Icon(Icons.delivery_dining, size: 18), text: 'En camino'),
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Mi día'),
            ],
          ),
        );
      },
    );
  }
}

// ── TAB 1: DISPONIBLES ────────────────────────────────────────────────────────
class _TabDisponibles extends StatelessWidget {
  final String repartidorId;
  const _TabDisponibles({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        final todos = snap.data ?? [];
        final disponibles = todos.where((p) =>
            p.estado == 'Listo' &&
            (p.repartidorId == null || p.repartidorId!.isEmpty)).toList();

        if (disponibles.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📦', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 16),
            const Text('No hay pedidos disponibles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Colors.white38)),
            const SizedBox(height: 8),
            const Text('Espera nuevas entregas',
                style: TextStyle(color: Colors.white24)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: disponibles.length,
          itemBuilder: (_, i) => _CardDisponible(
              pedido: disponibles[i], repartidorId: repartidorId),
        );
      },
    );
  }
}

class _CardDisponible extends StatefulWidget {
  final PedidoModel pedido;
  final String repartidorId;
  const _CardDisponible({required this.pedido, required this.repartidorId});
  @override State<_CardDisponible> createState() => _CardDisponibleState();
}

class _CardDisponibleState extends State<_CardDisponible> {
  bool _tomando = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final direccion = p.direccionEntrega?['direccion'] ?? 'Sin dirección';
    final referencia = p.direccionEntrega?['referencia'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(
            color: _kAccent.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: Colors.green.withOpacity(0.2))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.5))),
              child: const Text('✅ LISTO PARA ENTREGAR',
                  style: TextStyle(color: Colors.green,
                      fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const Spacer(),
            _LiveTimer(fecha: p.fecha),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Cliente ───────────────────────────────
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.clienteNombre, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                if (p.clienteTelefono != null)
                  Text(p.clienteTelefono!,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
              // Botón llamar
              if (p.clienteTelefono != null)
                _BotonLlamar(telefono: p.clienteTelefono!),
            ]),
            const SizedBox(height: 12),

            // ── Dirección con link a Maps ──────────────
            _DireccionCard(direccion: direccion, referencia: referencia),
            const SizedBox(height: 12),

            // ── Productos ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📦 Contenido del pedido',
                    style: TextStyle(color: Colors.white54,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...p.items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text('${item['cantidad']}',
                          style: TextStyle(color: _kAccent,
                              fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                        item['productoNombre'] ?? item['nombre'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                )),
                if (p.items.length > 3)
                  Text('  +${p.items.length - 3} más',
                      style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Total + botón tomar ────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total del pedido',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text('\$${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 26,
                        fontWeight: FontWeight.w900, color: Colors.green)),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _tomando ? null : () => _tomarPedido(context),
                icon: _tomando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delivery_dining, size: 18),
                label: Text(_tomando ? 'Tomando...' : 'TOMAR',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
    HapticFeedback.mediumImpact();
    final ok = await PedidoService().asignarRepartidor(
        widget.pedido.id, widget.repartidorId);
    if (mounted) {
      setState(() => _tomando = false);
      if (ok) {
        UbicacionService().iniciarTracking();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Pedido tomado — ¡a entregar! GPS activado 📍'),
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
}

// ── TAB 2: MIS ENTREGAS EN CAMINO ────────────────────────────────────────────
class _TabMisEntregas extends StatelessWidget {
  final String repartidorId;
  const _TabMisEntregas({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        final todos = snap.data ?? [];
        final misEntregas = todos.where((p) =>
            p.repartidorId == repartidorId && p.estado == 'En camino').toList();

        if (misEntregas.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🛵', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 16),
            const Text('Sin entregas activas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Colors.white38)),
            const SizedBox(height: 8),
            const Text('Toma un pedido de la pestaña "Disponibles"',
                style: TextStyle(color: Colors.white24), textAlign: TextAlign.center),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: misEntregas.length,
          itemBuilder: (_, i) => _CardEnCamino(pedido: misEntregas[i]),
        );
      },
    );
  }
}

class _CardEnCamino extends StatefulWidget {
  final PedidoModel pedido;
  const _CardEnCamino({required this.pedido});
  @override State<_CardEnCamino> createState() => _CardEnCaminoState();
}

class _CardEnCaminoState extends State<_CardEnCamino> {
  final _codigoCtrl = TextEditingController();
  bool _verificando = false;
  bool _expandido = true;

  @override void dispose() { _codigoCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final direccion = p.direccionEntrega?['direccion'] ?? '';
    final referencia = p.direccionEntrega?['referencia'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(
            color: _kAccent.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAccent.withOpacity(0.5))),
                child: const Text('🛵 EN CAMINO',
                    style: TextStyle(color: _kAccent,
                        fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const Spacer(),
              _LiveTimer(fecha: p.fecha),
              const SizedBox(width: 8),
              Icon(_expandido ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38, size: 20),
            ]),
          ),
        ),

        if (_expandido) Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Cliente ───────────────────────────────
            Row(children: [
              const Text('👤', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(p.clienteNombre,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: Colors.white))),
              if (p.clienteTelefono != null)
                _BotonLlamar(telefono: p.clienteTelefono!),
            ]),
            const SizedBox(height: 10),

            // ── Dirección ─────────────────────────────
            _DireccionCard(direccion: direccion, referencia: referencia),
            const SizedBox(height: 10),

            // ── Total ─────────────────────────────────
            Row(children: [
              const Text('💰', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('\$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ]),
            const SizedBox(height: 14),

            // ── Panel verificación código ──────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 6),
                  Text('Verificar entrega',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                const Text('Ingresa el código de 6 dígitos del cliente:',
                    style: TextStyle(fontSize: 12, color: Colors.white38)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _codigoCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold,
                          letterSpacing: 10, color: Colors.white),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: const TextStyle(
                            color: Colors.white12, letterSpacing: 10),
                        filled: true, fillColor: _kBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Colors.amber.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.amber, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _verificando ? null : () => _verificar(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      elevation: 0,
                    ),
                    child: _verificando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('✓', style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _verificar(BuildContext context) async {
    if (_codigoCtrl.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El código debe tener 6 dígitos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _verificando = true);
    HapticFeedback.mediumImpact();
    final ok = await PedidoService().marcarEntregadoDomicilio(
        widget.pedido.id, _codigoCtrl.text.trim());
    if (mounted) {
      setState(() => _verificando = false);
      if (ok) {
        UbicacionService().detenerTracking();
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _kCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('✅ ¡Entregado!', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 10),
              const Text('Pedido entregado correctamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('\$${widget.pedido.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.green, fontSize: 24),
                  textAlign: TextAlign.center),
              const Text('registrado en tu cuenta',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            actions: [ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('¡Listo!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('❌ Código incorrecto. Verifica con el cliente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ── TAB 3: MI DÍA ─────────────────────────────────────────────────────────────
class _TabMiDia extends StatelessWidget {
  final String repartidorId;
  const _TabMiDia({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    const metaDiaria = 20; // meta de entregas

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('repartidorId', isEqualTo: repartidorId)
          .where('estado', isEqualTo: 'Entregado')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        final docs = snap.data?.docs ?? [];
        final pedidos = docs.map((d) =>
            PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();

        final totalEntregas  = pedidos.length;
        final totalGanancias = pedidos.fold(0.0, (s, p) => s + p.total);
        final promedio = totalEntregas > 0 ? totalGanancias / totalEntregas : 0.0;
        final progreso = (totalEntregas / metaDiaria).clamp(0.0, 1.0);

        // Pedidos por hora
        final Map<int, int> porHora = {};
        for (final p in pedidos) {
          final h = p.fecha.hour;
          porHora[h] = (porHora[h] ?? 0) + 1;
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Banner resumen ─────────────────────────
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3730A3), Color(0xFF6366F1)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(children: [
                Row(children: [
                  const Text('🛵', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Mi resumen de hoy',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${hoy.day}/${hoy.month}/${hoy.year}',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  _DayStat('Entregas', '$totalEntregas', '📦'),
                  _DayStat('Ganancias', '\$${totalGanancias.toStringAsFixed(0)}', '💰'),
                  _DayStat('Promedio', '\$${promedio.toStringAsFixed(0)}', '📈'),
                ]),
                const SizedBox(height: 16),
                // Barra de progreso meta
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Meta del día',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$totalEntregas / $metaDiaria entregas',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso, minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(
                          progreso >= 1.0 ? Colors.green : Colors.white),
                    ),
                  ),
                  if (progreso >= 1.0) ...[
                    const SizedBox(height: 6),
                    const Text('🎉 ¡Meta alcanzada!',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ]),
              ]),
            ),

            // ── Gráfica por hora ───────────────────────
            if (porHora.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: const Text('📊 Entregas por hora',
                    style: TextStyle(color: Colors.white70,
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _GraficaHoras(porHora: porHora),
              ),
              const SizedBox(height: 16),
            ],

            // ── Historial del día ──────────────────────
            if (pedidos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Text('📦', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text('Sin entregas hoy todavía',
                      style: TextStyle(fontSize: 16,
                          color: Colors.white38, fontWeight: FontWeight.bold)),
                ]),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: const Text('Historial de hoy',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: Colors.white70)),
              ),
              ...pedidos.map((p) {
                final hora = '${p.fecha.hour.toString().padLeft(2, '0')}:'
                    '${p.fecha.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                          color: Color(0xFF052E16), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('✅', style: TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.clienteNombre, style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14, color: Colors.white)),
                      Text(p.direccionEntrega?['direccion'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$hora · ${p.items.length} productos',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white24)),
                    ])),
                    Text('\$${p.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15, color: Colors.green)),
                  ]),
                );
              }),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }
}

// ── Gráfica de barras por hora ────────────────────────────────────────────────
class _GraficaHoras extends StatelessWidget {
  final Map<int, int> porHora;
  const _GraficaHoras({required this.porHora});
  @override
  Widget build(BuildContext context) {
    final maxVal = porHora.values.reduce((a, b) => a > b ? a : b);
    final horas  = porHora.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        SizedBox(
          height: 70,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end,
            children: horas.map((h) {
              final val = porHora[h] ?? 0;
              final pct = maxVal > 0 ? val / maxVal : 0.0;
              final esAhora = h == DateTime.now().hour;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (val > 0)
                    Text('$val', style: TextStyle(
                        color: esAhora ? _kAccent : Colors.white38,
                        fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    height: (pct * 45).clamp(4.0, 45.0),
                    decoration: BoxDecoration(
                      color: esAhora ? _kAccent : _kAccent.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
              ));
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: horas.map((h) => Expanded(
          child: Text('${h}h', textAlign: TextAlign.center,
              style: TextStyle(
                  color: h == DateTime.now().hour ? _kAccent : Colors.white24,
                  fontSize: 8)),
        )).toList()),
      ]),
    );
  }
}

// ── Widgets reutilizables ─────────────────────────────────────────────────────

/// Timer en vivo MM:SS
class _LiveTimer extends StatefulWidget {
  final DateTime fecha;
  const _LiveTimer({required this.fecha});
  @override State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  late Timer _timer;
  late DateTime _ahora;
  @override
  void initState() {
    super.initState();
    _ahora = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _ahora = DateTime.now()); });
  }
  @override void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final diff  = _ahora.difference(widget.fecha);
    final mm    = diff.inMinutes.toString().padLeft(2, '0');
    final ss    = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final urgente = diff.inMinutes >= 20;
    final color = urgente ? Colors.red : diff.inMinutes >= 10 ? Colors.orange : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, color: color, size: 11),
        const SizedBox(width: 3),
        Text('$mm:$ss', style: TextStyle(
            color: color, fontSize: 11,
            fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }
}

/// Botón para llamar al cliente
class _BotonLlamar extends StatelessWidget {
  final String telefono;
  const _BotonLlamar({required this.telefono});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final ok = await LauncherService.llamar(telefono);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo llamar a $telefono'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.green.withOpacity(0.4)),
        ),
        child: const Icon(Icons.phone, color: Colors.green, size: 18),
      ),
    );
  }
}

/// Tarjeta de dirección con Google Maps y navegación GPS
class _DireccionCard extends StatelessWidget {
  final String direccion;
  final String referencia;
  const _DireccionCard({required this.direccion, required this.referencia});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(direccion, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
            if (referencia.isNotEmpty)
              Text(referencia, style: const TextStyle(
                  fontSize: 11, color: Colors.white38)),
          ])),
        ]),
        const SizedBox(height: 10),
        // Botones Maps y Navegar
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await LauncherService.abrirMaps(direccion);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No se pudo abrir Google Maps'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              icon: const Icon(Icons.map_outlined, size: 15),
              label: const Text('Ver en Maps',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final ok = await LauncherService.navegar(direccion);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No se pudo abrir la navegación'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              icon: const Icon(Icons.navigation, size: 15),
              label: const Text('Navegar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DayStat extends StatelessWidget {
  final String label, value, emoji;
  const _DayStat(this.label, this.value, this.emoji);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ]),
  );
}
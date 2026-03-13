import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/ubicacion_service.dart';
import '../services/notificacion_service.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeRepartidor extends StatefulWidget {
  const HomeRepartidor({super.key});
  @override
  State<HomeRepartidor> createState() => _HomeRepartidorState();
}

class _HomeRepartidorState extends State<HomeRepartidor> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Error: sin sesión')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        appBar: AppBar(
          title: const Text('🛵 Panel Repartidor'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            _ToggleDisponible(uid: user!.uid),
            NotifBadgeBtn(uid: user!.uid, rol: 'repartidor'),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.inbox, size: 20),
                  text: 'Disponibles'),
              Tab(icon: Icon(Icons.delivery_dining, size: 20),
                  text: 'Mis entregas'),
              Tab(icon: Icon(Icons.bar_chart, size: 20),
                  text: 'Mi día'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TabDisponibles(repartidorId: user!.uid),
            _TabMisEntregas(repartidorId: user!.uid),
            _TabMiDia(repartidorId: user!.uid),
          ],
        ),
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
      builder: (context, snap) {
        final disponible =
            (snap.data?.data() as Map<String, dynamic>?)
                ?['disponible'] as bool? ?? false;
        return GestureDetector(
          onTap: () => FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'disponible': !disponible}),
          child: Container(
            margin: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: disponible
                  ? Colors.green.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: disponible
                      ? Colors.green
                      : Colors.white30),
            ),
            child: Row(children: [
              Icon(
                  disponible
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 10,
                  color: disponible
                      ? Colors.green
                      : Colors.white54),
              const SizedBox(width: 5),
              Text(disponible ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: disponible
                          ? Colors.green
                          : Colors.white54)),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════ TAB 1: DISPONIBLES ═══════════════════════════════════════
class _TabDisponibles extends StatelessWidget {
  final String repartidorId;
  const _TabDisponibles({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.indigo));
        }
        final todos = snap.data ?? [];
        final disponibles = todos
            .where((p) =>
                p.estado == 'Listo' &&
                (p.repartidorId == null ||
                    p.repartidorId!.isEmpty))
            .toList();

        if (disponibles.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Text('📦', style: TextStyle(fontSize: 70)),
              const SizedBox(height: 16),
              const Text('No hay pedidos disponibles',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38)),
              const SizedBox(height: 8),
              const Text('Espera nuevas entregas',
                  style: TextStyle(color: Colors.white24)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.indigo.withValues(alpha: 0.4)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header verde
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            border: Border(
                bottom: BorderSide(
                    color:
                        Colors.green.withValues(alpha: 0.25))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('✅ LISTO',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const Spacer(),
            Text('#${p.id.substring(0, 6).toUpperCase()}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white38)),
            const SizedBox(width: 8),
            Text(_tiempoTranscurrido(p.fecha),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.person,
                  size: 18, color: Colors.indigo),
              const SizedBox(width: 6),
              Text(p.clienteNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
              if (p.clienteTelefono != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone,
                    size: 14, color: Colors.white24),
                const SizedBox(width: 2),
                Text(p.clienteTelefono!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38)),
              ],
            ]),
            const SizedBox(height: 8),

            // Dirección
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          p.direccionEntrega?[
                                  'direccion'] ??
                              'Sin dirección',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white))),
                ]),
                if ((p.direccionEntrega?['referencia'] ??
                            '')
                        .toString()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            p.direccionEntrega![
                                    'referencia']
                                .toString(),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 10),

            // Productos
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                const Text('Contenido:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white70)),
                const SizedBox(height: 4),
                ...p.items.take(3).map((i) => Text(
                    '  ${i['cantidad']}× '
                    '${i['productoNombre'] ?? i['nombre'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70))),
                if (p.items.length > 3)
                  Text(
                      '  ...y ${p.items.length - 3} más',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Text('\$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _tomando
                    ? null
                    : () => _tomarPedido(context),
                icon: _tomando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.delivery_dining),
                label: Text(
                    _tomando
                        ? 'Tomando...'
                        : 'TOMAR PEDIDO',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
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
    final ok = await PedidoService().asignarRepartidor(
        widget.pedido.id, widget.repartidorId);
    if (!mounted) return;
    setState(() => _tomando = false);
    if (ok) {
      UbicacionService().iniciarTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            '✅ Pedido asignado — ¡a entregar! GPS activado 📍'),
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

  String _tiempoTranscurrido(DateTime f) {
    final diff = DateTime.now().difference(f);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours}h';
  }
}

// ══════════════════ TAB 2: MIS ENTREGAS ACTIVAS ══════════════════════════════
class _TabMisEntregas extends StatelessWidget {
  final String repartidorId;
  const _TabMisEntregas({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerPedidosDomicilio(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.indigo));
        }
        final todos = snap.data ?? [];
        final misEntregas = todos
            .where((p) =>
                p.repartidorId == repartidorId &&
                p.estado == 'En camino')
            .toList();

        if (misEntregas.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Text('🛵', style: TextStyle(fontSize: 70)),
              const SizedBox(height: 16),
              const Text('Sin entregas activas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38)),
              const SizedBox(height: 8),
              const Text(
                  'Toma un pedido de la pestaña "Disponibles"',
                  style: TextStyle(color: Colors.white24),
                  textAlign: TextAlign.center),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: misEntregas.length,
          itemBuilder: (_, i) =>
              _CardEnCamino(pedido: misEntregas[i]),
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

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.indigo.withValues(alpha: 0.6),
            width: 1.5),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header azul colapsable
        GestureDetector(
          onTap: () =>
              setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('🛵 EN CAMINO',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const Spacer(),
              Text('#${p.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white38)),
              const SizedBox(width: 8),
              Icon(
                  _expandido
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.grey),
            ]),
          ),
        ),

        if (_expandido)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Cliente
              Row(children: [
                const Icon(Icons.person,
                    size: 18, color: Colors.indigo),
                const SizedBox(width: 6),
                Text(p.clienteNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white)),
              ]),
              if (p.clienteTelefono != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const SizedBox(width: 24),
                  const Icon(Icons.phone,
                      size: 15, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(p.clienteTelefono!,
                      style: const TextStyle(
                          color: Colors.white38)),
                ]),
              ],
              const SizedBox(height: 10),

              // Dirección
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.location_on,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                    Text(
                        p.direccionEntrega?['direccion'] ??
                            '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    if ((p.direccionEntrega?['referencia'] ??
                                '')
                            .toString()
                            .isNotEmpty)
                      Text(
                          p.direccionEntrega!['referencia']
                              .toString(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38)),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),

              Text('\$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 16),

              // Panel verificación
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange
                          .withValues(alpha: 0.4)),
                ),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                  const Row(children: [
                    Icon(Icons.lock,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 6),
                    Text('Verificar entrega',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                      'Ingresa el código de 6 dígitos del cliente:',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white54)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoCtrl,
                        keyboardType:
                            TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: Colors.white),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '------',
                          hintStyle: const TextStyle(
                              color: Colors.white12,
                              letterSpacing: 8),
                          filled: true,
                          fillColor:
                              const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.orange
                                      .withValues(
                                          alpha: 0.4))),
                          focusedBorder:
                              OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          10),
                                  borderSide:
                                      const BorderSide(
                                          color:
                                              Colors.orange,
                                          width: 2)),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      // Sin pasar context como parámetro
                      onPressed: _verificando
                          ? null
                          : _verificar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                      ),
                      child: _verificando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                          : const Text('OK',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── FIX: sin parámetro BuildContext
  // ── FIX: if (!mounted) return  →  elimina warning async gap
  Future<void> _verificar() async {
    if (_codigoCtrl.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El código debe tener 6 dígitos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _verificando = true);

    final ok = await PedidoService().marcarEntregadoDomicilio(
        widget.pedido.id, _codigoCtrl.text.trim());

    if (!mounted) return; // guarda post-await
    setState(() => _verificando = false);

    if (ok) {
      UbicacionService().detenerTracking();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('✅ ¡Entregado!',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            const Text('🎉',
                style: TextStyle(fontSize: 50)),
            const SizedBox(height: 10),
            const Text(
                'Pedido entregado correctamente.',
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
                '\$${widget.pedido.total.toStringAsFixed(2)} registrado.',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16),
                textAlign: TextAlign.center),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize:
                      const Size(double.infinity, 44)),
              child: const Text('¡Listo!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '❌ Código incorrecto. Verifica con el cliente.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3)));
    }
  }
}

// ══════════════════ TAB 3: MI DÍA ════════════════════════════════════════════
class _TabMiDia extends StatelessWidget {
  final String repartidorId;
  const _TabMiDia({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    final hoy       = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('repartidorId', isEqualTo: repartidorId)
          .where('estado', isEqualTo: 'Entregado')
          .where('fecha',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(inicioHoy))
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.indigo));
        }
        final docs = snap.data?.docs ?? [];
        final pedidos = docs
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        final totalEntregas  = pedidos.length;
        final totalGanancias =
            pedidos.fold(0.0, (s, p) => s + p.total);
        final promedio = totalEntregas > 0
            ? totalGanancias / totalEntregas
            : 0.0;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Resumen del día
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3730A3),
                      Color(0xFF4F46E5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.indigo
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(children: [
                const Row(children: [
                  Text('🛵',
                      style: TextStyle(fontSize: 28)),
                  SizedBox(width: 10),
                  Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Text('Mi resumen de hoy',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13)),
                    Text('Estadísticas del día',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ]),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  _DayStat('Entregas', '$totalEntregas',
                      Icons.check_circle_outline),
                  _DayStat(
                      'Total',
                      '\$${totalGanancias.toStringAsFixed(2)}',
                      Icons.attach_money),
                  _DayStat(
                      'Promedio',
                      '\$${promedio.toStringAsFixed(2)}',
                      Icons.trending_up),
                ]),
              ]),
            ),

            if (pedidos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(children: [
                  Text('📦',
                      style: TextStyle(fontSize: 60)),
                  SizedBox(height: 16),
                  Text('Sin entregas hoy todavía',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white38,
                          fontWeight: FontWeight.bold)),
                ]),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16),
                child: Text('Historial de hoy',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              ...pedidos.map((p) {
                final hora =
                    '${p.fecha.hour.toString().padLeft(2, '0')}:'
                    '${p.fecha.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: Color(0xFF052E16),
                          shape: BoxShape.circle),
                      child: const Center(
                          child: Text('✅',
                              style: TextStyle(
                                  fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                      Text(p.clienteNombre,
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white)),
                      Text(
                          p.direccionEntrega?[
                                  'direccion'] ??
                              '',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis),
                      Text(
                          '$hora · ${p.items.length} productos',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white24)),
                    ])),
                    Text(
                        '\$${p.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green)),
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

class _DayStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _DayStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white60)),
        ]),
      );
}
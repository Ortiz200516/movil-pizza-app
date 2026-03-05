import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import '../carrito/carrito_provider.dart';
import 'package:provider/provider.dart';
import 'calificacion_page.dart';
import 'tracking_page.dart';

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
        color: const Color(0xFF0F172A),
        child: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFF6B35),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF6B35),
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
        child: TabBarView(controller: _tab, children: [
          _TabEnProceso(uid: user.uid),
          _TabHistorial(uid: user.uid),
        ]),
      ),
    ]);
  }
}

// ── TAB EN PROCESO ────────────────────────────────────────────
class _TabEnProceso extends StatelessWidget {
  final String uid;
  const _TabEnProceso({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado')
            .toList();

        if (todos.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const Text('✅', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 14),
                const Text('Sin pedidos activos',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('¡Todo entregado!',
                    style:
                        TextStyle(color: Colors.white.withOpacity(0.25))),
              ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: todos.length,
          itemBuilder: (_, i) =>
              _TarjetaPedido(pedido: todos[i], enProceso: true),
        );
      },
    );
  }
}

// ── TAB HISTORIAL ─────────────────────────────────────────────
class _TabHistorial extends StatefulWidget {
  final String uid;
  const _TabHistorial({required this.uid});
  @override
  State<_TabHistorial> createState() => _TabHistorialState();
}

class _TabHistorialState extends State<_TabHistorial> {
  String _filtro   = 'Todos';
  String _busqueda = '';
  int?   _mesFiltro; // null = todos los meses
  final _searchCtrl = TextEditingController();

  static const _meses = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: widget.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
        }

        final todosPedidos = (snap.data?.docs ?? [])
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .where((p) => p.estado == 'Entregado' || p.estado == 'Cancelado')
            .toList();

        // Stats generales
        final entregados =
            todosPedidos.where((p) => p.estado == 'Entregado').length;
        final cancelados =
            todosPedidos.where((p) => p.estado == 'Cancelado').length;
        final gastado = todosPedidos
            .where((p) => p.estado == 'Entregado')
            .fold(0.0, (s, p) => s + p.total);

        // Aplicar filtros
        var pedidos = todosPedidos.where((p) {
          final matchEstado =
              _filtro == 'Todos' || p.estado == _filtro;
          final matchMes =
              _mesFiltro == null || p.fecha.month == _mesFiltro;
          final matchBusqueda = _busqueda.isEmpty ||
              p.items.any((item) =>
                  (item['productoNombre'] ?? item['nombre'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_busqueda.toLowerCase())) ||
              (p.codigoVerificacion ?? '')
                  .contains(_busqueda);
          return matchEstado && matchMes && matchBusqueda;
        }).toList();

        return Column(children: [
          // ── Stats ──
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(children: [
              _StatItem('📦', '$entregados', 'Entregados', Colors.green),
              _divider(),
              _StatItem('❌', '$cancelados', 'Cancelados', Colors.red),
              _divider(),
              _StatItem('💰', '\$${gastado.toStringAsFixed(2)}', 'Gastado',
                  const Color(0xFFFF6B35)),
            ]),
          ),

          // ── Buscador ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _busqueda = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar por producto o código...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white38, size: 20),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _busqueda = '');
                        })
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFFF6B35), width: 1.5)),
              ),
            ),
          ),

          // ── Filtros estado ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todos', 'Entregado', 'Cancelado'].map((f) {
                  final sel = _filtro == f;
                  final color = f == 'Entregado'
                      ? Colors.green
                      : f == 'Cancelado'
                          ? Colors.red
                          : const Color(0xFFFF6B35);
                  return GestureDetector(
                    onTap: () => setState(() => _filtro = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withOpacity(0.15)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? color.withOpacity(0.6)
                                : Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(f,
                          style: TextStyle(
                            color: sel ? color : Colors.white38,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Filtro por mes ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipMes(
                      label: 'Todos',
                      seleccionado: _mesFiltro == null,
                      onTap: () => setState(() => _mesFiltro = null)),
                  ...List.generate(12, (i) {
                    final mes = i + 1;
                    return _ChipMes(
                      label: _meses[i],
                      seleccionado: _mesFiltro == mes,
                      onTap: () => setState(() =>
                          _mesFiltro = _mesFiltro == mes ? null : mes),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Lista ──
          Expanded(
            child: pedidos.isEmpty
                ? Center(
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
                              color: Colors.white38, fontSize: 15)),
                    ]))
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    itemCount: pedidos.length,
                    itemBuilder: (_, i) => _TarjetaPedido(
                        pedido: pedidos[i], enProceso: false),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 32,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 12));
}

// ── Chip de mes ───────────────────────────────────────────────
class _ChipMes extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;
  const _ChipMes(
      {required this.label,
      required this.seleccionado,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionado
                ? Colors.blue.withOpacity(0.2)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: seleccionado
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.white.withOpacity(0.06)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: seleccionado ? Colors.blue : Colors.white38,
                  fontSize: 11,
                  fontWeight: seleccionado
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
      );
}

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

// ── TARJETA PEDIDO ────────────────────────────────────────────
class _TarjetaPedido extends StatefulWidget {
  final PedidoModel pedido;
  final bool enProceso;
  const _TarjetaPedido(
      {required this.pedido, required this.enProceso});
  @override
  State<_TarjetaPedido> createState() => _TarjetaPedidoState();
}

class _TarjetaPedidoState extends State<_TarjetaPedido> {
  bool _expandido = false;

  Color get _colorEstado {
    switch (widget.pedido.estado) {
      case 'Pendiente':  return Colors.orange;
      case 'Preparando': return Colors.blue;
      case 'Listo':      return Colors.teal;
      case 'En camino':  return Colors.indigo;
      case 'Entregado':  return Colors.green;
      case 'Cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  String get _emojiEstado {
    switch (widget.pedido.estado) {
      case 'Pendiente':  return '⏳';
      case 'Preparando': return '👨‍🍳';
      case 'Listo':      return '✅';
      case 'En camino':  return '🛵';
      case 'Entregado':  return '📦';
      case 'Cancelado':  return '❌';
      default:           return '📋';
    }
  }

  // ── Repetir pedido ──
  Future<void> _repetirPedido(BuildContext context) async {
    final carrito =
        Provider.of<CarritoProvider>(context, listen: false);
    final p = widget.pedido;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('🔁 Repetir pedido',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Se agregarán ${p.items.length} producto(s) al carrito.\n¿Continuar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white),
              child: const Text('Agregar al carrito')),
        ],
      ),
    );

    if (confirmar != true) return;

    for (final item in p.items) {
      carrito.agregarProducto({
        'id': item['productoId'] ?? '',
        'nombre': item['productoNombre'] ?? item['nombre'] ?? '',
        'precio': (item['precioUnitario'] ?? 0.0),
        'cantidad': item['cantidad'] ?? 1,
        'imagen': item['imagen'] ?? '',
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🛒 ${p.items.length} producto(s) agregados al carrito'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Ver carrito',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.pedido;
    final color = _colorEstado;
    final fecha =
        '${p.fecha.day.toString().padLeft(2, '0')}/${p.fecha.month.toString().padLeft(2, '0')} '
        '${p.fecha.hour.toString().padLeft(2, '0')}:${p.fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(children: [
        // ── Cabecera ──
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(_emojiEstado,
                        style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                        p.tipoPedido == 'mesa'
                            ? '🍽️ Mesa ${p.numeroMesa}'
                            : '🛵 Domicilio',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      )),
                      Text('\$${p.total.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.estado,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(fecha,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const Spacer(),
                      Text('${p.items.length} producto(s)',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ]),
                  ])),
              const SizedBox(width: 8),
              Icon(
                  _expandido
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white38,
                  size: 20),
            ]),
          ),
        ),

        // ── Detalle expandible ──
        if (_expandido) ...[
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Items
              ...p.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                            child: Text('${item['cantidad'] ?? 1}',
                                style: const TextStyle(
                                    color: Color(0xFFFF6B35),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        item['productoNombre'] ?? item['nombre'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      )),
                      Text(
                          '\$${((item['precioTotal'] ?? item['precioUnitario'] ?? 0.0)).toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ]),
                  )),

              const Divider(color: Colors.white10, height: 16),

              // Totales
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12)),
                    Text('\$${p.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
              const SizedBox(height: 3),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text('\$${p.total.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ]),

              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.payment,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(p.metodoPago,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ]),

              // Dirección si es domicilio
              if (p.tipoPedido == 'domicilio' &&
                  p.direccionEntrega != null &&
                  (p.direccionEntrega!['direccion'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          p.direccionEntrega!['direccion']?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12))),
                ]),
              ],

              // Código verificación
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          const Color(0xFFFF6B35).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Text('🔑',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Código de verificación',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        Text((p.codigoVerificacion ?? '----'),
                            style: const TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4)),
                      ])),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        color: Colors.white38, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: (p.codigoVerificacion ?? '----')));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Código copiado'),
                              duration: Duration(seconds: 1)));
                    },
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Botones de acción
              Row(children: [
                // Repetir pedido
                if (p.estado == 'Entregado')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _repetirPedido(context),
                      icon: const Icon(Icons.refresh,
                          size: 15, color: Color(0xFFFF6B35)),
                      label: const Text('Repetir',
                          style: TextStyle(
                              color: Color(0xFFFF6B35),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFFF6B35)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                if (p.estado == 'Entregado')
                  const SizedBox(width: 8),

                // Tracking
                if (p.estado == 'En camino' &&
                    p.tipoPedido == 'domicilio' &&
                    p.repartidorId != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TrackingClientePage(pedido: p))),
                      icon: const Text('🛵',
                          style: TextStyle(fontSize: 14)),
                      label: const Text('Ver en mapa',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                // Calificar
                if (p.estado == 'Entregado')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CalificacionPage(pedido: p))),
                      icon: const Icon(Icons.star,
                          size: 15, color: Colors.white),
                      label: const Text('Calificar',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}
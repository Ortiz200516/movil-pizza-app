// ===== C:\Users\amame\movil-pizza-app\lib\home\home_admin.dart =====
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';
import '../services/categoria_service.dart';
import '../services/producto_service.dart';
import '../models/categoria_model.dart';
import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../admin/usuarios_page.dart';
import '../admin/pedidos_admin_page.dart';
import '../admin/reportes_page.dart';
import '../admin/mesas_admin_page.dart';
import '../admin/disponibilidad_page.dart';
import '../admin/dashboard_page.dart';
import '../admin/cupones_page.dart';
import '../admin/info_local_admin_page.dart';
import '../admin/cierre_caja_page.dart';
import '../admin/reservas_admin_page.dart';
import '../services/fidelidad_service.dart';

const _estadosActivos = ['Pendiente', 'Preparando', 'Listo', 'En camino'];

Color _colorEstado(String estado) {
  switch (estado) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return Colors.blue;
    case 'Listo':      return Colors.purple;
    case 'En camino':  return Colors.indigo;
    case 'Entregado':  return Colors.green;
    case 'Cancelado':  return Colors.red;
    default:           return Colors.grey;
  }
}

IconData _iconoEstado(String estado) {
  switch (estado) {
    case 'Pendiente':  return Icons.access_time;
    case 'Preparando': return Icons.restaurant;
    case 'Listo':      return Icons.done_all;
    case 'En camino':  return Icons.delivery_dining;
    case 'Entregado':  return Icons.check_circle;
    case 'Cancelado':  return Icons.cancel;
    default:           return Icons.help_outline;
  }
}

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});
  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  final AuthService _authService = AuthService();
  final CategoriaService _categoriaService = CategoriaService();
  final ProductoService _productoService = ProductoService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> iconosDisponibles = [
    'ðŸ•', 'ðŸ”', 'ðŸŒ®', 'ðŸ—', 'ðŸ¥¤', 'ðŸº', 'ðŸ°', 'ðŸª',
    'ðŸ¥—', 'ðŸ', 'ðŸŸ', 'ðŸŒ­', 'ðŸ¥ª', 'ðŸ©', 'â˜•', 'ðŸ§ƒ'
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 12,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          title: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('pedidos')
                .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
                .snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Row(children: [
                const Text('ðŸ‘¨â€ðŸ’¼ Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (count > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5))),
                    child: Text('$count activos',
                      style: const TextStyle(color: Colors.red,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]);
            },
          ),
          backgroundColor: const Color(0xFF581C87),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.category, size: 20), text: 'CategorÃ­as'),
              Tab(icon: Icon(Icons.inventory, size: 20), text: 'Productos'),
              Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Pedidos'),
              Tab(icon: Icon(Icons.bar_chart, size: 20), text: 'Reportes'),
              Tab(icon: Icon(Icons.table_restaurant, size: 20), text: 'Mesas'),
              Tab(icon: Icon(Icons.toggle_on, size: 20), text: 'Disponibilidad'),
              Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Dashboard'),
              Tab(icon: Icon(Icons.local_offer, size: 20), text: 'Cupones'),
              Tab(icon: Icon(Icons.store_outlined, size: 20), text: 'Info Local'),
              Tab(icon: Icon(Icons.point_of_sale, size: 20), text: 'Caja'),
              Tab(icon: Icon(Icons.stars_rounded, size: 20), text: 'Fidelidad'),
              Tab(icon: Icon(Icons.table_restaurant, size: 20), text: 'Reservas'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'Gestionar Usuarios',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UsuariosPage())),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar SesiÃ³n',
              onPressed: () async {
                await _authService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
          ],
        ),
        drawer: _buildDashboardDrawer(),
        body: TabBarView(
          children: [
            _buildCategoriasTab(),
            _buildProductosTab(),
            PedidosAdminPage(),
            ReportesPage(),
            MesasAdminPage(),
            DisponibilidadPage(),
            DashboardPage(),
            CuponesPage(),
            const InfoLocalAdminPage(),
            const CierreCajaPage(),
            const _FidelidadAdminTab(),
            const ReservasAdminPage(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tab,
              builder: (context, _) {
                if (tab.index == 0) {
                  return FloatingActionButton.extended(
                    onPressed: _mostrarDialogoAgregarCategoria,
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar CategorÃ­a'),
                  );
                } else if (tab.index == 1) {
                  return FloatingActionButton.extended(
                    onPressed: _mostrarDialogoAgregarProducto,
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Producto'),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  // â”€â”€ Drawer oscuro â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDashboardDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF581C87), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.dashboard, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              const Text('Panel en Tiempo Real',
                  style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_authService.currentUserEmail ?? '',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('ðŸ‘¨â€ðŸ³ Cocina',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              _buildCocinaStatus(),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              const Text('ðŸ›µ Repartidores',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              _buildRepartidoresStatus(),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              const Text('ðŸ“¦ Pedidos Recientes',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              _buildPedidosRecientes(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCocinaStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Pendiente', 'Preparando'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _LoadingCard();
        final pedidos = snapshot.data!.docs;
        final enPreparacion =
            pedidos.where((p) => p['estado'] == 'Preparando').length;
        final pendientes =
            pedidos.where((p) => p['estado'] == 'Pendiente').length;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.restaurant, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text('$enPreparacion en preparaciÃ³n',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.pending, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              Text('$pendientes pendientes',
                  style: const TextStyle(color: Colors.white60)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildRepartidoresStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', isEqualTo: 'En camino')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _LoadingCard();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.delivery_dining, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('No hay entregas en camino',
                  style: TextStyle(color: Colors.white60)),
            ]),
          );
        }
        return Column(
          children: docs.map((doc) {
            final repartidorId = doc['repartidorId'];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users').doc(repartidorId).get(),
              builder: (context, snap) {
                final nombre = snap.hasData
                    ? snap.data!['email']?.split('@')[0] ?? 'Repartidor'
                    : 'Repartidor';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.indigo.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Icon(
                          Icons.delivery_dining,
                          color: Colors.indigo, size: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(nombre, style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('Entregando pedido',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.indigo.withValues(alpha: 0.5)),
                      ),
                      child: const Text('En camino',
                          style: TextStyle(
                              color: Colors.indigo,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPedidosRecientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .orderBy('fecha', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _LoadingCard();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('No hay pedidos recientes',
                style: TextStyle(color: Colors.white60)),
          );
        }
        return Column(
          children: docs.map((doc) {
            final p = PedidoModel.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>);
            final color = _colorEstado(p.estado);
            final diff = DateTime.now().difference(p.fecha);
            final tiempo = diff.inMinutes < 60
                ? '${diff.inMinutes}m'
                : diff.inHours < 24
                    ? '${diff.inHours}h'
                    : '${diff.inDays}d';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Icon(_iconoEstado(p.estado),
                      color: color, size: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('\$${p.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${p.items.length} items Â· ${p.estado}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ])),
                Text(tiempo,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  // â”€â”€ Tab CategorÃ­as â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCategoriasTab() {
    return StreamBuilder<List<CategoriaModel>>(
      stream: _categoriaService.obtenerCategorias(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.purple));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(
            icono: Icons.category,
            mensaje: 'No hay categorÃ­as creadas',
            sub: 'Toca el botÃ³n âž• para agregar tu primera categorÃ­a',
          );
        }
        final cats = snapshot.data!;
        final disponibles = cats.where((c) => c.disponible).length;
        return Column(children: [
          _StatsHeader(stats: [
            _StatData('Total', cats.length.toString(),
                Icons.category, Colors.purple),
            _StatData('Visibles', disponibles.toString(),
                Icons.check_circle, Colors.green),
            _StatData('Ocultas', (cats.length - disponibles).toString(),
                Icons.visibility_off, Colors.orange),
          ]),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: cats.length,
              itemBuilder: (_, i) => _buildCategoriaCard(cats[i]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildCategoriaCard(CategoriaModel cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: cat.disponible
                ? Colors.purple.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarDialogoEditarCategoria(cat),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: cat.disponible
                    ? Colors.purple.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(cat.icono,
                      style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(cat.nombre, style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Chip(cat.disponible ? 'Visible' : 'Oculta',
                      cat.disponible ? Colors.green : Colors.orange),
                  _Chip('Orden: ${cat.orden}', Colors.blue),
                  if (cat.requiereCocina) _Chip('Cocina', Colors.purple),
                ]),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmarEliminarCategoria(cat),
            ),
          ]),
        ),
      ),
    );
  }

  // â”€â”€ Tab Productos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildProductosTab() {
    return StreamBuilder<List<ProductoModel>>(
      stream: _productoService.obtenerProductos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.purple));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(
            icono: Icons.inventory,
            mensaje: 'No hay productos creados',
            sub: 'Toca el botÃ³n âž• para agregar tu primer producto',
          );
        }
        final prods = snapshot.data!;
        final disponibles = prods.where((p) => p.disponible).length;
        return Column(children: [
          _StatsHeader(stats: [
            _StatData('Total', prods.length.toString(),
                Icons.inventory, Colors.purple),
            _StatData('Disponibles', disponibles.toString(),
                Icons.check_circle, Colors.green),
            _StatData('Agotados', (prods.length - disponibles).toString(),
                Icons.remove_circle, Colors.red),
          ]),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: prods.length,
              itemBuilder: (_, i) => _buildProductoCard(prods[i]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildProductoCard(ProductoModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: p.disponible
                ? Colors.purple.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarDialogoEditarProducto(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: p.disponible
                    ? Colors.purple.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(p.icono,
                      style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.nombre, style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(p.descripcion,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Chip('\$${p.precio.toStringAsFixed(2)}', Colors.green),
                  _Chip(p.categoria, Colors.blue),
                  if (!p.disponible) _Chip('Agotado', Colors.red),
                ]),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmarEliminarProducto(p),
            ),
          ]),
        ),
      ),
    );
  }

  // â”€â”€ DiÃ¡logos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _mostrarDialogoAgregarCategoria() {
    final nombreCtrl = TextEditingController();
    String iconoSel = iconosDisponibles[0];
    int orden = 0;
    bool requiereCocina = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('âž• Agregar CategorÃ­a',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.category),
              const SizedBox(height: 14),
              const Text('Selecciona un icono:',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectorIconos(iconoSel, (i) => setD(() => iconoSel = i)),
              const SizedBox(height: 14),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Orden de apariciÃ³n',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.sort, color: Colors.purple),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => orden = int.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Requiere cocina',
                    style: TextStyle(color: Colors.white70)),
                value: requiereCocina,
                activeColor: Colors.purple,
                onChanged: (v) => setD(() => requiereCocina = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreCtrl.text.isEmpty) return;
                await _categoriaService.agregarCategoria(CategoriaModel(
                  id: '', nombre: nombreCtrl.text, icono: iconoSel,
                  disponible: true, orden: orden,
                  requiereCocina: requiereCocina,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('âœ… CategorÃ­a agregada', Colors.green);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarCategoria(CategoriaModel cat) {
    final nombreCtrl = TextEditingController(text: cat.nombre);
    String iconoSel = cat.icono;
    int orden = cat.orden;
    bool disponible = cat.disponible;
    bool requiereCocina = cat.requiereCocina;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('âœï¸ Editar CategorÃ­a',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.category),
              const SizedBox(height: 14),
              const Text('Icono:',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectorIconos(iconoSel, (i) => setD(() => iconoSel = i)),
              const SizedBox(height: 14),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Orden',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.sort, color: Colors.purple),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple)),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: orden.toString()),
                onChanged: (v) => orden = int.tryParse(v) ?? 0,
              ),
              SwitchListTile(
                title: const Text('Visible',
                    style: TextStyle(color: Colors.white70)),
                value: disponible,
                activeColor: Colors.purple,
                onChanged: (v) => setD(() => disponible = v),
              ),
              SwitchListTile(
                title: const Text('Requiere cocina',
                    style: TextStyle(color: Colors.white70)),
                value: requiereCocina,
                activeColor: Colors.purple,
                onChanged: (v) => setD(() => requiereCocina = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white),
              onPressed: () async {
                await _categoriaService.editarCategoria(
                    cat.id,
                    CategoriaModel(
                      id: cat.id, nombre: nombreCtrl.text,
                      icono: iconoSel, disponible: disponible,
                      orden: orden, requiereCocina: requiereCocina,
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('âœ… CategorÃ­a actualizada', Colors.green);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCategoria(CategoriaModel cat) async {
    final ok = await _confirmar('Â¿Eliminar la categorÃ­a "${cat.nombre}"?');
    if (ok) {
      await _categoriaService.eliminarCategoria(cat.id);
      _snack('âœ… CategorÃ­a eliminada', Colors.green);
    }
  }

  void _mostrarDialogoAgregarProducto() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final descCtrl   = TextEditingController();
    String? catSel;
    final categorias = await _categoriaService.obtenerCategorias().first;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('âž• Agregar Producto',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.fastfood),
              const SizedBox(height: 12),
              _campo(descCtrl, 'DescripciÃ³n', Icons.description, maxLines: 3),
              const SizedBox(height: 12),
              _campo(precioCtrl, 'Precio', Icons.attach_money,
                  tipo: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'CategorÃ­a',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.category, color: Colors.purple),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple)),
                ),
                items: categorias.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(children: [
                    Text(c.icono, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(c.nombre,
                        style: const TextStyle(color: Colors.white)),
                  ]),
                )).toList(),
                onChanged: (v) => setD(() => catSel = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreCtrl.text.isEmpty ||
                    precioCtrl.text.isEmpty ||
                    catSel == null) {
                  _snack('âš ï¸ Completa todos los campos', Colors.orange);
                  return;
                }
                final categoria =
                    categorias.firstWhere((c) => c.id == catSel);
                await _productoService.agregarProducto(ProductoModel(
                  id: '', nombre: nombreCtrl.text.trim(),
                  precio: double.tryParse(
                          precioCtrl.text.replaceAll(',', '.')) ??
                      0,
                  descripcion: descCtrl.text.trim(),
                  disponible: true,
                  categoria: categoria.nombre,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('âœ… Producto agregado', Colors.green);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(ProductoModel prod) async {
    final nombreCtrl =
        TextEditingController(text: prod.nombre);
    final precioCtrl =
        TextEditingController(text: prod.precio.toString());
    final descCtrl   = TextEditingController(text: prod.descripcion);
    String catSel    = prod.categoria;
    bool disponible  = prod.disponible;
    final categorias = await _categoriaService.obtenerCategorias().first;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('âœï¸ Editar Producto',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.fastfood),
              const SizedBox(height: 12),
              _campo(descCtrl, 'DescripciÃ³n', Icons.description,
                  maxLines: 3),
              const SizedBox(height: 12),
              _campo(precioCtrl, 'Precio', Icons.attach_money,
                  tipo: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'CategorÃ­a',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon:
                      Icon(Icons.category, color: Colors.purple),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple)),
                ),
                initialValue:
                    categorias.any((c) => c.nombre == catSel)
                        ? catSel
                        : null,
                items: categorias.map((c) => DropdownMenuItem(
                  value: c.nombre,
                  child: Row(children: [
                    Text(c.icono, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(c.nombre,
                        style: const TextStyle(color: Colors.white)),
                  ]),
                )).toList(),
                onChanged: (v) => setD(() => catSel = v ?? catSel),
              ),
              SwitchListTile(
                title: const Text('Disponible',
                    style: TextStyle(color: Colors.white70)),
                value: disponible,
                activeColor: Colors.purple,
                onChanged: (v) => setD(() => disponible = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white),
              onPressed: () async {
                await _productoService.editarProducto(
                    prod.id,
                    ProductoModel(
                      id: prod.id, nombre: nombreCtrl.text,
                      precio:
                          double.tryParse(precioCtrl.text) ?? prod.precio,
                      descripcion: descCtrl.text,
                      disponible: disponible,
                      categoria: catSel,
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('âœ… Producto actualizado', Colors.green);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarProducto(ProductoModel p) async {
    final ok = await _confirmar('Â¿Eliminar "${p.nombre}"?');
    if (ok) {
      await _productoService.eliminarProducto(p.id);
      _snack('âœ… Producto eliminado', Colors.green);
    }
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.purple),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.purple)),
      ),
    );
  }

  Widget _selectorIconos(String sel, void Function(String) onChange) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: iconosDisponibles.map((i) {
        final isSel = i == sel;
        return InkWell(
          onTap: () => onChange(i),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: isSel
                  ? Colors.purple.withValues(alpha: 0.25)
                  : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isSel ? Colors.purple : Colors.white24,
                  width: 2),
            ),
            child: Center(
                child: Text(i, style: const TextStyle(fontSize: 22))),
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _confirmar(String mensaje) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('âš ï¸ Confirmar',
                style: TextStyle(color: Colors.white)),
            content: Text(mensaje,
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.white38))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

// â”€â”€â”€ WIDGETS AUXILIARES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
        child: CircularProgressIndicator(
            color: Colors.purple, strokeWidth: 2)),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icono;
  final String mensaje, sub;
  const _EmptyState(
      {required this.icono, required this.mensaje, required this.sub});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icono, size: 100, color: Colors.white10),
      const SizedBox(height: 16),
      Text(mensaje,
          style: const TextStyle(
              fontSize: 20,
              color: Colors.white38,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(sub, style: const TextStyle(color: Colors.white24)),
    ]),
  );
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatsHeader extends StatelessWidget {
  final List<_StatData> stats;
  const _StatsHeader({required this.stats});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    color: const Color(0xFF0F172A),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: stats.map((s) => Expanded(
        child: Column(children: [
          Icon(s.icon, color: s.color, size: 28),
          const SizedBox(height: 6),
          Text(s.value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: s.color)),
          const SizedBox(height: 2),
          Text(s.label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white54)),
        ]),
      )).toList(),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );
}

// ── Tab de fidelidad en admin ─────────────────────────────────────────────────
class _FidelidadAdminTab extends StatefulWidget {
  const _FidelidadAdminTab();
  @override
  State<_FidelidadAdminTab> createState() => _FidelidadAdminTabState();
}

class _FidelidadAdminTabState extends State<_FidelidadAdminTab> {
  final _svc = FidelidadService();
  final _uidCtrl   = TextEditingController();
  final _ptsCtrl   = TextEditingController();
  final _motivoCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _uidCtrl.dispose(); _ptsCtrl.dispose(); _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _darPuntos() async {
    final uid    = _uidCtrl.text.trim();
    final pts    = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    final motivo = _motivoCtrl.text.trim();
    if (uid.isEmpty || pts <= 0) return;
    setState(() => _enviando = true);
    try {
      await _svc.darPuntosManual(uid, pts, motivo.isEmpty ? 'Puntos otorgados por admin' : motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⭐ +$pts puntos otorgados'),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
      ));
      _uidCtrl.clear(); _ptsCtrl.clear(); _motivoCtrl.clear();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const kCard = Color(0xFF1E293B);
    const kCard2 = Color(0xFF263348);
    const kNaranja = Color(0xFFFF6B35);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Resumen niveles ────────────────────────────────────────────────
        const Text('NIVELES DE FIDELIDAD', style: TextStyle(
            color: Colors.white38, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...kNiveles.map((n) {
          final color = Color(int.parse('FF${n.colorHex}', radix: 16));
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Text(n.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.nombre, style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(n.puntosMax == -1
                    ? '${n.puntosMin}+ pts'
                    : '${n.puntosMin}–${n.puntosMax} pts',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ])),
              Text('×${n.multiplicador}',
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          );
        }),
        const SizedBox(height: 20),

        // ── Otorgar puntos manualmente ─────────────────────────────────────
        const Text('OTORGAR PUNTOS', style: TextStyle(
            color: Colors.white38, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(children: [
            _AdminField(_uidCtrl, 'UID del usuario (de Firestore)', Icons.person),
            const SizedBox(height: 10),
            _AdminField(_ptsCtrl, 'Puntos a otorgar', Icons.stars, isNum: true),
            const SizedBox(height: 10),
            _AdminField(_motivoCtrl, 'Motivo (opcional)', Icons.edit_note),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _enviando ? null : _darPuntos,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kNaranja.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: _enviando
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('⭐ Otorgar puntos',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 14))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('💡 El UID lo encuentras en Firestore → users → ID del documento',
            style: const TextStyle(color: Colors.white24, fontSize: 11)),
      ],
    );
  }
}

Widget _AdminField(
    TextEditingController ctrl, String hint, IconData icon,
    {bool isNum = false}) {
  return TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white24, size: 18),
      filled: true,
      fillColor: const Color(0xFF263348),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
    ),
  );
}
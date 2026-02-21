import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';
import '../services/categoria_service.dart';
import '../services/producto_service.dart';
import '../models/categoria_model.dart';
import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../auth/login_page.dart';
import '../admin/usuarios_page.dart';
import '../admin/pedidos_admin_page.dart';
import '../admin/reportes_page.dart';
import '../admin/mesas_admin_page.dart';
import '../admin/disponibilidad_page.dart';

const _estadosActivos = ['Pendiente', 'Preparando', 'Listo', 'En camino'];

Color _colorEstado(String estado) {
  switch (estado) {
    case 'Pendiente':    return Colors.orange;
    case 'Preparando':   return Colors.blue;
    case 'Listo':        return Colors.purple;
    case 'En camino':    return Colors.indigo;
    case 'Entregado':    return Colors.green;
    case 'Cancelado':    return Colors.red;
    default:             return Colors.grey;
  }
}

IconData _iconoEstado(String estado) {
  switch (estado) {
    case 'Pendiente':    return Icons.access_time;
    case 'Preparando':   return Icons.restaurant;
    case 'Listo':        return Icons.done_all;
    case 'En camino':    return Icons.delivery_dining;
    case 'Entregado':    return Icons.check_circle;
    case 'Cancelado':    return Icons.cancel;
    default:             return Icons.help_outline;
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
    '🍕', '🍔', '🌮', '🍗', '🥤', '🍺', '🍰', '🍪',
    '🥗', '🍝', '🍟', '🌭', '🥪', '🍩', '☕', '🧃'
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('👨‍💼 Panel Administrador'),
          backgroundColor: Colors.purple,
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
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.category, size: 20), text: 'Categorías'),
              Tab(icon: Icon(Icons.inventory, size: 20), text: 'Productos'),
              Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Pedidos'),
              Tab(icon: Icon(Icons.bar_chart, size: 20), text: 'Reportes'),
              Tab(icon: Icon(Icons.table_restaurant, size: 20), text: 'Mesas'),
              Tab(icon: Icon(Icons.toggle_on, size: 20), text: 'Disponibilidad'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'Gestionar Usuarios',
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const UsuariosPage())),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                await _authService.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const LoginPage()));
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
                    label: const Text('Agregar Categoría'),
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

  Widget _buildDashboardDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.dashboard, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text('Dashboard en Tiempo Real',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_authService.currentUserEmail ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('👨‍🍳 Cocina', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCocinaStatus(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('🛵 Repartidores', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildRepartidoresStatus(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('📦 Pedidos Recientes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildPedidosRecientes(),
              ],
            ),
          ),
        ],
      ),
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
        final enPreparacion = pedidos.where((p) => p['estado'] == 'Preparando').length;
        final pendientes = pedidos.where((p) => p['estado'] == 'Pendiente').length;
        return Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.restaurant, color: Colors.orange),
                const SizedBox(width: 8),
                Text('$enPreparacion en preparación', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.pending, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Text('$pendientes pendientes'),
              ]),
            ]),
          ),
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
          return Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.delivery_dining, color: Colors.blue),
                SizedBox(width: 8),
                Text('No hay entregas en camino'),
              ]),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final repartidorId = doc['repartidorId'];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(repartidorId).get(),
              builder: (context, snap) {
                final nombre = snap.hasData
                    ? snap.data!['email']?.split('@')[0] ?? 'Repartidor'
                    : 'Repartidor';
                return Card(
                  color: Colors.indigo.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.delivery_dining, color: Colors.white, size: 18),
                    ),
                    title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Entregando pedido', style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(10)),
                      child: const Text('En camino', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
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
          return Card(
            color: Colors.grey.shade50,
            child: const Padding(padding: EdgeInsets.all(14), child: Text('No hay pedidos recientes')),
          );
        }
        return Column(
          children: docs.map((doc) {
            final p = PedidoModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
            final color = _colorEstado(p.estado);
            final diff = DateTime.now().difference(p.fecha);
            final tiempo = diff.inMinutes < 60
                ? '${diff.inMinutes}m'
                : diff.inHours < 24 ? '${diff.inHours}h' : '${diff.inDays}d';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_iconoEstado(p.estado), color: color, size: 18),
                ),
                title: Text('\$${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${p.items.length} items · ${p.estado}',
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(tiempo,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoriasTab() {
    return StreamBuilder<List<CategoriaModel>>(
      stream: _categoriaService.obtenerCategorias(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(
            icono: Icons.category,
            mensaje: 'No hay categorías creadas',
            sub: 'Toca el botón ➕ para agregar tu primera categoría',
          );
        }
        final cats = snapshot.data!;
        final disponibles = cats.where((c) => c.disponible).length;
        return Column(children: [
          _StatsHeader(stats: [
            _StatData('Total', cats.length.toString(), Icons.category, Colors.purple),
            _StatData('Visibles', disponibles.toString(), Icons.check_circle, Colors.green),
            _StatData('Ocultas', (cats.length - disponibles).toString(), Icons.visibility_off, Colors.orange),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarDialogoEditarCategoria(cat),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: cat.disponible ? Colors.purple.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(cat.icono, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Chip(cat.disponible ? 'Visible' : 'Oculta', cat.disponible ? Colors.green : Colors.orange),
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

  Widget _buildProductosTab() {
    return StreamBuilder<List<ProductoModel>>(
      stream: _productoService.obtenerProductos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(
            icono: Icons.inventory,
            mensaje: 'No hay productos creados',
            sub: 'Toca el botón ➕ para agregar tu primer producto',
          );
        }
        final prods = snapshot.data!;
        final disponibles = prods.where((p) => p.disponible).length;
        return Column(children: [
          _StatsHeader(stats: [
            _StatData('Total', prods.length.toString(), Icons.inventory, Colors.purple),
            _StatData('Disponibles', disponibles.toString(), Icons.check_circle, Colors.green),
            _StatData('Agotados', (prods.length - disponibles).toString(), Icons.remove_circle, Colors.red),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarDialogoEditarProducto(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: p.disponible ? Colors.purple.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(p.icono, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(p.descripcion,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  void _mostrarDialogoAgregarCategoria() {
    final nombreCtrl = TextEditingController();
    String iconoSel = iconosDisponibles[0];
    int orden = 0;
    bool requiereCocina = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('➕ Agregar Categoría'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.category),
              const SizedBox(height: 14),
              const Text('Selecciona un icono:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectorIconos(iconoSel, (i) => setD(() => iconoSel = i)),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(labelText: 'Orden de aparición', prefixIcon: Icon(Icons.sort), border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => orden = int.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Requiere cocina'),
                value: requiereCocina,
                onChanged: (v) => setD(() => requiereCocina = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreCtrl.text.isEmpty) return;
                await _categoriaService.agregarCategoria(CategoriaModel(
                  id: '', nombre: nombreCtrl.text, icono: iconoSel,
                  disponible: true, orden: orden, requiereCocina: requiereCocina,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('✅ Categoría agregada', Colors.green);
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
          title: const Text('✏️ Editar Categoría'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.category),
              const SizedBox(height: 14),
              const Text('Icono:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectorIconos(iconoSel, (i) => setD(() => iconoSel = i)),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(labelText: 'Orden', prefixIcon: Icon(Icons.sort), border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: orden.toString()),
                onChanged: (v) => orden = int.tryParse(v) ?? 0,
              ),
              SwitchListTile(title: const Text('Visible'), value: disponible, onChanged: (v) => setD(() => disponible = v)),
              SwitchListTile(title: const Text('Requiere cocina'), value: requiereCocina, onChanged: (v) => setD(() => requiereCocina = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                await _categoriaService.editarCategoria(cat.id, CategoriaModel(
                  id: cat.id, nombre: nombreCtrl.text, icono: iconoSel,
                  disponible: disponible, orden: orden, requiereCocina: requiereCocina,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('✅ Categoría actualizada', Colors.green);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCategoria(CategoriaModel cat) async {
    final ok = await _confirmar('¿Eliminar la categoría "${cat.nombre}"?');
    if (ok) {
      await _categoriaService.eliminarCategoria(cat.id);
      _snack('✅ Categoría eliminada', Colors.green);
    }
  }

  void _mostrarDialogoAgregarProducto() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? catSel;
    final categorias = await _categoriaService.obtenerCategorias().first;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('➕ Agregar Producto'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.fastfood),
              const SizedBox(height: 12),
              _campo(descCtrl, 'Descripción', Icons.description, maxLines: 3),
              const SizedBox(height: 12),
              _campo(precioCtrl, 'Precio', Icons.attach_money, tipo: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.category), border: OutlineInputBorder()),
                value: catSel,
                items: categorias.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(children: [Text(c.icono, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8), Text(c.nombre)]),
                )).toList(),
                onChanged: (v) => setD(() => catSel = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty || catSel == null) {
                  _snack('⚠️ Completa todos los campos', Colors.orange);
                  return;
                }
                final categoria = categorias.firstWhere((c) => c.id == catSel);
                await _productoService.agregarProducto(ProductoModel(
                  id: '', nombre: nombreCtrl.text,
                  precio: double.tryParse(precioCtrl.text) ?? 0,
                  descripcion: descCtrl.text,
                  disponible: true,
                  categoria: categoria.nombre,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('✅ Producto agregado', Colors.green);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(ProductoModel prod) async {
    final nombreCtrl = TextEditingController(text: prod.nombre);
    final precioCtrl = TextEditingController(text: prod.precio.toString());
    final descCtrl = TextEditingController(text: prod.descripcion);
    String catSel = prod.categoria;
    bool disponible = prod.disponible;
    final categorias = await _categoriaService.obtenerCategorias().first;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('✏️ Editar Producto'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo(nombreCtrl, 'Nombre', Icons.fastfood),
              const SizedBox(height: 12),
              _campo(descCtrl, 'Descripción', Icons.description, maxLines: 3),
              const SizedBox(height: 12),
              _campo(precioCtrl, 'Precio', Icons.attach_money, tipo: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.category), border: OutlineInputBorder()),
                value: categorias.any((c) => c.id == catSel || c.nombre == catSel) ? catSel : null,
                items: categorias.map((c) => DropdownMenuItem(
                  value: c.nombre,
                  child: Row(children: [Text(c.icono, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8), Text(c.nombre)]),
                )).toList(),
                onChanged: (v) => setD(() => catSel = v!),
              ),
              SwitchListTile(
                title: const Text('Disponible'),
                value: disponible,
                onChanged: (v) => setD(() => disponible = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                await _productoService.editarProducto(prod.id, ProductoModel(
                  id: prod.id, nombre: nombreCtrl.text,
                  precio: double.tryParse(precioCtrl.text) ?? prod.precio,
                  descripcion: descCtrl.text,
                  disponible: disponible,
                  categoria: catSel,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('✅ Producto actualizado', Colors.green);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarProducto(ProductoModel p) async {
    final ok = await _confirmar('¿Eliminar "${p.nombre}"?');
    if (ok) {
      await _productoService.eliminarProducto(p.id);
      _snack('✅ Producto eliminado', Colors.green);
    }
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: tipo, maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
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
              color: isSel ? Colors.purple.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSel ? Colors.purple : Colors.grey.shade300, width: 2),
            ),
            child: Center(child: Text(i, style: const TextStyle(fontSize: 22))),
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _confirmar(String mensaje) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Confirmar'),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icono;
  final String mensaje, sub;
  const _EmptyState({required this.icono, required this.mensaje, required this.sub});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icono, size: 100, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(mensaje, style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(sub, style: TextStyle(color: Colors.grey.shade500)),
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
    color: Colors.purple.shade50,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: stats.map((s) => Expanded(
        child: Column(children: [
          Icon(s.icon, color: s.color, size: 28),
          const SizedBox(height: 6),
          Text(s.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: s.color)),
          const SizedBox(height: 2),
          Text(s.label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );
}
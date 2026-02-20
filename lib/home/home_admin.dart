import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';
import '../services/categoria_service.dart';
import '../services/producto_service.dart';
import '../models/categoria_model.dart';
import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../auth/login_page.dart';
import '../admin/usuarios_page.dart';

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

  // Lista de iconos disponibles para categorías
  final List<String> iconosDisponibles = [
    '🍕', '🍔', '🌮', '🍗', '🥤', '🍺', '🍰', '🍪',
    '🥗', '🍝', '🍟', '🌭', '🥪', '🍩', '☕', '🧃'
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Solo 2 pestañas: Categorías y Productos
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
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.category, size: 24), text: 'Categorías'),
              Tab(icon: Icon(Icons.inventory, size: 24), text: 'Productos'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'Gestionar Usuarios',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsuariosPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                await _authService.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
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
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final currentTab = tabController.index;
                
                String label;
                IconData icon;
                VoidCallback onPressed;
                
                switch (currentTab) {
                  case 0: // Categorías
                    label = 'Agregar Categoría';
                    icon = Icons.add;
                    onPressed = _mostrarDialogoAgregarCategoria;
                    break;
                  case 1: // Productos
                    label = 'Agregar Producto';
                    icon = Icons.add;
                    onPressed = _mostrarDialogoAgregarProducto;
                    break;
                  default:
                    return const SizedBox.shrink();
                }

                return FloatingActionButton.extended(
                  onPressed: onPressed,
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  icon: Icon(icon),
                  label: Text(label),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Dashboard en el Drawer
  Widget _buildDashboardDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
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
                  const Text(
                    'Dashboard en Tiempo Real',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _authService.currentUserEmail ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Dashboard Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Resumen de Cocina
                const Text(
                  '👨‍🍳 Cocina',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCocinaStatus(),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Resumen de Repartidores
                const Text(
                  '🛵 Repartidores',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildRepartidoresStatus(),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Pedidos Recientes
                const Text(
                  '📦 Pedidos Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
          .where('estado', whereIn: ['Pendiente', 'En preparación'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final pedidos = snapshot.data!.docs;
        final enPreparacion = pedidos.where((p) => p['estado'] == 'En preparación').length;
        final pendientes = pedidos.where((p) => p['estado'] == 'Pendiente').length;

        return Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '$enPreparacion en preparación',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.pending, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text('$pendientes pendientes'),
                  ],
                ),
              ],
            ),
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
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final pedidosEnCamino = snapshot.data!.docs;

        if (pedidosEnCamino.isEmpty) {
          return Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('No hay entregas en camino'),
                ],
              ),
            ),
          );
        }

        return Column(
          children: pedidosEnCamino.map((doc) {
            final repartidorId = doc['repartidorId'];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(repartidorId)
                  .get(),
              builder: (context, userSnap) {
                final repartidorNombre = userSnap.hasData 
                    ? userSnap.data!['email']?.split('@')[0] ?? 'Repartidor'
                    : 'Repartidor';

                return Card(
                  color: Colors.indigo.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.delivery_dining, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      repartidorNombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Entregando pedido',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'En camino',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
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
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final pedidos = snapshot.data!.docs;

        if (pedidos.isEmpty) {
          return Card(
            color: Colors.grey.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay pedidos recientes'),
            ),
          );
        }

        return Column(
          children: pedidos.map((doc) {
            final pedido = PedidoModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
            
            Color estadoColor = Colors.grey;
            if (pedido.estado == 'Pendiente') estadoColor = Colors.orange;
            if (pedido.estado == 'En preparación') estadoColor = Colors.blue;
            if (pedido.estado == 'Listo') estadoColor = Colors.purple;
            if (pedido.estado == 'En camino') estadoColor = Colors.indigo;
            if (pedido.estado == 'Entregado') estadoColor = Colors.green;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: estadoColor.withOpacity(0.2),
                  child: Icon(Icons.receipt, color: estadoColor, size: 20),
                ),
                title: Text(
                  '\$${pedido.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${pedido.items.length} items - ${pedido.estado}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  _formatTime(pedido.fecha),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatTime(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // ==================== PESTAÑA 1: CATEGORÍAS ====================
  Widget _buildCategoriasTab() {
    return StreamBuilder<List<CategoriaModel>>(
      stream: _categoriaService.obtenerCategorias(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category, size: 100, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No hay categorías creadas',
                  style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca el botón ➕ para agregar tu primera categoría',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final categorias = snapshot.data!;
        final disponibles = categorias.where((c) => c.disponible).length;

        return Column(
          children: [
            // Estadísticas
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.purple.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('Total', categorias.length.toString(), Icons.category, Colors.purple),
                  _buildStatCard('Disponibles', disponibles.toString(), Icons.check_circle, Colors.green),
                  _buildStatCard('Ocultas', (categorias.length - disponibles).toString(), Icons.visibility_off, Colors.orange),
                ],
              ),
            ),
            // Lista
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  return _buildCategoriaCard(categoria);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriaCard(CategoriaModel categoria) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarDialogoEditarCategoria(categoria),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: categoria.disponible ? Colors.purple.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    categoria.icono,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoria.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          categoria.disponible ? 'Visible' : 'Oculta',
                          categoria.disponible ? Colors.green : Colors.orange,
                        ),
                        _buildChip(
                          'Orden: ${categoria.orden}',
                          Colors.blue,
                        ),
                        if (categoria.requiereCocina)
                          _buildChip('Requiere cocina', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              // Acciones
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmarEliminarCategoria(categoria),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PESTAÑA 2: PRODUCTOS ====================
  Widget _buildProductosTab() {
    return StreamBuilder<List<ProductoModel>>(
      stream: _productoService.obtenerProductos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 100, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No hay productos creados',
                  style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca el botón ➕ para agregar tu primer producto',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final productos = snapshot.data!;
        final disponibles = productos.where((p) => p.disponible).length;

        return Column(
          children: [
            // Estadísticas
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.purple.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('Total', productos.length.toString(), Icons.inventory, Colors.purple),
                  _buildStatCard('Disponibles', disponibles.toString(), Icons.check_circle, Colors.green),
                  _buildStatCard('Agotados', (productos.length - disponibles).toString(), Icons.remove_circle, Colors.red),
                ],
              ),
            ),
            // Lista
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
                  return _buildProductoCard(producto);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductoCard(ProductoModel producto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarDialogoEditarProducto(producto),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: producto.disponible ? Colors.purple.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fastfood,
                  color: producto.disponible ? Colors.purple : Colors.grey,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      producto.descripcion,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          '\$${producto.precio.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                        if (producto.categoria.isNotEmpty)
                          _buildChip(
                            producto.categoria,
                            Colors.blue,
                          ),
                        
                          _buildChip('Varios tamaños', Colors.orange),
                        
                          _buildChip('Combo', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              // Acciones
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmarEliminarProducto(producto),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WIDGETS AUXILIARES ====================
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==================== DIÁLOGOS - CATEGORÍAS ====================
  void _mostrarDialogoAgregarCategoria() {
    final nombreCtrl = TextEditingController();
    String iconoSeleccionado = iconosDisponibles[0];
    int orden = 0;
    bool requiereCocina = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('➕ Agregar Categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Selecciona un icono:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconosDisponibles.map((icono) {
                    final isSelected = icono == iconoSeleccionado;
                    return InkWell(
                      onTap: () {
                        setStateDialog(() {
                          iconoSeleccionado = icono;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.purple : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(icono, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Orden de aparición',
                    prefixIcon: Icon(Icons.sort),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    orden = int.tryParse(value) ?? 0;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Requiere cocina'),
                  subtitle: const Text('Marca si los productos pasan por cocina'),
                  value: requiereCocina,
                  onChanged: (value) {
                    setStateDialog(() {
                      requiereCocina = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Ingresa un nombre')),
                  );
                  return;
                }

                try {
                  final categoria = CategoriaModel(
                    id: '',
                    nombre: nombreCtrl.text,
                    icono: iconoSeleccionado,
                    disponible: true,
                    orden: orden,
                    requiereCocina: requiereCocina,
                  );

                  await _categoriaService.agregarCategoria(categoria);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Categoría agregada'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarCategoria(CategoriaModel categoria) {
    final nombreCtrl = TextEditingController(text: categoria.nombre);
    String iconoSeleccionado = categoria.icono;
    int orden = categoria.orden;
    bool disponible = categoria.disponible;
    bool requiereCocina = categoria.requiereCocina;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('✏️ Editar Categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icono:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconosDisponibles.map((icono) {
                    final isSelected = icono == iconoSeleccionado;
                    return InkWell(
                      onTap: () {
                        setStateDialog(() {
                          iconoSeleccionado = icono;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.purple : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(icono, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Orden',
                    prefixIcon: Icon(Icons.sort),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: orden.toString()),
                  onChanged: (value) {
                    orden = int.tryParse(value) ?? 0;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Visible'),
                  value: disponible,
                  onChanged: (value) {
                    setStateDialog(() {
                      disponible = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Requiere cocina'),
                  value: requiereCocina,
                  onChanged: (value) {
                    setStateDialog(() {
                      requiereCocina = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final categoriaActualizada = CategoriaModel(
                    id: categoria.id,
                    nombre: nombreCtrl.text,
                    icono: iconoSeleccionado,
                    disponible: disponible,
                    orden: orden,
                    requiereCocina: requiereCocina,
                  );

                  await _categoriaService.editarCategoria(categoria.id, categoriaActualizada);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Categoría actualizada'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCategoria(CategoriaModel categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmar Eliminación'),
        content: Text('¿Eliminar la categoría "${categoria.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _categoriaService.eliminarCategoria(categoria.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Categoría eliminada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ==================== DIÁLOGOS - PRODUCTOS ====================
  void _mostrarDialogoAgregarProducto() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    String? categoriaSeleccionada;
    
    final categorias = await _categoriaService.obtenerCategorias().first;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('➕ Agregar Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.fastfood),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  value: categoriaSeleccionada,
                  items: categorias.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Row(
                        children: [
                          Text(cat.icono, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(cat.nombre),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      categoriaSeleccionada = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty || categoriaSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Completa todos los campos')),
                  );
                  return;
                }

                try {
                  final categoria = categorias.firstWhere((c) => c.id == categoriaSeleccionada);
                  
                  final producto = ProductoModel(
                    id: '',
                    nombre: nombreCtrl.text,
                    precio: double.parse(precioCtrl.text),
                    descripcion: descripcionCtrl.text,
                    disponible: true,
                    categoria: categoria.nombre,
                  );

                  await _productoService.agregarProducto(producto);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Producto agregado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(ProductoModel producto) async {
    final nombreCtrl = TextEditingController(text: producto.nombre);
    final precioCtrl = TextEditingController(text: producto.precio.toString());
    final descripcionCtrl = TextEditingController(text: producto.descripcion);
    String categoriaSeleccionada = producto.categoria;
    bool disponible = producto.disponible;
    
    final categorias = await _categoriaService.obtenerCategorias().first;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('✏️ Editar Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.fastfood),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  value: categoriaSeleccionada,
                  items: categorias.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Row(
                        children: [
                          Text(cat.icono, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(cat.nombre),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      categoriaSeleccionada = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Disponible'),
                  value: disponible,
                  onChanged: (value) {
                    setStateDialog(() {
                      disponible = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final categoria = categorias.firstWhere((c) => c.id == categoriaSeleccionada);
                  
                  final productoActualizado = ProductoModel(
                    id: producto.id,
                    nombre: nombreCtrl.text,
                    precio: double.parse(precioCtrl.text),
                    descripcion: descripcionCtrl.text,
                    disponible: disponible,
                    categoria: categoria.nombre,
                  );

                  await _productoService.editarProducto(producto.id, productoActualizado);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Producto actualizado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarProducto(ProductoModel producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmar Eliminación'),
        content: Text('¿Eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _productoService.eliminarProducto(producto.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Producto eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
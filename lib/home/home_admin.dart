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
import '../admin/dashboard_page.dart';
import '../admin/cupones_page.dart';
import '../admin/promociones_admin_page.dart';

// ── Colores ───────────────────────────────────────────────────────────────────
const _kPurple  = Color(0xFF7C3AED);
const _kPurple2 = Color(0xFF581C87);
const _kBg      = Color(0xFF0F172A);
const _kCard    = Color(0xFF1E293B);

Color _colorEstado(String e) {
  switch (e) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return Colors.blue;
    case 'Listo':      return Colors.purple;
    case 'En camino':  return Colors.indigo;
    case 'Entregado':  return Colors.green;
    case 'Cancelado':  return Colors.red;
    default:           return Colors.grey;
  }
}

IconData _iconoEstado(String e) {
  switch (e) {
    case 'Pendiente':  return Icons.access_time;
    case 'Preparando': return Icons.restaurant;
    case 'Listo':      return Icons.done_all;
    case 'En camino':  return Icons.delivery_dining;
    case 'Entregado':  return Icons.check_circle;
    case 'Cancelado':  return Icons.cancel;
    default:           return Icons.help_outline;
  }
}

// ── Secciones del admin ───────────────────────────────────────────────────────
enum _Sec {
  dashboard, categorias, productos, pedidos,
  mesas, disponibilidad, reportes, cupones, promociones, usuarios,
}

// ─────────────────────────────────────────────────────────────────────────────
class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});
  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  final _auth     = AuthService();
  final _catSvc   = CategoriaService();
  final _prodSvc  = ProductoService();
  final _scaffKey = GlobalKey<ScaffoldState>();

  _Sec _sec = _Sec.dashboard;

  final _iconos = [
    '🍕','🍔','🌮','🍗','🥤','🍺','🎂','🍪',
    '🥗','🍝','🍟','🌭','🥪','🍩','☕','🧃',
  ];

  String get _titulo {
    switch (_sec) {
      case _Sec.dashboard:      return '📊 Dashboard';
      case _Sec.categorias:     return '🗂️ Categorías';
      case _Sec.productos:      return '🍕 Productos';
      case _Sec.pedidos:        return '📋 Pedidos';
      case _Sec.mesas:          return '🪑 Mesas';
      case _Sec.disponibilidad: return '🟢 Disponibilidad';
      case _Sec.reportes:       return '📈 Reportes';
      case _Sec.cupones:        return '🎟️ Cupones';
      case _Sec.promociones:    return '🎉 Promociones';
      case _Sec.usuarios:       return '👥 Usuarios';
    }
  }

  Widget get _body {
    switch (_sec) {
      case _Sec.dashboard:      return const DashboardPage();
      case _Sec.categorias:     return _CategoriasTab(svc: _catSvc, iconos: _iconos);
      case _Sec.productos:      return _ProductosTab(prodSvc: _prodSvc, catSvc: _catSvc, iconos: _iconos);
      case _Sec.pedidos:        return PedidosAdminPage();
      case _Sec.mesas:          return const MesasAdminPage();
      case _Sec.disponibilidad: return const DisponibilidadPage();
      case _Sec.reportes:       return const ReportesPage();
      case _Sec.cupones:        return const CuponesPage();
      case _Sec.promociones:    return const PromocionesAdminPage();
      case _Sec.usuarios:       return const UsuariosPage();
    }
  }

  void _ir(_Sec s) {
    HapticFeedback.selectionClick();
    setState(() => _sec = s);
    _scaffKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffKey,
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      drawer: _AdminDrawer(actual: _sec, onIr: _ir),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_sec), child: _body),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPurple2,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffKey.currentState?.openDrawer(),
      ),
      title: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos')
            .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
            .snapshots(),
        builder: (_, snap) {
          final n = snap.data?.docs.length ?? 0;
          return Row(children: [
            Expanded(child: Text(_titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis)),
            if (n > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Text('$n urgentes', style: const TextStyle(
                    color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ]);
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            await _auth.logout();
            if (context.mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
            }
          },
        ),
      ],
    );
  }

  Widget? _buildFab() {
    if (_sec == _Sec.categorias) {
      return FloatingActionButton.extended(
        onPressed: () => _CategoriasTab.showAgregar(context, _catSvc, _iconos),
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      );
    }
    if (_sec == _Sec.productos) {
      return FloatingActionButton.extended(
        onPressed: () => _ProductosTab.showAgregar(context, _prodSvc, _catSvc),
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
      );
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDrawer extends StatelessWidget {
  final _Sec actual;
  final void Function(_Sec) onIr;
  const _AdminDrawer({required this.actual, required this.onIr});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _kBg,
      child: Column(children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 20, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPurple2, _kPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(child: Text('👨‍💼', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 12),
            const Text('Panel Admin', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const Text('La Italiana Pizzería', style: TextStyle(
                color: Colors.white54, fontSize: 12)),
          ]),
        ),

        // ── KPI rápido ───────────────────────────────────────────────────────
        _DrawerKpi(),

        const Divider(color: Colors.white10, height: 1),

        // ── Menú ─────────────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Item(emoji: '📊', label: 'Dashboard',
                  sec: _Sec.dashboard, actual: actual, onTap: onIr),

              _Separator('MENÚ'),
              _Item(emoji: '🗂️', label: 'Categorías',
                  sec: _Sec.categorias, actual: actual, onTap: onIr),
              _Item(emoji: '🍕', label: 'Productos',
                  sec: _Sec.productos, actual: actual, onTap: onIr),

              _Separator('OPERACIONES'),
              _Item(emoji: '📋', label: 'Pedidos',
                  sec: _Sec.pedidos, actual: actual, onTap: onIr, badge: true),
              _Item(emoji: '🪑', label: 'Mesas',
                  sec: _Sec.mesas, actual: actual, onTap: onIr),
              _Item(emoji: '🟢', label: 'Disponibilidad',
                  sec: _Sec.disponibilidad, actual: actual, onTap: onIr),

              _Separator('MARKETING'),
              _Item(emoji: '🎟️', label: 'Cupones',
                  sec: _Sec.cupones, actual: actual, onTap: onIr),
              _Item(emoji: '🎉', label: 'Promociones',
                  sec: _Sec.promociones, actual: actual, onTap: onIr),

              _Separator('ANALYTICS'),
              _Item(emoji: '📈', label: 'Reportes',
                  sec: _Sec.reportes, actual: actual, onTap: onIr),
              _Item(emoji: '👥', label: 'Usuarios',
                  sec: _Sec.usuarios, actual: actual, onTap: onIr),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.all(14),
          child: const Text('La Italiana v1.0  ·  Admin',
              style: TextStyle(color: Colors.white12, fontSize: 11)),
        ),
      ]),
    );
  }
}

class _DrawerKpi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pedidos')
          .where('estado', whereIn: [
        'Pendiente', 'Preparando', 'Listo', 'En camino'
      ]).snapshots(),
      builder: (_, s1) {
        final activos = s1.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pedidos')
              .where('estado', isEqualTo: 'Entregado').snapshots(),
          builder: (_, s2) {
            final now = DateTime.now();
            final hoy = (s2.data?.docs ?? []).where((d) {
              final ts = (d.data() as Map)['fecha'];
              try {
                final f = (ts as dynamic).toDate() as DateTime;
                return f.year == now.year && f.month == now.month && f.day == now.day;
              } catch (_) { return false; }
            });
            final ventas = hoy.fold(0.0, (s, d) =>
                s + (((d.data() as Map)['total'] as num?)?.toDouble() ?? 0));

            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                Expanded(child: Column(children: [
                  Text('$activos', style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 22)),
                  const Text('Activos', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
                Container(width: 1, height: 32, color: Colors.white12),
                Expanded(child: Column(children: [
                  Text('\$${ventas.toStringAsFixed(0)}', style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w900, fontSize: 22)),
                  const Text('Hoy', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
              ]),
            );
          },
        );
      },
    );
  }
}

class _Separator extends StatelessWidget {
  final String label;
  const _Separator(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 3),
    child: Text(label, style: const TextStyle(
        color: Colors.white24, fontSize: 10,
        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
  );
}

class _Item extends StatelessWidget {
  final String emoji, label;
  final _Sec sec, actual;
  final void Function(_Sec) onTap;
  final bool badge;
  const _Item({
    required this.emoji, required this.label,
    required this.sec, required this.actual,
    required this.onTap, this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final sel = sec == actual;
    Widget tile = GestureDetector(
      onTap: () => onTap(sec),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? _kPurple.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? _kPurple.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
              color: sel ? Colors.white : Colors.white60,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 14))),
          if (sel)
            const Icon(Icons.chevron_right, color: _kPurple, size: 16),
        ]),
      ),
    );

    if (!badge) return tile;

    return Stack(children: [
      tile,
      Positioned(
        right: 16, top: 4,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pedidos')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
              .snapshots(),
          builder: (_, snap) {
            final n = snap.data?.docs.length ?? 0;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$n', style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB CATEGORÍAS
// ─────────────────────────────────────────────────────────────────────────────
class _CategoriasTab extends StatelessWidget {
  final CategoriaService svc;
  final List<String> iconos;
  const _CategoriasTab({required this.svc, required this.iconos});

  static void showAgregar(BuildContext ctx, CategoriaService svc, List<String> iconos) {
    final nombreCtrl = TextEditingController();
    String iconoSel  = '🍕';
    int orden        = 0;
    bool cocina      = true;

    showDialog(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => _AdminDialog(
          titulo: '➕ Nueva Categoría',
          onGuardar: () async {
            if (nombreCtrl.text.isEmpty) return;
            await svc.agregarCategoria(CategoriaModel(
              id: '', nombre: nombreCtrl.text.trim(),
              icono: iconoSel, orden: orden,
              disponible: true, requiereCocina: cocina,
            ));
            if (dctx.mounted) Navigator.pop(dctx);
          },
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _Campo(ctrl: nombreCtrl, label: 'Nombre', icon: Icons.category),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Icono:', style: TextStyle(color: Colors.white54, fontSize: 13))),
            const SizedBox(height: 8),
            _IconPicker(iconos: iconos, sel: iconoSel,
                onChange: (i) => setD(() => iconoSel = i)),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Orden:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.remove, color: Colors.white38, size: 20),
                  onPressed: () => setD(() => orden = (orden - 1).clamp(0, 99))),
              Text('$orden', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(icon: const Icon(Icons.add, color: Colors.white38, size: 20),
                  onPressed: () => setD(() => orden++)),
            ]),
            SwitchListTile(
              title: const Text('Requiere cocina',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              value: cocina, activeColor: _kPurple,
              onChanged: (v) => setD(() => cocina = v),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoriaModel>>(
      stream: svc.obtenerCategorias(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kPurple));
        }
        final cats = snap.data ?? [];
        if (cats.isEmpty) {
          return const _EmptyState(icono: Icons.category,
              msg: 'Sin categorías', sub: 'Toca ➕ para crear la primera');
        }
        final vis = cats.where((c) => c.disponible).length;
        return Column(children: [
          _StatsBar(items: [
            _Stat('Total',    '${cats.length}', Icons.category,     _kPurple),
            _Stat('Visibles', '$vis',           Icons.check_circle, Colors.green),
            _Stat('Ocultas',  '${cats.length - vis}', Icons.visibility_off, Colors.orange),
          ]),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: cats.length,
              itemBuilder: (_, i) => _CatCard(cat: cats[i], svc: svc, iconos: iconos),
            ),
          ),
        ]);
      },
    );
  }
}

class _CatCard extends StatelessWidget {
  final CategoriaModel cat;
  final CategoriaService svc;
  final List<String> iconos;
  const _CatCard({required this.cat, required this.svc, required this.iconos});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.disponible
            ? _kPurple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditar(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: cat.disponible
                    ? _kPurple.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(cat.icono,
                  style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.nombre, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _ChipTag(cat.disponible ? 'Visible' : 'Oculta',
                    cat.disponible ? Colors.green : Colors.orange),
                _ChipTag('Orden ${cat.orden}', Colors.blue),
                if (cat.requiereCocina) _ChipTag('Cocina', _kPurple),
              ]),
            ])),
            PopupMenuButton<String>(
              color: _kCard,
              icon: const Icon(Icons.more_vert, color: Colors.white38),
              onSelected: (v) async {
                if (v == 'edit') _showEditar(context);
                if (v == 'toggle') {
                  await svc.editarCategoria(cat.id,
                      CategoriaModel(id: cat.id, nombre: cat.nombre,
                          icono: cat.icono, orden: cat.orden,
                          disponible: !cat.disponible,
                          requiereCocina: cat.requiereCocina));
                }
                if (v == 'del') {
                  final ok = await _confirm(context, '¿Eliminar "${cat.nombre}"?');
                  if (ok) await svc.eliminarCategoria(cat.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit, color: Colors.white54),
                        title: Text('Editar', style: TextStyle(color: Colors.white)))),
                PopupMenuItem(value: 'toggle',
                    child: ListTile(
                        leading: Icon(
                            cat.disponible ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54),
                        title: Text(cat.disponible ? 'Ocultar' : 'Mostrar',
                            style: const TextStyle(color: Colors.white)))),
                const PopupMenuItem(value: 'del',
                    child: ListTile(leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Eliminar', style: TextStyle(color: Colors.red)))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditar(BuildContext context) {
    final nombreCtrl = TextEditingController(text: cat.nombre);
    String iconoSel  = cat.icono;
    int orden        = cat.orden;
    bool disponible  = cat.disponible;
    bool cocina      = cat.requiereCocina;

    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => _AdminDialog(
          titulo: '✏️ Editar Categoría',
          onGuardar: () async {
            await svc.editarCategoria(cat.id, CategoriaModel(
              id: cat.id, nombre: nombreCtrl.text.trim(),
              icono: iconoSel, orden: orden,
              disponible: disponible, requiereCocina: cocina,
            ));
            if (dctx.mounted) Navigator.pop(dctx);
          },
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _Campo(ctrl: nombreCtrl, label: 'Nombre', icon: Icons.category),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Icono:', style: TextStyle(color: Colors.white54, fontSize: 13))),
            const SizedBox(height: 8),
            _IconPicker(iconos: iconos, sel: iconoSel,
                onChange: (i) => setD(() => iconoSel = i)),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Orden:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.remove, color: Colors.white38, size: 20),
                  onPressed: () => setD(() => orden = (orden - 1).clamp(0, 99))),
              Text('$orden', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(icon: const Icon(Icons.add, color: Colors.white38, size: 20),
                  onPressed: () => setD(() => orden++)),
            ]),
            SwitchListTile(
              title: const Text('Visible', style: TextStyle(color: Colors.white70, fontSize: 14)),
              value: disponible, activeColor: _kPurple,
              onChanged: (v) => setD(() => disponible = v),
            ),
            SwitchListTile(
              title: const Text('Requiere cocina',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              value: cocina, activeColor: _kPurple,
              onChanged: (v) => setD(() => cocina = v),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB PRODUCTOS
// ─────────────────────────────────────────────────────────────────────────────
class _ProductosTab extends StatefulWidget {
  final ProductoService prodSvc;
  final CategoriaService catSvc;
  final List<String> iconos;
  const _ProductosTab({required this.prodSvc, required this.catSvc, required this.iconos});

  static void showAgregar(BuildContext ctx, ProductoService prodSvc, CategoriaService catSvc) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final descCtrl   = TextEditingController();
    String? catSel;
    final cats = await catSvc.obtenerCategorias().first;
    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => _AdminDialog(
          titulo: '➕ Nuevo Producto',
          onGuardar: () async {
            if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty || catSel == null) return;
            final cat = cats.firstWhere((c) => c.id == catSel);
            await prodSvc.agregarProducto(ProductoModel(
              id: '', nombre: nombreCtrl.text.trim(),
              precio: double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0,
              descripcion: descCtrl.text.trim(),
              disponible: true, categoria: cat.nombre,
            ));
            if (dctx.mounted) Navigator.pop(dctx);
          },
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _Campo(ctrl: nombreCtrl, label: 'Nombre', icon: Icons.fastfood),
            const SizedBox(height: 12),
            _Campo(ctrl: descCtrl, label: 'Descripción', icon: Icons.description, maxLines: 2),
            const SizedBox(height: 12),
            _Campo(ctrl: precioCtrl, label: 'Precio', icon: Icons.attach_money,
                tipo: TextInputType.number),
            const SizedBox(height: 12),
            _CatDropdown(cats: cats, val: catSel, onChanged: (v) => setD(() => catSel = v)),
          ]),
        ),
      ),
    );
  }

  @override
  State<_ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<_ProductosTab> {
  String _busq = '';
  final _ctrl  = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductoModel>>(
      stream: widget.prodSvc.obtenerProductos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kPurple));
        }
        final todos = snap.data ?? [];
        var prods = todos;
        if (_busq.isNotEmpty) {
          prods = prods.where((p) =>
            p.nombre.toLowerCase().contains(_busq) ||
            p.categoria.toLowerCase().contains(_busq)).toList();
        }
        final disp = todos.where((p) => p.disponible).length;

        return Column(children: [
          _StatsBar(items: [
            _Stat('Total',      '${todos.length}', Icons.inventory,   _kPurple),
            _Stat('Disponibles', '$disp',          Icons.check_circle, Colors.green),
            _Stat('Agotados', '${todos.length - disp}', Icons.remove_circle, Colors.red),
          ]),

          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _busq = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar producto o categoría...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                suffixIcon: _busq.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () { _ctrl.clear(); setState(() => _busq = ''); })
                    : null,
                filled: true, fillColor: _kCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kPurple, width: 1.5)),
              ),
            ),
          ),

          Expanded(
            child: prods.isEmpty
                ? const _EmptyState(icono: Icons.inventory,
                    msg: 'Sin productos', sub: 'Toca ➕ para crear el primero')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: prods.length,
                    itemBuilder: (_, i) => _ProdCard(
                        prod: prods[i], svc: widget.prodSvc, catSvc: widget.catSvc),
                  ),
          ),
        ]);
      },
    );
  }
}

class _ProdCard extends StatelessWidget {
  final ProductoModel prod;
  final ProductoService svc;
  final CategoriaService catSvc;
  const _ProdCard({required this.prod, required this.svc, required this.catSvc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: prod.disponible
            ? _kPurple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditar(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Imagen/icono
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                color: prod.disponible
                    ? _kPurple.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(prod.icono,
                      style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prod.nombre, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              if (prod.descripcion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(prod.descripcion,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _ChipTag('\$${prod.precio.toStringAsFixed(2)}', Colors.green),
                _ChipTag(prod.categoria, Colors.blue),
                if (!prod.disponible) _ChipTag('Agotado', Colors.red),
              ]),
            ])),
            PopupMenuButton<String>(
              color: _kCard,
              icon: const Icon(Icons.more_vert, color: Colors.white38),
              onSelected: (v) async {
                if (v == 'edit') _showEditar(context);
                if (v == 'toggle') {
                  await svc.editarProducto(prod.id, ProductoModel(
                    id: prod.id, nombre: prod.nombre, precio: prod.precio,
                    descripcion: prod.descripcion, categoria: prod.categoria,
                    disponible: !prod.disponible,
                  ));
                }
                if (v == 'del') {
                  final ok = await _confirm(context, '¿Eliminar "${prod.nombre}"?');
                  if (ok) await svc.eliminarProducto(prod.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit, color: Colors.white54),
                        title: Text('Editar', style: TextStyle(color: Colors.white)))),
                PopupMenuItem(value: 'toggle',
                    child: ListTile(
                        leading: Icon(
                            prod.disponible ? Icons.remove_circle : Icons.check_circle,
                            color: Colors.white54),
                        title: Text(prod.disponible ? 'Marcar agotado' : 'Disponible',
                            style: const TextStyle(color: Colors.white)))),
                const PopupMenuItem(value: 'del',
                    child: ListTile(leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Eliminar', style: TextStyle(color: Colors.red)))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditar(BuildContext context) async {
    final nombreCtrl = TextEditingController(text: prod.nombre);
    final precioCtrl = TextEditingController(text: prod.precio.toString());
    final descCtrl   = TextEditingController(text: prod.descripcion);
    String catSel    = prod.categoria;
    bool disponible  = prod.disponible;
    final cats       = await catSvc.obtenerCategorias().first;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => _AdminDialog(
          titulo: '✏️ Editar Producto',
          onGuardar: () async {
            await svc.editarProducto(prod.id, ProductoModel(
              id: prod.id, nombre: nombreCtrl.text.trim(),
              precio: double.tryParse(precioCtrl.text) ?? prod.precio,
              descripcion: descCtrl.text.trim(),
              disponible: disponible, categoria: catSel,
            ));
            if (dctx.mounted) Navigator.pop(dctx);
          },
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _Campo(ctrl: nombreCtrl, label: 'Nombre', icon: Icons.fastfood),
            const SizedBox(height: 12),
            _Campo(ctrl: descCtrl, label: 'Descripción', icon: Icons.description, maxLines: 2),
            const SizedBox(height: 12),
            _Campo(ctrl: precioCtrl, label: 'Precio', icon: Icons.attach_money,
                tipo: TextInputType.number),
            const SizedBox(height: 12),
            _CatDropdown(
                cats: cats,
                val: cats.any((c) => c.nombre == catSel) ? catSel : null,
                useName: true,
                onChanged: (v) => setD(() => catSel = v ?? catSel)),
            SwitchListTile(
              title: const Text('Disponible',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              value: disponible, activeColor: _kPurple,
              onChanged: (v) => setD(() => disponible = v),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDialog extends StatelessWidget {
  final String titulo;
  final Widget content;
  final Future<void> Function() onGuardar;
  const _AdminDialog({required this.titulo, required this.content, required this.onGuardar});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(titulo, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: content),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async { await onGuardar(); },
          child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType tipo;
  const _Campo({required this.ctrl, required this.label, required this.icon,
      this.maxLines = 1, this.tipo = TextInputType.text});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tipo, maxLines: maxLines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: _kPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPurple, width: 1.5)),
    ),
  );
}

class _IconPicker extends StatelessWidget {
  final List<String> iconos;
  final String sel;
  final void Function(String) onChange;
  const _IconPicker({required this.iconos, required this.sel, required this.onChange});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: iconos.map((i) {
      final active = i == sel;
      return GestureDetector(
        onTap: () => onChange(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: active ? _kPurple.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? _kPurple : Colors.white12,
                width: active ? 2 : 1),
          ),
          child: Center(child: Text(i, style: const TextStyle(fontSize: 22))),
        ),
      );
    }).toList(),
  );
}

class _CatDropdown extends StatelessWidget {
  final List<CategoriaModel> cats;
  final String? val;
  final bool useName;
  final void Function(String?) onChanged;
  const _CatDropdown({required this.cats, required this.val,
      required this.onChanged, this.useName = false});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    dropdownColor: _kCard,
    style: const TextStyle(color: Colors.white),
    value: val,
    decoration: InputDecoration(
      labelText: 'Categoría',
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: const Icon(Icons.category, color: _kPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPurple)),
    ),
    items: cats.map((c) => DropdownMenuItem(
      value: useName ? c.nombre : c.id,
      child: Row(children: [
        Text(c.icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(c.nombre, style: const TextStyle(color: Colors.white)),
      ]),
    )).toList(),
    onChanged: onChanged,
  );
}

class _StatsBar extends StatelessWidget {
  final List<_Stat> items;
  const _StatsBar({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: items.expand<Widget>((s) => [
          Expanded(child: Column(children: [
            Icon(s.icon, color: s.color, size: 20),
            const SizedBox(height: 4),
            Text(s.val, style: TextStyle(
                color: s.color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(s.label, style: const TextStyle(
                color: Colors.white38, fontSize: 10)),
          ])),
          if (s != items.last)
            Container(width: 1, height: 32, color: Colors.white12),
        ]).toList(),
      ),
    );
  }
}

class _Stat {
  final String label, val;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.val, this.icon, this.color);
  bool operator ==(Object o) => o is _Stat && o.label == label;
  int get hashCode => label.hashCode;
}

class _ChipTag extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipTag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icono;
  final String msg, sub;
  const _EmptyState({required this.icono, required this.msg, required this.sub});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icono, size: 64, color: Colors.white12),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(
          color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(sub, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 13)),
      ),
    ]),
  );
}

// ── Utilidades ────────────────────────────────────────────────────────────────
Future<bool> _confirm(BuildContext ctx, String msg) async {
  return await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('⚠️ Confirmar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text(msg, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  ) ?? false;
}
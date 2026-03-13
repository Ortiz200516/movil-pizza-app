import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';
import '../carrito/carrito_provider.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kNaranja = Color(0xFFFF6B35);
const _kBg      = Color(0xFF0F172A);
const _kCard    = Color(0xFF1E293B);

const List<Color> _paleta = [
  Color(0xFFFF6B35), Color(0xFFFFB800), Color(0xFF38BDF8),
  Color(0xFF818CF8), Color(0xFFFB7185), Color(0xFF4ADE80),
  Color(0xFFF472B6), Color(0xFF34D399), Color(0xFFFBBF24),
];
Color _colorPorIdx(int i) => _paleta[i % _paleta.length];

Color _colorDeCat(String cat) {
  final n = cat.toLowerCase();
  if (n.contains('pizza'))                               return const Color(0xFFFF6B35);
  if (n.contains('hamburgues') || n.contains('burger'))  return const Color(0xFFFFB800);
  if (n.contains('cerveza') || n.contains('beer'))       return const Color(0xFF38BDF8);
  if (n.contains('bebida') || n.contains('refresco'))    return const Color(0xFF818CF8);
  if (n.contains('entrada') || n.contains('snack'))      return const Color(0xFFFB7185);
  if (n.contains('ensalada'))                            return const Color(0xFF4ADE80);
  if (n.contains('postre') || n.contains('helado'))      return const Color(0xFFF472B6);
  if (n.contains('combo') || n.contains('promo'))        return const Color(0xFF34D399);
  return const Color(0xFFFF6B35);
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── MenuPage ──────────────────────────────────────────────────────────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _service    = ProductoService();
  final _searchCtrl = TextEditingController();
  String? _catSel;
  String  _query     = '';
  List<ProductoModel> _cache = [];
  bool _cacheLoaded = false;

  @override
  void initState() {
    super.initState();
    _cargarCache();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Caché local para modo offline
  Future<void> _cargarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('menu_cache');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        setState(() {
          _cache = list.map((m) => ProductoModel.fromFirestore(
              m['id'] ?? '', Map<String, dynamic>.from(m))).toList();
          _cacheLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _guardarCache(List<ProductoModel> productos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list  = productos.map((p) => {
        'id': p.id, 'nombre': p.nombre, 'descripcion': p.descripcion,
        'precio': p.precio, 'categoria': p.categoria,
        'disponible': p.disponible, 'icono': p.icono,
      }).toList();
      await prefs.setString('menu_cache', jsonEncode(list));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // Header colapsable
          SliverAppBar(
            backgroundColor: _kBg,
            expandedHeight: 80,
            floating: true,
            snap: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A0A00), _kBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Nuestro Menú',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      Text('Elige tu favorita 🍕',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kNaranja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _kNaranja.withValues(alpha: 0.3)),
                    ),
                    child: const Text('🍕', style: TextStyle(fontSize: 26)),
                  ),
                ]),
              ),
            ),
          ),

          // Buscador + chips categorías
          SliverToBoxAdapter(
            child: _SearchBar(
              query: _query,
              catSel: _catSel,
              searchCtrl: _searchCtrl,
              onQueryChanged: (v) => setState(() {
                _query = v;
                if (v.isNotEmpty) _catSel = null;
              }),
              onClearQuery: () => setState(() {
                _searchCtrl.clear();
                _query = '';
                _catSel = null;
              }),
              onCatSelected: (cat) => setState(() => _catSel = cat),
            ),
          ),

          // Grid productos
          StreamBuilder<List<ProductoModel>>(
            stream: _service.obtenerProductos(),
            builder: (context, snap) {

              // Skeleton mientras carga (sin caché)
              if (snap.connectionState == ConnectionState.waiting &&
                  !_cacheLoaded) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.72,
                        crossAxisSpacing: 10, mainAxisSpacing: 10),
                    delegate: SliverChildBuilderDelegate(
                        (_, __) => const _SkeletonCard(), childCount: 6),
                  ),
                );
              }

              var productos = snap.data ?? _cache;

              // Guardar en caché si hay datos frescos
              if (snap.data != null && snap.data!.isNotEmpty) {
                _guardarCache(snap.data!);
              }

              // Filtros
              if (_catSel != null) {
                productos = productos
                    .where((p) => p.categoria.trim() == _catSel!.trim())
                    .toList();
              }
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                productos = productos
                    .where((p) =>
                        p.nombre.toLowerCase().contains(q) ||
                        p.descripcion.toLowerCase().contains(q) ||
                        p.categoria.toLowerCase().contains(q))
                    .toList();
              }

              if (productos.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    catSel: _catSel,
                    query: _query,
                    onReset: () => setState(() {
                      _catSel = null;
                      _query = '';
                      _searchCtrl.clear();
                    }),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72,
                      crossAxisSpacing: 10, mainAxisSpacing: 10),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TarjetaProducto(
                        producto: productos[i], index: i),
                    childCount: productos.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Buscador + chips (widget normal, sin SliverPersistentHeader) ──────────────
class _SearchBar extends StatelessWidget {
  final String query;
  final String? catSel;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onCatSelected;

  const _SearchBar({
    required this.query, required this.catSel,
    required this.searchCtrl, required this.onQueryChanged,
    required this.onClearQuery, required this.onCatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: Column(children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: query.isNotEmpty
                      ? _kNaranja.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar pizzas, combos, bebidas...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: query.isNotEmpty
                        ? _kNaranja
                        : Colors.white.withValues(alpha: 0.3),
                    size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 18),
                        onPressed: onClearQuery)
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
        ),

        // Chips categorías
        if (query.isEmpty)
          SizedBox(
            height: 44,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categorias')
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: List.generate(4,
                        (_) => const _SkeletonChip()),
                  );
                }
                final docs = snap.data!.docs
                    .where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['disponible'] != false;
                    })
                    .toList()
                  ..sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    return ((da['orden'] ?? 999) as int)
                        .compareTo((db['orden'] ?? 999) as int);
                  });

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _CatChip(
                      label: '🍽️  Todo',
                      color: _kNaranja,
                      selected: catSel == null,
                      onTap: () => onCatSelected(null),
                    ),
                    ...List.generate(docs.length, (i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final nombre = (d['nombre'] as String? ?? '').trim();
                      if (nombre.isEmpty) return const SizedBox.shrink();
                      final icono = d['icono'] as String? ?? '🍽️';
                      return _CatChip(
                        label: '$icono  $nombre',
                        color: _colorPorIdx(i),
                        selected: catSel == nombre,
                        onTap: () => onCatSelected(nombre),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ── Chip de categoría ─────────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.07),
            width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8)]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? color : Colors.white.withValues(alpha: 0.4),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 12)),
    ),
  );
}

// ── Skeleton card ─────────────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          Expanded(flex: 5, child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _anim.value * 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Container(height: 12, width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.1),
                      borderRadius: BorderRadius.circular(6))),
              Container(height: 10, width: 80,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.06),
                      borderRadius: BorderRadius.circular(6))),
              Container(height: 10, width: 60,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.08),
                      borderRadius: BorderRadius.circular(6))),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip();
  @override
  Widget build(BuildContext context) => Container(
    width: 90, height: 34,
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
    ),
  );
}

// ── Tarjeta producto ──────────────────────────────────────────────────────────
class _TarjetaProducto extends StatefulWidget {
  final ProductoModel producto;
  final int index;
  const _TarjetaProducto({required this.producto, required this.index});
  @override
  State<_TarjetaProducto> createState() => _TarjetaProductoState();
}

class _TarjetaProductoState extends State<_TarjetaProducto>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  int _cantEnCarrito = 0;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.08)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _agregarRapido() {
    HapticFeedback.lightImpact();
    _bounceCtrl.forward(from: 0);
    setState(() => _cantEnCarrito++);
    Provider.of<CarritoProvider>(context, listen: false).agregarProducto({
      'id':        widget.producto.id,
      'nombre':    widget.producto.nombre,
      'precio':    widget.producto.precio,
      'categoria': widget.producto.categoria,
      'icono':     widget.producto.icono,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(widget.producto.icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text('${widget.producto.nombre} agregado',
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: _colorDeCat(widget.producto.categoria),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      duration: const Duration(seconds: 1),
    ));
  }

  void _verDetalle() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleSheet(producto: widget.producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorDeCat(widget.producto.categoria);
    final icono = widget.producto.icono;

    return GestureDetector(
      onTap: _verDetalle,
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (_, child) =>
            Transform.scale(scale: _bounceAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.07),
                  blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            // Área imagen/emoji
            Expanded(flex: 5, child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(children: [
                Center(child: Text(icono,
                    style: const TextStyle(fontSize: 52))),

                // Badge categoría
                Positioned(top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_capitalizar(widget.producto.categoria),
                        style: TextStyle(color: color, fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),

                // Badge cantidad en carrito
                if (_cantEnCarrito > 0)
                  Positioned(top: 8, right: 8,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: _kNaranja, shape: BoxShape.circle),
                      child: Center(child: Text('$_cantEnCarrito',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                  ),

                // Overlay no disponible
                if (!widget.producto.disponible)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16))),
                      child: const Center(
                        child: Text('NO DISPONIBLE',
                            style: TextStyle(color: Colors.white54,
                                fontSize: 10, fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ),
                  ),
              ]),
            )),

            // Info + botón agregar
            Expanded(flex: 3, child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Text(widget.producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Row(children: [
                  Expanded(child: Text(
                    '\$${widget.producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14),
                  )),
                  if (widget.producto.disponible)
                    GestureDetector(
                      onTap: _agregarRapido,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color.withValues(alpha: 0.4))),
                        child: Icon(Icons.add, color: color, size: 18),
                      ),
                    ),
                ]),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom sheet detalle ──────────────────────────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final ProductoModel producto;
  const _DetalleSheet({required this.producto});

  @override
  Widget build(BuildContext context) {
    final color = _colorDeCat(producto.categoria);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
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
            Center(child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            )),

            // Emoji grande
            Center(child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1)),
              child: Center(child: Text(producto.icono,
                  style: const TextStyle(fontSize: 56))),
            )),
            const SizedBox(height: 16),

            // Nombre y precio
            Row(children: [
              Expanded(child: Text(producto.nombre,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 20))),
              Text('\$${producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.w900, fontSize: 22)),
            ]),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_capitalizar(producto.categoria),
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),

            if (producto.descripcion.isNotEmpty) ...[
              Text(producto.descripcion,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 14, height: 1.6)),
              const SizedBox(height: 16),
            ],

            if (!producto.disponible)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: const Row(children: [
                  Text('⛔', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Text('No disponible en este momento',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ]),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Provider.of<CarritoProvider>(context, listen: false)
                      .agregarProducto({
                    'id': producto.id, 'nombre': producto.nombre,
                    'precio': producto.precio, 'categoria': producto.categoria,
                    'icono': producto.icono,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${producto.nombre} agregado al carrito 🛒',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ));
                },
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Agregar al carrito',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String? catSel;
  final String query;
  final VoidCallback onReset;
  const _EmptyState({this.catSel, required this.query, required this.onReset});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(catSel != null ? '🔍' : '😕',
          style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 14),
      Text(
        catSel != null && query.isEmpty
            ? 'No hay productos en "$catSel"'
            : 'Sin resultados para "$query"',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 15, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.refresh, color: _kNaranja, size: 16),
        label: const Text('Ver todo el menú',
            style: TextStyle(color: _kNaranja, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}
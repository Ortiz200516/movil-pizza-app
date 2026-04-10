import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';
import '../carrito/carrito_provider.dart';
import '../widgets/skeleton_widgets.dart';

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
      if (raw != null && mounted) {
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

          // Header fijo — SliverToBoxAdapter evita superposición
          SliverToBoxAdapter(
            child: Container(
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
                        (_, __) => const SkeletonMenuCard(), childCount: 6),
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
                        (_) => const SkeletonCatChip()),
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


// _SkeletonChip → reemplazado por SkeletonCatChip de skeleton_widgets.dart

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
    final p     = widget.producto;
    final color = _colorDeCat(p.categoria);
    final tieneImagen = p.imagenUrl != null && p.imagenUrl!.isNotEmpty;

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
            border: Border.all(
                color: p.disponible
                    ? color.withValues(alpha: 0.22)
                    : Colors.red.withValues(alpha: 0.25),
                width: 1.5),
            boxShadow: [BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 16, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            // ── Área imagen ───────────────────────────────────────────
            Expanded(flex: 6, child: Stack(children: [

              // Imagen o emoji
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: tieneImagen
                    ? Image.network(
                        p.imagenUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _EmojiPlaceholder(
                            icono: p.icono, color: color),
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : _EmojiPlaceholder(icono: p.icono, color: color),
                      )
                    : _EmojiPlaceholder(icono: p.icono, color: color),
              ),

              // Gradiente inferior sobre imagen para legibilidad
              if (tieneImagen)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Badge categoría (top-left)
              Positioned(top: 8, left: 8,
                child: _BadgeCategoria(
                    label: _capitalizar(p.categoria), color: color)),

              // Badge cantidad en carrito (top-right)
              if (_cantEnCarrito > 0)
                Positioned(top: 8, right: 8,
                  child: _BadgeCantidad(cantidad: _cantEnCarrito)),

              // Indicador disponibilidad (dot bottom-right)
              Positioned(bottom: 8, right: 8,
                child: _DotDisponible(disponible: p.disponible)),

              // Overlay no disponible
              if (!p.disponible)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.58),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⛔', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 6),
                            Text('No disponible',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ])),

            // ── Info inferior ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Nombre
                Text(p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25)),
                const SizedBox(height: 2),

                // Tiempo preparación
                Row(children: [
                  Icon(Icons.schedule_outlined,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 3),
                  Text('~${p.tiempoPreparacion} min',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10)),
                ]),
                const SizedBox(height: 8),

                // Precio + botón agregar
                Row(children: [
                  Expanded(child: Text(
                      '\$${p.precio.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 15))),
                  if (p.disponible)
                    GestureDetector(
                      onTap: _agregarRapido,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _cantEnCarrito > 0
                              ? color : color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.add_rounded,
                            color: _cantEnCarrito > 0
                                ? Colors.white : color,
                            size: 18),
                      ),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares de la tarjeta ─────────────────────────────────────────

/// Placeholder con emoji cuando no hay imagen
class _EmojiPlaceholder extends StatelessWidget {
  final String icono;
  final Color color;
  const _EmojiPlaceholder({required this.icono, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: double.infinity,
    color: color.withValues(alpha: 0.09),
    child: Center(child: Text(icono,
        style: const TextStyle(fontSize: 54))),
  );
}

/// Badge de categoría con fondo semitransparente blur-like
class _BadgeCategoria extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeCategoria({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 9,
        fontWeight: FontWeight.w800, letterSpacing: 0.3)),
  );
}

/// Badge de cantidad en carrito
class _BadgeCantidad extends StatelessWidget {
  final int cantidad;
  const _BadgeCantidad({required this.cantidad});
  @override
  Widget build(BuildContext context) => Container(
    width: 24, height: 24,
    decoration: BoxDecoration(
      color: _kNaranja,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(
          color: _kNaranja.withValues(alpha: 0.5),
          blurRadius: 6, spreadRadius: 1)],
    ),
    child: Center(child: Text('$cantidad',
        style: const TextStyle(color: Colors.white,
            fontSize: 11, fontWeight: FontWeight.w900))),
  );
}

/// Indicador dot de disponibilidad
class _DotDisponible extends StatelessWidget {
  final bool disponible;
  const _DotDisponible({required this.disponible});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: disponible
              ? const Color(0xFF4ADE80) : Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(disponible ? 'Disponible' : 'Agotado',
          style: const TextStyle(
              color: Colors.white, fontSize: 8,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Detalle de producto — pantalla completa ──────────────────────────────────
class _DetalleSheet extends StatefulWidget {
  final ProductoModel producto;
  const _DetalleSheet({required this.producto});
  @override
  State<_DetalleSheet> createState() => _DetalleSheetState();
}

class _DetalleSheetState extends State<_DetalleSheet>
    with SingleTickerProviderStateMixin {
  int    _cantidad   = 1;
  String _notaExtra  = '';
  bool   _agregando  = false;
  late AnimationController _btnCtrl;
  late Animation<double>   _btnScale;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _btnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _btnCtrl.dispose(); super.dispose(); }

  double get _totalLinea => widget.producto.precio * _cantidad;

  Future<void> _agregar() async {
    if (_agregando || !widget.producto.disponible) return;
    setState(() => _agregando = true);
    _btnCtrl.forward().then((_) => _btnCtrl.reverse());
    HapticFeedback.mediumImpact();
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    final p = widget.producto;
    for (int i = 0; i < _cantidad; i++) {
      carrito.agregarProducto({
        'id': p.id, 'nombre': p.nombre, 'precio': p.precio,
        'categoria': p.categoria, 'icono': p.icono,
        'imagenUrl': p.imagenUrl ?? '',
        'notasEspeciales': _notaExtra.trim(),
      });
    }
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(p.icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          _cantidad == 1
              ? '${p.nombre} agregado al carrito'
              : '$_cantidad × ${p.nombre} agregados',
          style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: _colorDeCat(p.categoria),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.producto;
    final color = _colorDeCat(p.categoria);
    final tieneImagen = p.imagenUrl != null && p.imagenUrl!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [

          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white12,
                borderRadius: BorderRadius.circular(2)))),

          // Contenido scrollable
          Expanded(child: ListView(controller: ctrl, padding: EdgeInsets.zero,
            children: [

              // ── Imagen hero ──────────────────────────────────────────
              Stack(children: [
                SizedBox(
                  height: 240, width: double.infinity,
                  child: tieneImagen
                      ? Image.network(p.imagenUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _HeroEmoji(icono: p.icono, color: color))
                      : _HeroEmoji(icono: p.icono, color: color),
                ),
                // Gradiente inferior
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(height: 80,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [_kBg, _kBg.withValues(alpha: 0)])))),
                // Badge categoría
                Positioned(top: 14, left: 16,
                  child: _BadgeCategoria(
                      label: _capitalizar(p.categoria), color: color)),
                // Disponibilidad
                Positioned(top: 14, right: 56,
                  child: _DotDisponible(disponible: p.disponible)),
                // Cerrar
                Positioned(top: 10, right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 17)))),
              ]),

              // ── Info ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                  // Nombre
                  Text(p.nombre, style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 22, height: 1.2)),
                  const SizedBox(height: 8),

                  // Meta info
                  Row(children: [
                    Icon(Icons.schedule_outlined, size: 13,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 4),
                    Text('~${p.tiempoPreparacion} min', style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                    const SizedBox(width: 14),
                    Icon(Icons.restaurant_outlined, size: 13,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 4),
                    Text(_capitalizar(p.categoria), style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                  const SizedBox(height: 16),

                  // Descripción
                  if (p.descripcion.isNotEmpty) ...[
                    Text(p.descripcion, style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14, height: 1.65)),
                    const SizedBox(height: 20),
                  ],

                  // Opciones
                  if (p.opciones != null && p.opciones!.isNotEmpty) ...[
                    _SeccionOpciones(opciones: p.opciones!, color: color),
                    const SizedBox(height: 4),
                  ],

                  // Nota especial
                  _CampoNota(onChanged: (v) =>
                      setState(() => _notaExtra = v), color: color),
                  const SizedBox(height: 16),

                  // No disponible
                  if (!p.disponible)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.25))),
                      child: const Row(children: [
                        Text('⛔', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                            'No disponible en este momento',
                            style: TextStyle(color: Colors.red, fontSize: 13))),
                      ])),
                  const SizedBox(height: 100),
                ]),
              ),
            ],
          )),

          // ── Barra fija: cantidad + agregar ───────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: _kCard,
              border: Border(top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06)))),
            child: Row(children: [
              // Selector cantidad
              Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _BtnCantidad(icono: Icons.remove_rounded, color: color,
                    onTap: _cantidad > 1 ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _cantidad--);
                    } : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_cantidad', style: TextStyle(
                        color: color, fontWeight: FontWeight.w900,
                        fontSize: 18))),
                  _BtnCantidad(icono: Icons.add_rounded, color: color,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _cantidad++);
                    }),
                ]),
              ),
              const SizedBox(width: 14),
              // Botón agregar
              Expanded(child: AnimatedBuilder(
                animation: _btnScale,
                builder: (_, child) =>
                    Transform.scale(scale: _btnScale.value, child: child),
                child: GestureDetector(
                  onTap: p.disponible ? _agregar : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: p.disponible
                          ? color : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: p.disponible ? [BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 14, offset: const Offset(0, 5))] : null),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                        _agregando
                            ? Icons.hourglass_top_rounded
                            : Icons.add_shopping_cart_rounded,
                        color: p.disponible ? Colors.white : Colors.white24,
                        size: 18),
                      const SizedBox(width: 8),
                      Text(
                        p.disponible
                            ? 'Agregar · \$${_totalLinea.toStringAsFixed(2)}'
                            : 'No disponible',
                        style: TextStyle(
                            color: p.disponible
                                ? Colors.white : Colors.white24,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                  ),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Hero emoji ────────────────────────────────────────────────────────────────
class _HeroEmoji extends StatelessWidget {
  final String icono; final Color color;
  const _HeroEmoji({required this.icono, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, height: double.infinity,
    color: color.withValues(alpha: 0.09),
    child: Center(child: Text(icono, style: const TextStyle(fontSize: 96))));
}

// ── Sección de opciones ───────────────────────────────────────────────────────
class _SeccionOpciones extends StatefulWidget {
  final Map<String, dynamic> opciones; final Color color;
  const _SeccionOpciones({required this.opciones, required this.color});
  @override State<_SeccionOpciones> createState() => _SeccionOpcionesState();
}

class _SeccionOpcionesState extends State<_SeccionOpciones> {
  final Map<String, String> _sel = {};
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.opciones.entries.map((g) {
        final vals = g.value is List
            ? (g.value as List).map((v) => v.toString()).toList()
            : <String>[];
        if (vals.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_capitalizar(g.key), style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: vals.map((v) {
            final sel = _sel[g.key] == v;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick();
                  setState(() => _sel[g.key] = v); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? widget.color.withValues(alpha: 0.15) : _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? widget.color.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
                    width: sel ? 1.5 : 1)),
                child: Text(v, style: TextStyle(
                    color: sel ? widget.color : Colors.white54,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13))));
          }).toList()),
          const SizedBox(height: 16),
        ]);
      }).toList());
  }
}

// ── Campo nota especial ───────────────────────────────────────────────────────
class _CampoNota extends StatefulWidget {
  final ValueChanged<String> onChanged; final Color color;
  const _CampoNota({required this.onChanged, required this.color});
  @override State<_CampoNota> createState() => _CampoNotaState();
}

class _CampoNotaState extends State<_CampoNota> {
  bool _exp = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(
      onTap: () => setState(() => _exp = !_exp),
      child: Row(children: [
        Icon(Icons.note_add_outlined, size: 15,
            color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Text('Agregar nota especial', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
        const Spacer(),
        Icon(_exp ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
            color: Colors.white24, size: 18),
      ])),
    AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          _exp ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          onChanged: widget.onChanged, maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Ej: sin cebolla, extra salsa...',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            filled: true, fillColor: _kCard,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: widget.color.withValues(alpha: 0.5), width: 1.5)),
          ))),
    ),
  ]);
}

// ── Botón cantidad ────────────────────────────────────────────────────────────
class _BtnCantidad extends StatelessWidget {
  final IconData icono; final Color color; final VoidCallback? onTap;
  const _BtnCantidad(
      {required this.icono, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 44,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: onTap != null
              ? color.withValues(alpha: 0.1) : Colors.transparent),
      child: Icon(icono,
          color: onTap != null ? color : Colors.white12, size: 20)));
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
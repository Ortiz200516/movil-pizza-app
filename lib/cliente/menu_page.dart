import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';
import '../carrito/carrito_provider.dart';

// ─── HELPERS ─────────────────────────────────────────────────
const List<Color> _paleta = [
  Color(0xFFFF6B35), Color(0xFFFFB800), Color(0xFF38BDF8),
  Color(0xFF818CF8), Color(0xFFFB7185), Color(0xFF4ADE80),
  Color(0xFFF472B6), Color(0xFF34D399), Color(0xFFFBBF24),
];
Color _colorPorIdx(int i) => _paleta[i % _paleta.length];

Color _colorDeCat(String cat) {
  final n = cat.toLowerCase();
  if (n.contains('pizza'))                              return const Color(0xFFFF6B35);
  if (n.contains('hamburgues') || n.contains('burger')) return const Color(0xFFFFB800);
  if (n.contains('cerveza') || n.contains('beer'))      return const Color(0xFF38BDF8);
  if (n.contains('bebida') || n.contains('refresco'))   return const Color(0xFF818CF8);
  if (n.contains('entrada') || n.contains('snack'))     return const Color(0xFFFB7185);
  if (n.contains('ensalada'))                           return const Color(0xFF4ADE80);
  if (n.contains('postre') || n.contains('helado'))     return const Color(0xFFF472B6);
  if (n.contains('pollo') || n.contains('chicken'))     return const Color(0xFFFB7185);
  if (n.contains('combo') || n.contains('promo'))       return const Color(0xFF34D399);
  if (n.contains('desayuno'))                           return const Color(0xFFFBBF24);
  return const Color(0xFFFF6B35);
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─── MENU PAGE ────────────────────────────────────────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _service    = ProductoService();
  final _searchCtrl = TextEditingController();
  String? _catSel;
  String  _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _nombreUsuario() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty)
      return user.displayName!.split(' ').first;
    return 'amigo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: CustomScrollView(
        // ← Un solo scroll para TODO (header + chips + grid)
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Header colapsable ──────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0F172A),
            expandedHeight: 90,
            floating: true,
            snap: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A00), Color(0xFF0F172A)],
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${_saludo()}, ${_nombreUsuario()} 👋',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      const Text('¿Qué te apetece hoy?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.3)),
                    ),
                    child: const Text('🍕', style: TextStyle(fontSize: 26)),
                  ),
                ]),
              ),
            ),
          ),

          // ── Buscador + chips (sticky) ──────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarDelegate(
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

          // ── Grid de productos ──────────────────────────────
          StreamBuilder<List<ProductoModel>>(
            stream: _service.obtenerProductos(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFFFF6B35))),
                );
              }

              var productos = snap.data ?? [];

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
                return SliverFillRemaining(child: _buildVacio());
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
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

  Widget _buildVacio() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_catSel != null ? '🔍' : '😕',
          style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 14),
      Text(
        _catSel != null && _query.isEmpty
            ? 'No hay productos en "$_catSel"'
            : 'Sin resultados para "$_query"',
        style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 15,
            fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      TextButton.icon(
        onPressed: () => setState(() {
          _catSel = null;
          _query = '';
          _searchCtrl.clear();
        }),
        icon: const Icon(Icons.refresh, color: Color(0xFFFF6B35), size: 16),
        label: const Text('Ver todo el menú',
            style: TextStyle(
                color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

// ─── DELEGATE PARA BUSCADOR + CHIPS (sticky) ──────────────────
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final String query;
  final String? catSel;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onCatSelected;

  const _SearchBarDelegate({
    required this.query,
    required this.catSel,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCatSelected,
  });

  @override
  double get minExtent => 110;
  @override
  double get maxExtent => 110;

  @override
  bool shouldRebuild(_SearchBarDelegate old) =>
      old.query != query || old.catSel != catSel;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar pizzas, combos, bebidas...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.25), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.white.withOpacity(0.3), size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.white.withOpacity(0.3), size: 18),
                        onPressed: onClearQuery,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
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
                if (!snap.hasData) return const SizedBox.shrink();
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
                      color: const Color(0xFFFF6B35),
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

// ─── CHIP ─────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? color.withOpacity(0.18)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? color.withOpacity(0.75)
              : Colors.white.withOpacity(0.07),
          width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 8)]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
            color: selected ? color : Colors.white.withOpacity(0.4),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.2,
          )),
    ),
  );
}

// ─── TARJETA PRODUCTO ─────────────────────────────────────────
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
  late Animation<double>   _bounceAnim;

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
    Provider.of<CarritoProvider>(context, listen: false).agregarProducto({
      'id': widget.producto.id,
      'nombre': widget.producto.nombre,
      'precio': widget.producto.precio,
      'categoria': widget.producto.categoria,
      'icono': widget.producto.icono,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(widget.producto.icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
            child: Text('${widget.producto.nombre} agregado',
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: _colorDeCat(widget.producto.categoria),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.08)),
                      ),
                    ),
                  ),
                  Center(
                      child: Text(icono,
                          style: const TextStyle(fontSize: 52))),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          _capitalizar(widget.producto.categoria),
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                    ),
                  ),
                  if (!widget.producto.disponible)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16))),
                        child: const Center(
                          child: Text('NO DISPONIBLE',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text(widget.producto.nombre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                    Text(
                        '\$${widget.producto.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3)),
                    if (widget.producto.disponible)
                      GestureDetector(
                        onTap: _agregarRapido,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(9),
                              border: Border.all(
                                  color: color.withOpacity(0.5),
                                  width: 1.5)),
                          child: Icon(Icons.add,
                              color: color, size: 16),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── SHEET DE DETALLE ─────────────────────────────────────────
class _DetalleSheet extends StatefulWidget {
  final ProductoModel producto;
  const _DetalleSheet({required this.producto});
  @override
  State<_DetalleSheet> createState() => _DetalleSheetState();
}

class _DetalleSheetState extends State<_DetalleSheet> {
  int _cantidad = 1;
  String? _tamanoSel;
  final _notasCtrl = TextEditingController();

  @override
  void dispose() { _notasCtrl.dispose(); super.dispose(); }

  double get _precioFinal {
    double p = widget.producto.precio;
    if (_tamanoSel == 'grande')   p += 2.0;
    if (_tamanoSel == 'mediana')  p += 1.0;
    if (_tamanoSel == 'familiar') p += 4.0;
    return p * _cantidad;
  }

  @override
  Widget build(BuildContext context) {
    final color   = _colorDeCat(widget.producto.categoria);
    final opciones = widget.producto.opciones;
    final tamanos  = opciones?['tamanios'] as List?
        ?? opciones?['tamaños'] as List?;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.3))),
              child: Center(child: Text(widget.producto.icono,
                  style: const TextStyle(fontSize: 46))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(_capitalizar(widget.producto.categoria),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Text(widget.producto.nombre,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('\$${widget.producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ])),
          ]),
          if (widget.producto.descripcion.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06))),
              child: Text(widget.producto.descripcion,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      height: 1.5)),
            ),
          ],
          if (tamanos != null && tamanos.isNotEmpty) ...[
            const SizedBox(height: 20),
            _labelSeccion('Tamaño'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: tamanos.map<Widget>((t) {
              final sel = _tamanoSel == t.toString();
              return GestureDetector(
                onTap: () => setState(() => _tamanoSel = t.toString()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? color.withOpacity(0.18)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel
                            ? color
                            : Colors.white.withOpacity(0.1),
                        width: 1.5)),
                  child: Text(t.toString(),
                      style: TextStyle(
                          color: sel
                              ? color
                              : Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              );
            }).toList()),
          ],
          const SizedBox(height: 20),
          _labelSeccion('Notas especiales'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07))),
            child: TextField(
              controller: _notasCtrl,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Sin cebolla, bien cocido, sin sal...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            _labelSeccion('Cantidad'),
            Row(children: [
              _BtnCantidad(
                  icono: Icons.remove,
                  color: color,
                  onTap: _cantidad > 1
                      ? () => setState(() => _cantidad--)
                      : null),
              SizedBox(
                width: 48,
                child: Center(
                    child: Text('$_cantidad',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900))),
              ),
              _BtnCantidad(
                  icono: Icons.add,
                  color: color,
                  onTap: () => setState(() => _cantidad++)),
            ]),
          ]),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Provider.of<CarritoProvider>(context, listen: false)
                  .agregarProducto({
                'id': widget.producto.id,
                'nombre': widget.producto.nombre,
                'precio': widget.producto.precio,
                'categoria': widget.producto.categoria,
                'icono': widget.producto.icono,
                'cantidad': _cantidad,
                if (_tamanoSel != null)
                  'opcionesSeleccionadas': {'tamano': _tamanoSel},
                if (_notasCtrl.text.isNotEmpty)
                  'notasEspeciales': _notasCtrl.text,
                'opcionesKey': '${widget.producto.id}_$_tamanoSel',
              });
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              messenger.showSnackBar(SnackBar(
                content: Text(
                    '${widget.producto.icono} ${widget.producto.nombre} x$_cantidad agregado'),
                backgroundColor:
                    _colorDeCat(widget.producto.categoria),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              ));
            },
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6))],
              ),
              child: Center(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                      'Agregar  •  \$${_precioFinal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _labelSeccion(String texto) => Text(texto,
      style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

class _BtnCantidad extends StatelessWidget {
  final IconData icono;
  final Color color;
  final VoidCallback? onTap;
  const _BtnCantidad(
      {required this.icono, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null
            ? color.withOpacity(0.14)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: onTap != null
                ? color.withOpacity(0.45)
                : Colors.white.withOpacity(0.05))),
      child: Icon(icono,
          color: onTap != null
              ? color
              : Colors.white.withOpacity(0.12),
          size: 18),
    ),
  );
}
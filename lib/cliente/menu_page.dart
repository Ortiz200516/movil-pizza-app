import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';
import '../carrito/carrito_provider.dart';

// ─── COLORES DE CATEGORIA ────────────────────────────────────
const Map<String, Color> _catColors = {
  'pizza':       Color(0xFFFF6B35),
  'hamburguesa': Color(0xFFFFB800),
  'cerveza':     Color(0xFF38BDF8),
  'bebida':      Color(0xFF818CF8),
  'entrada':     Color(0xFFFB7185),
  'ensalada':    Color(0xFF4ADE80),
  'postre':      Color(0xFFF472B6),
};

const Map<String, String> _catIconos = {
  'pizza': '🍕', 'hamburguesa': '🍔', 'cerveza': '🍺',
  'bebida': '🥤', 'entrada': '🍟', 'ensalada': '🥗', 'postre': '🍰',
};

Color _colorDeCat(String cat) =>
    _catColors[cat.toLowerCase()] ?? const Color(0xFFFF6B35);

// ─── MENU PAGE PRINCIPAL ─────────────────────────────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final ProductoService _service = ProductoService();
  String? _catSel;          // null = todas
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: Column(children: [

        // ── BARRA DE BÚSQUEDA ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Expanded(child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar en el menu...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: Colors.white.withOpacity(0.3), size: 18),
                          onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; _catSel = null; }),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            )),
          ]),
        ),

        // ── CHIPS DE CATEGORÍAS ────────────────────────────
        if (_query.isEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CatChip(label: '🍽️ Todo', color: const Color(0xFFFF6B35),
                    selected: _catSel == null, onTap: () => setState(() => _catSel = null)),
                ..._catColors.keys.map((cat) => _CatChip(
                  label: '${_catIconos[cat]} ${_capitalizar(cat)}',
                  color: _colorDeCat(cat),
                  selected: _catSel == cat,
                  onTap: () => setState(() => _catSel = cat),
                )),
              ],
            ),
          ),

        const SizedBox(height: 10),

        // ── GRID DE PRODUCTOS ──────────────────────────────
        Expanded(
          child: StreamBuilder<List<ProductoModel>>(
            stream: _query.isNotEmpty || _catSel == null
                ? _service.obtenerProductos()
                : _service.obtenerProductosPorCategoria(_catSel!),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
              }
              var productos = snap.data ?? [];

              // Filtrar por búsqueda
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                productos = productos.where((p) =>
                    p.nombre.toLowerCase().contains(q) ||
                    p.descripcion.toLowerCase().contains(q) ||
                    p.categoria.toLowerCase().contains(q)).toList();
              }

              if (productos.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🔍', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 12),
                  Text('Sin resultados', style: TextStyle(color: Colors.white.withOpacity(0.3),
                      fontSize: 16, fontWeight: FontWeight.w600)),
                ]));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: productos.length,
                itemBuilder: (_, i) => _TarjetaProducto(producto: productos[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─── CHIP DE CATEGORÍA ────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.2) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color.withOpacity(0.7) : Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? color : Colors.white.withOpacity(0.45),
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12, letterSpacing: 0.3,
      )),
    ),
  );
}

// ─── TARJETA DE PRODUCTO ──────────────────────────────────────
class _TarjetaProducto extends StatelessWidget {
  final ProductoModel producto;
  const _TarjetaProducto({required this.producto});

  @override
  Widget build(BuildContext context) {
    final color = _colorDeCat(producto.categoria);
    return GestureDetector(
      onTap: () => _mostrarDetalle(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Zona emoji
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(children: [
              Center(child: Text(producto.icono, style: const TextStyle(fontSize: 52))),
              // Badge categoría
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(_capitalizar(producto.categoria),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
            ]),
          ),

          // Info del producto
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(producto.nombre, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(producto.descripcion, style: TextStyle(color: Colors.white.withOpacity(0.35),
                  fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('\$${producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
                GestureDetector(
                  onTap: () => _agregarRapido(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.add, color: color, size: 17),
                  ),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  void _agregarRapido(BuildContext context) {
    Provider.of<CarritoProvider>(context, listen: false).agregarProducto({
      'id': producto.id, 'nombre': producto.nombre, 'precio': producto.precio,
      'categoria': producto.categoria, 'icono': producto.icono,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(producto.icono, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text('${producto.nombre} agregado al carrito',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _colorDeCat(producto.categoria),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 1),
    ));
  }

  void _mostrarDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleSheet(producto: producto),
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
    else if (_tamanoSel == 'mediana')   p += 1.0;
    else if (_tamanoSel == 'familiar')  p += 4.0;
    return p * _cantidad;
  }

  @override
  Widget build(BuildContext context) {
    final color   = _colorDeCat(widget.producto.categoria);
    final opciones = widget.producto.opciones;
    final tamanos  = opciones?['tamanios'] as List? ?? opciones?['tamaños'] as List?;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Handle
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Emoji + nombre + precio
          Row(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3))),
              child: Center(child: Text(widget.producto.icono, style: const TextStyle(fontSize: 44))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_capitalizar(widget.producto.categoria),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Text(widget.producto.nombre, style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('\$${widget.producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            ])),
          ]),

          const SizedBox(height: 12),
          Text(widget.producto.descripcion,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5)),

          // Tamaños (si aplica)
          if (tamanos != null && tamanos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Tamano', style: TextStyle(color: Colors.white.withOpacity(0.6),
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: tamanos.map<Widget>((t) {
              final sel = _tamanoSel == t.toString();
              return GestureDetector(
                onTap: () => setState(() => _tamanoSel = t.toString()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.2) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? color : Colors.white.withOpacity(0.1), width: 1.5),
                  ),
                  child: Text(t.toString(), style: TextStyle(
                      color: sel ? color : Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              );
            }).toList()),
          ],

          // Notas especiales
          const SizedBox(height: 20),
          Text('Notas especiales', style: TextStyle(color: Colors.white.withOpacity(0.6),
              fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _notasCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Sin cebolla, termino de coccion, etc...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),

          // Cantidad
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Cantidad', style: TextStyle(color: Colors.white.withOpacity(0.6),
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            Row(children: [
              _BtnCantidad(icono: Icons.remove, color: color,
                  onTap: _cantidad > 1 ? () => setState(() => _cantidad--) : null),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text('$_cantidad', style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              _BtnCantidad(icono: Icons.add, color: color,
                  onTap: () => setState(() => _cantidad++)),
            ]),
          ]),

          // Botón agregar
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Provider.of<CarritoProvider>(context, listen: false).agregarProducto({
                'id': widget.producto.id,
                'nombre': widget.producto.nombre,
                'precio': widget.producto.precio,
                'categoria': widget.producto.categoria,
                'icono': widget.producto.icono,
                'cantidad': _cantidad,
                if (_tamanoSel != null) 'opcionesSeleccionadas': {'tamano': _tamanoSel},
                if (_notasCtrl.text.isNotEmpty) 'notasEspeciales': _notasCtrl.text,
                'opcionesKey': '${widget.producto.id}_$_tamanoSel',
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${widget.producto.icono} ${widget.producto.nombre} x$_cantidad agregado'),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Agregar al carrito  •  \$${_precioFinal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ])),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BtnCantidad extends StatelessWidget {
  final IconData icono;
  final Color color;
  final VoidCallback? onTap;
  const _BtnCantidad({required this.icono, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onTap != null ? color.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
      ),
      child: Icon(icono, color: onTap != null ? color : Colors.white.withOpacity(0.15), size: 18),
    ),
  );
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

String _iconoPorNombre(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('pizza'))                                              return '🍕';
  if (n.contains('hamburgues'))                                         return '🍔';
  if (n.contains('cerveza'))                                            return '🍺';
  if (n.contains('bebida')||n.contains('refresco')||n.contains('jugo')) return '🥤';
  if (n.contains('entrada')||n.contains('snack')||n.contains('papa'))   return '🍟';
  if (n.contains('ensalada'))                                           return '🥗';
  if (n.contains('postre')||n.contains('helado')||n.contains('dulce'))  return '🍰';
  if (n.contains('combo'))                                              return '🍱';
  if (n.contains('cafe')||n.contains('café'))                           return '☕';
  return '🍽️';
}

Color _colorDeCat(String cat) {
  final n = cat.toLowerCase();
  if (n.contains('pizza'))                          return const Color(0xFFFF6B35);
  if (n.contains('hamburgues'))                     return const Color(0xFFFFB800);
  if (n.contains('cerveza'))                        return const Color(0xFF38BDF8);
  if (n.contains('bebida')||n.contains('refresco')) return const Color(0xFF818CF8);
  if (n.contains('entrada')||n.contains('snack'))   return const Color(0xFFFB7185);
  if (n.contains('ensalada'))                       return const Color(0xFF4ADE80);
  if (n.contains('postre'))                         return const Color(0xFFF472B6);
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
  final _service = ProductoService();
  String? _catSel;
  String  _query  = '';
  final   _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: Column(children: [

        // Búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() { _query = v; if (v.isNotEmpty) _catSel = null; }),
              decoration: InputDecoration(
                hintText: 'Buscar en el menú...',
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
          ),
        ),

        // Chips dinámicos
        if (_query.isEmpty)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categorias')
                .where('disponible', isEqualTo: true)
                .orderBy('orden')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 42,
                  child: Center(child: SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35), strokeWidth: 2))));
              }
              final docs = snap.data!.docs;
              return SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CatChip(label: '🍽️ Todo', color: const Color(0xFFFF6B35),
                        selected: _catSel == null, onTap: () => setState(() => _catSel = null)),
                    ...List.generate(docs.length, (i) {
                      final d      = docs[i].data() as Map<String, dynamic>;
                      final nombre = (d['nombre'] as String? ?? '').trim();
                      if (nombre.isEmpty) return const SizedBox.shrink();
                      final icono  = d['icono'] as String? ?? _iconoPorNombre(nombre);
                      return _CatChip(
                        label: '$icono $nombre',
                        color: _colorPorIdx(i),
                        selected: _catSel == nombre,
                        onTap: () => setState(() => _catSel = nombre),
                      );
                    }),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 10),

        // Grid de productos
        Expanded(
          child: StreamBuilder<List<ProductoModel>>(
            stream: _service.obtenerProductos(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
              }
              var productos = snap.data ?? [];

              if (_catSel != null) {
                productos = productos.where((p) => p.categoria.trim() == _catSel!.trim()).toList();
              }
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                productos = productos.where((p) =>
                    p.nombre.toLowerCase().contains(q) ||
                    p.descripcion.toLowerCase().contains(q) ||
                    p.categoria.toLowerCase().contains(q)).toList();
              }

              if (productos.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_catSel != null ? _iconoPorNombre(_catSel!) : '🔍',
                      style: const TextStyle(fontSize: 50)),
                  const SizedBox(height: 12),
                  Text(
                    _catSel != null && _query.isEmpty
                        ? 'No hay productos en "$_catSel"'
                        : 'Sin resultados para "$_query"',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() { _catSel = null; _query = ''; _searchCtrl.clear(); }),
                    child: Text('Ver todo el menú', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                  ),
                ]));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 0.78,
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
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

// ─── CHIP ─────────────────────────────────────────────────────
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

// ─── TARJETA PRODUCTO ─────────────────────────────────────────
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
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(children: [
              Center(child: Text(producto.icono, style: const TextStyle(fontSize: 52))),
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
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(producto.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(producto.descripcion, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
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
        Text('${producto.nombre} agregado', style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _colorDeCat(producto.categoria),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 1),
    ));
  }

  void _mostrarDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
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
    if (_tamanoSel == 'mediana')  p += 1.0;
    if (_tamanoSel == 'familiar') p += 4.0;
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
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
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
              Text(widget.producto.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('\$${widget.producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            ])),
          ]),
          const SizedBox(height: 12),
          Text(widget.producto.descripcion,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5)),
          if (tamanos != null && tamanos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Tamaño', style: TextStyle(color: Colors.white.withOpacity(0.6),
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
                hintText: 'Sin cebolla, término de cocción, etc...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Cantidad', style: TextStyle(color: Colors.white.withOpacity(0.6),
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            Row(children: [
              _BtnCantidad(icono: Icons.remove, color: color,
                  onTap: _cantidad > 1 ? () => setState(() => _cantidad--) : null),
              Container(width: 48, alignment: Alignment.center,
                child: Text('$_cantidad', style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
              _BtnCantidad(icono: Icons.add, color: color,
                  onTap: () => setState(() => _cantidad++)),
            ]),
          ]),
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

// ─── BOTÓN CANTIDAD ───────────────────────────────────────────
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
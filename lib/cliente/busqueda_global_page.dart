import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import '../services/producto_service.dart';
import '../models/producto_model.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kNar  = Color(0xFFFF6B35);
const _kAzul = Color(0xFF38BDF8);
const _kVerde = Color(0xFF4ADE80);

class BusquedaGlobalPage extends StatefulWidget {
  const BusquedaGlobalPage({super.key});
  @override
  State<BusquedaGlobalPage> createState() => _BusquedaGlobalPageState();
}

class _BusquedaGlobalPageState extends State<BusquedaGlobalPage> {
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();
  String _query = '';
  String _filtro = 'todo'; // todo | productos | pedidos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white70, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Buscar productos, pedidos...',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 20),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _FiltrosChips(
            filtro: _filtro,
            onFiltro: (f) => setState(() => _filtro = f),
          ),
        ),
      ),
      body: _query.isEmpty
          ? _PantallaInicio()
          : _ResultadosBusqueda(query: _query, filtro: _filtro),
    );
  }
}

// ── Chips de filtro ───────────────────────────────────────────────────────────
class _FiltrosChips extends StatelessWidget {
  final String filtro;
  final ValueChanged<String> onFiltro;
  static const _chips = [
    ('todo',       '🔍 Todo'),
    ('productos',  '🍕 Productos'),
    ('pedidos',    '📦 Pedidos'),
  ];
  const _FiltrosChips({required this.filtro, required this.onFiltro});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: Row(children: _chips.map((c) {
      final sel = filtro == c.$1;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onFiltro(c.$1);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? _kNar.withValues(alpha: 0.15) : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel ? _kNar.withValues(alpha: 0.5) : Colors.white12,
                width: sel ? 1.5 : 1),
          ),
          child: Text(c.$2, style: TextStyle(
              color: sel ? _kNar : Colors.white38,
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ),
      );
    }).toList()),
  );
}

// ── Pantalla inicial (sin query) ──────────────────────────────────────────────
class _PantallaInicio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔍', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('¿Qué buscas?',
          style: TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Productos del menú, pedidos anteriores...',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
      const SizedBox(height: 32),
      // Sugerencias rápidas
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Wrap(spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: ['Pizza', 'Pasta', 'Bebidas', 'Ofertas',
              'Mis pedidos'].map((s) =>
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(s, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13)),
              ),
            ),
          ).toList()),
      ),
    ]));
  }
}

// ── Resultados de búsqueda ────────────────────────────────────────────────────
class _ResultadosBusqueda extends StatelessWidget {
  final String query, filtro;
  const _ResultadosBusqueda({required this.query, required this.filtro});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── Productos ──────────────────────────────────────────────────────
        if (filtro == 'todo' || filtro == 'productos')
          StreamBuilder<List<ProductoModel>>(
            stream: ProductoService().obtenerProductos(),
            builder: (_, snap) {
              final productos = (snap.data ?? []).where((p) =>
                  p.nombre.toLowerCase().contains(q) ||
                  p.descripcion.toLowerCase().contains(q) ||
                  p.categoria.toLowerCase().contains(q)).toList();

              if (productos.isEmpty && filtro == 'productos') {
                return _EmptyResult('productos', query);
              }
              if (productos.isEmpty) return const SizedBox.shrink();

              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTit('🍕 Productos (${productos.length})'),
                ...productos.take(5).map((p) => _ProductoTile(producto: p)),
                if (productos.length > 5)
                  _VerMas('${productos.length - 5} productos más'),
                const SizedBox(height: 16),
              ]);
            },
          ),

        // ── Pedidos ────────────────────────────────────────────────────────
        if (filtro == 'todo' || filtro == 'pedidos')
          Builder(builder: (_) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return const SizedBox.shrink();
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .where('clienteId', isEqualTo: uid)
                  .orderBy('fecha', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (_, snap) {
                final pedidos = (snap.data?.docs ?? [])
                    .map((d) => PedidoModel.fromFirestore(
                        d.id, d.data() as Map<String, dynamic>))
                    .where((p) =>
                        p.id.toLowerCase().contains(q) ||
                        p.estado.toLowerCase().contains(q) ||
                        p.tipoPedido.toLowerCase().contains(q) ||
                        p.items.any((i) =>
                            (i['nombre'] ?? i['productoNombre'] ?? '')
                                .toString().toLowerCase().contains(q)))
                    .toList();

                if (pedidos.isEmpty && filtro == 'pedidos') {
                  return _EmptyResult('pedidos', query);
                }
                if (pedidos.isEmpty) return const SizedBox.shrink();

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SecTit('📦 Pedidos (${pedidos.length})'),
                  ...pedidos.take(5).map((p) => _PedidoTile(pedido: p)),
                  if (pedidos.length > 5)
                    _VerMas('${pedidos.length - 5} pedidos más'),
                  const SizedBox(height: 16),
                ]);
              },
            );
          }),

        // Sin resultados
        if (filtro == 'todo')
          FutureBuilder(
            future: Future.delayed(const Duration(milliseconds: 500)),
            builder: (_, snap) => snap.connectionState == ConnectionState.done
                ? _EmptyResult('resultados', query)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

// ── Tile de producto ──────────────────────────────────────────────────────────
class _ProductoTile extends StatelessWidget {
  final ProductoModel producto;
  const _ProductoTile({required this.producto});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kNar.withValues(alpha: 0.15)),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kNar.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(producto.icono,
            style: const TextStyle(fontSize: 22))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(producto.nombre, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        Text(producto.categoria, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
      ])),
      Text('\$${producto.precio.toStringAsFixed(2)}',
          style: const TextStyle(color: _kVerde,
              fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  );
}

// ── Tile de pedido ────────────────────────────────────────────────────────────
class _PedidoTile extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoTile({required this.pedido});

  Color _col(String e) {
    switch (e) {
      case 'Entregado': return _kVerde;
      case 'Cancelado': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _col(pedido.estado).withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _col(pedido.estado).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(
          pedido.estado == 'Entregado' ? '✅'
              : pedido.estado == 'Cancelado' ? '❌' : '📦',
          style: const TextStyle(fontSize: 20))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${pedido.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13)),
        Text('${pedido.items.length} producto(s) · ${pedido.tipoPedido}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('\$${pedido.total.toStringAsFixed(2)}',
            style: TextStyle(color: _col(pedido.estado),
                fontWeight: FontWeight.w800, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _col(pedido.estado).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
          child: Text(pedido.estado, style: TextStyle(
              color: _col(pedido.estado), fontSize: 9,
              fontWeight: FontWeight.w700))),
      ]),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Widget _SecTit(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t, style: const TextStyle(color: Colors.white,
      fontWeight: FontWeight.w700, fontSize: 14)),
);

Widget _VerMas(String msg) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 4),
  child: Text('+ $msg', style: TextStyle(
      color: _kNar.withValues(alpha: 0.7), fontSize: 12)),
);

Widget _EmptyResult(String tipo, String query) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 20),
  child: Center(child: Column(children: [
    const Text('🔍', style: TextStyle(fontSize: 36)),
    const SizedBox(height: 8),
    Text('Sin $tipo para "$query"', style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
  ])),
);
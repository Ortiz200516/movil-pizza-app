import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/launcher_service.dart';
import '../services/auth_services.dart';
import '../services/notificacion_service.dart';
import '../services/producto_service.dart';
import '../models/pedido_model.dart';
import '../models/producto_model.dart';
import '../pedidos/pedidos_service.dart';

const _kTeal = Color(0xFF0F766E);
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kGreen = Color(0xFF2DD4BF);

class HomeMesero extends StatefulWidget {
  const HomeMesero({super.key});
  @override State<HomeMesero> createState() => _HomeMeseroState();
}

class _HomeMeseroState extends State<HomeMesero> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _MeseroAppBar(uid: uid),
        body: TabBarView(children: [
          _TabMesas(meseroUid: uid),
          const _TabPedidos(),
          _TabNuevaOrden(meseroUid: uid),
        ]),
      ),
    );
  }
}

// ── AppBar con resumen del turno ──────────────────────────────────────────────
class _MeseroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String uid;
  const _MeseroAppBar({required this.uid});
  @override Size get preferredSize => const Size.fromHeight(110);

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('meseroId', isEqualTo: uid)
          .where('estado', isEqualTo: 'Entregado')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final pedidos = docs.map((d) =>
            PedidoModel.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();
        final totalVentas = pedidos.fold(0.0, (s, p) => s + p.total);
        final totalOrds   = pedidos.length;

        return AppBar(
          backgroundColor: _kBg,
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 16,
          title: Row(children: [
            const Text('🍽️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Panel Mesero', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Hoy: $totalOrds órdenes · \$${totalVentas.toStringAsFixed(2)}',
                  style: const TextStyle(color: _kGreen,
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ]),
          actions: [
            NotifBadgeBtn(uid: uid, rol: 'mesero'),
            IconButton(
              icon: const Icon(Icons.logout_outlined, size: 20),
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: _kGreen,
            labelColor: _kGreen,
            unselectedLabelColor: Colors.white38,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.table_restaurant, size: 20), text: 'Mesas'),
              Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Pedidos'),
              Tab(icon: Icon(Icons.add_shopping_cart, size: 20), text: 'Nueva Orden'),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════ TAB 1: MESAS ══════════════════════════════════════════
class _TabMesas extends StatelessWidget {
  final String meseroUid;
  const _TabMesas({required this.meseroUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesas')
          .where('activa', isEqualTo: true)
          .orderBy('numero')
          .snapshots(),
      builder: (context, mesasSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pedidos')
              .where('tipoPedido', isEqualTo: 'mesa')
              .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
              .snapshots(),
          builder: (context, pedidosSnap) {
            final mesas       = mesasSnap.data?.docs ?? [];
            final pedidosDocs = pedidosSnap.data?.docs ?? [];

            final Map<int, Map<String, dynamic>> mesaConPedido = {};
            for (final doc in pedidosDocs) {
              final d = doc.data() as Map<String, dynamic>;
              final n = d['numeroMesa'];
              if (n != null) mesaConPedido[n as int] = {'id': doc.id, ...d};
            }

            final libres   = mesas.where((m) {
              final d = m.data() as Map<String, dynamic>;
              return !mesaConPedido.containsKey(d['numero']);
            }).length;
            final ocupadas = mesaConPedido.length;
            final listas   = mesaConPedido.values
                .where((p) => p['estado'] == 'Listo').length;

            return Column(children: [
              // ── Barra de stats ──────────────────────
              Container(
                color: const Color(0xFF0D1B2A),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(children: [
                  _StatChip('🟢', 'Libres', libres, Colors.green),
                  const SizedBox(width: 8),
                  _StatChip('🟠', 'Ocupadas', ocupadas, Colors.orange),
                  const SizedBox(width: 8),
                  _StatChip('✅', '¡Listas!', listas, _kGreen),
                ]),
              ),

              if (mesas.isEmpty)
                const Expanded(child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🍽️', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 12),
                  Text('No hay mesas activas',
                      style: TextStyle(color: Colors.white38, fontSize: 16)),
                ])))
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 10,
                        mainAxisSpacing: 10, childAspectRatio: 0.82),
                    itemCount: mesas.length,
                    itemBuilder: (_, i) {
                      final d      = mesas[i].data() as Map<String, dynamic>;
                      final numero = d['numero'] as int;
                      final cap    = d['capacidad'] as int? ?? 4;
                      final pedido = mesaConPedido[numero];
                      return _MesaCard(
                        numero: numero, capacidad: cap, pedido: pedido,
                        onTap: () => pedido != null
                            ? _verDetalle(context, pedido)
                            : _tomarOrden(context, numero),
                      );
                    },
                  ),
                ),
            ]);
          },
        );
      },
    );
  }

  void _verDetalle(BuildContext context, Map<String, dynamic> pedido) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleMesaSheet(pedido: pedido),
    );
  }

  void _tomarOrden(BuildContext context, int mesa) {
    DefaultTabController.of(context).animateTo(2);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🍽️ Tomando orden para Mesa $mesa'),
      backgroundColor: _kTeal,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ══════════════════════ TAB 2: PEDIDOS ACTIVOS ════════════════════════════════
class _TabPedidos extends StatelessWidget {
  const _TabPedidos();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
          .orderBy('fecha', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _kGreen));
        }
        final pedidos = snap.data!.docs
            .map((d) => PedidoModel.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        if (pedidos.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📋', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 14),
            const Text('Sin pedidos activos', style: TextStyle(
                color: Colors.white38, fontSize: 17,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Todos los pedidos están al día 👍',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ]));
        }

        final listos     = pedidos.where((p) => p.estado == 'Listo').toList();
        final preparando = pedidos.where((p) => p.estado == 'Preparando').toList();
        final pendientes = pedidos.where((p) => p.estado == 'Pendiente').toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (listos.isNotEmpty) ...[
              _GrupoHeader('✅ Listos para entregar', Colors.green, listos.length),
              ...listos.map((p) => _PedidoCard(pedido: p)),
              const SizedBox(height: 8),
            ],
            if (preparando.isNotEmpty) ...[
              _GrupoHeader('👨‍🍳 En cocina', Colors.blue, preparando.length),
              ...preparando.map((p) => _PedidoCard(pedido: p)),
              const SizedBox(height: 8),
            ],
            if (pendientes.isNotEmpty) ...[
              _GrupoHeader('⏳ Pendientes', Colors.orange, pendientes.length),
              ...pendientes.map((p) => _PedidoCard(pedido: p)),
            ],
          ],
        );
      },
    );
  }
}

class _GrupoHeader extends StatelessWidget {
  final String titulo; final Color color; final int count;
  const _GrupoHeader(this.titulo, this.color, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Row(children: [
      Text(titulo, style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    ]),
  );
}

class _PedidoCard extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoCard({required this.pedido});

  Color get _color {
    switch (pedido.estado) {
      case 'Listo':      return Colors.green;
      case 'Preparando': return Colors.blue;
      default:           return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(pedido.iconoEstado,
                  style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  pedido.tipoPedido == 'mesa'
                      ? '🍽️ Mesa ${pedido.numeroMesa}'
                      : '🛵 Domicilio',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(pedido.estado, style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 3),
              Text('${pedido.clienteNombre}  •  ${pedido.items.length} producto(s)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${pedido.total.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900,
                      fontSize: 16)),
              // Timer del pedido
              _MiniTimer(fecha: pedido.fecha),
            ]),
          ]),
        ),

        // Items
        if (pedido.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              children: pedido.items.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5)),
                    child: Center(child: Text('${item['cantidad'] ?? 1}',
                        style: TextStyle(color: color, fontSize: 10,
                            fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    item['productoNombre'] ?? item['nombre'] ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                  if ((item['notasEspeciales'] as String? ?? '').isNotEmpty)
                    const Text('📝', style: TextStyle(fontSize: 11)),
                ]),
              )).toList(),
            ),
          ),

        // Botón si está listo
        if (pedido.estado == 'Listo')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final ok = await PedidoService()
                      .actualizarEstado(pedido.id, 'Entregado');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ Entregado' : '❌ Error'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('MARCAR ENTREGADO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════ TAB 3: NUEVA ORDEN ════════════════════════════════════
class _TabNuevaOrden extends StatefulWidget {
  final String meseroUid;
  const _TabNuevaOrden({required this.meseroUid});
  @override State<_TabNuevaOrden> createState() => _TabNuevaOrdenState();
}

class _TabNuevaOrdenState extends State<_TabNuevaOrden> {
  int? _mesaSel;
  String? _catSel;
  final Map<String, int> _carrito = {};
  final Map<String, ProductoModel> _productosMap = {};
  final Map<String, String> _notas = {}; // productoId → nota
  bool _enviando = false;

  double get _total => _carrito.entries.fold(0.0, (s, e) {
    final p = _productosMap[e.key];
    return s + (p?.precio ?? 0) * e.value;
  });

  void _agregar(ProductoModel p) {
    HapticFeedback.selectionClick();
    setState(() {
      _productosMap[p.id] = p;
      _carrito[p.id] = (_carrito[p.id] ?? 0) + 1;
    });
  }

  void _quitar(String id) => setState(() {
    if ((_carrito[id] ?? 0) <= 1) {
      _carrito.remove(id);
      _notas.remove(id);
    } else {
      _carrito[id] = _carrito[id]! - 1;
    }
  });

  void _editarNota(String productoId, String nombre) {
    final ctrl = TextEditingController(text: _notas[productoId] ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('📝 Nota para $nombre',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej: sin cebolla, extra salsa...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true, fillColor: _kBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kGreen.withValues(alpha: 0.4))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGreen, width: 2)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: () {
                setState(() => _notas.remove(productoId));
                Navigator.pop(context);
              },
              child: const Text('Limpiar', style: TextStyle(color: Colors.red)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () {
                setState(() => _notas[productoId] = ctrl.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _confirmar() async {
    if (_mesaSel == null) { _snack('Selecciona una mesa', Colors.orange); return; }
    if (_carrito.isEmpty) { _snack('Agrega al menos un producto', Colors.orange); return; }
    setState(() => _enviando = true);
    try {
      final items = _carrito.entries.map((e) {
        final p = _productosMap[e.key]!;
        return {
          'productoId':      p.id,
          'productoNombre':  p.nombre,
          'precioUnitario':  p.precio,
          'cantidad':        e.value,
          'precioTotal':     p.precio * e.value,
          'icono':           p.icono,
          'imagenUrl':       p.imagenUrl ?? '',
          'notasEspeciales': _notas[p.id] ?? '',
        };
      }).toList();

      final subtotal = _total;
      final impuesto = subtotal * 0.15;
      final total    = subtotal + impuesto;

      await FirebaseFirestore.instance.collection('pedidos').add({
        'clienteId':     widget.meseroUid,
        'clienteNombre': 'Mesa $_mesaSel (Mesero)',
        'userId':        widget.meseroUid,
        'meseroId':      widget.meseroUid,
        'items':         items,
        'subtotal':      subtotal,
        'impuesto':      impuesto,
        'total':         total,
        'tipoPedido':    'mesa',
        'numeroMesa':    _mesaSel,
        'estado':        'Pendiente',
        'metodoPago':    'efectivo',
        'fecha':         FieldValue.serverTimestamp(),
        'codigoVerificacion':
            (100000 + (items.length * 12345) % 900000).toString(),
        'verificado': false,
      });

      await NotificacionService.notificarRol(
        rol: 'cocinero',
        titulo: '🍕 Nueva orden — Mesa $_mesaSel',
        cuerpo: '${items.length} producto(s) · \$${total.toStringAsFixed(2)}',
        tipo: 'pedido',
      );

      setState(() {
        _carrito.clear();
        _notas.clear();
        _mesaSel = null;
        _catSel  = null;
      });
      HapticFeedback.heavyImpact();
      _snack('✅ Orden enviada a cocina', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Selector de mesa ───────────────────────
      Container(
        color: const Color(0xFF0D1B2A),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          const Text('🍽️ Mesa:', style: TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mesas')
                  .where('activa', isEqualTo: true)
                  .orderBy('numero')
                  .snapshots(),
              builder: (_, snap) {
                final mesas = snap.data?.docs ?? [];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: mesas.map((m) {
                      final n   = (m.data() as Map)['numero'] as int;
                      final sel = _mesaSel == n;
                      return GestureDetector(
                        onTap: () => setState(() => _mesaSel = n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          width: 44, height: 36,
                          decoration: BoxDecoration(
                            color: sel ? _kTeal.withValues(alpha: 0.3) : _kCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? _kGreen : Colors.white12,
                              width: sel ? 2 : 1),
                          ),
                          child: Center(child: Text('$n', style: TextStyle(
                              color: sel ? _kGreen : Colors.white38,
                              fontWeight: FontWeight.bold))),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ]),
      ),

      // ── Chips de categoría ─────────────────────
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categorias').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          return SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _CatChip(label: '🍽️ Todo', sel: _catSel == null,
                    onTap: () => setState(() => _catSel = null)),
                ...docs.map((d) {
                  final data   = d.data() as Map<String, dynamic>;
                  final nombre = data['nombre'] as String? ?? '';
                  final icono  = data['icono'] as String? ?? '🍽️';
                  return _CatChip(
                    label: '$icono $nombre', sel: _catSel == nombre,
                    onTap: () => setState(() => _catSel = nombre));
                }),
              ],
            ),
          );
        },
      ),

      // ── Grid de productos ──────────────────────
      Expanded(
        child: StreamBuilder<List<ProductoModel>>(
          stream: ProductoService().obtenerProductos(),
          builder: (_, snap) {
            var prods = snap.data ?? [];
            if (_catSel != null) {
              prods = prods.where((p) => p.categoria == _catSel).toList();
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8,
                  mainAxisSpacing: 8, childAspectRatio: 0.75),
              itemCount: prods.length,
              itemBuilder: (_, i) {
                final p   = prods[i];
                final qty = _carrito[p.id] ?? 0;
                return _ProductoOrdenCard(
                  producto: p, cantidad: qty,
                  nota: _notas[p.id] ?? '',
                  onAgregar: () => _agregar(p),
                  onQuitar:  () => _quitar(p.id),
                  onNota: qty > 0
                      ? () => _editarNota(p.id, p.nombre) : null,
                );
              },
            );
          },
        ),
      ),

      // ── Barra inferior con resumen ─────────────
      if (_carrito.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(children: [
            // Mini resumen de items
            if (_carrito.length <= 3)
              ...(_carrito.entries.map((e) {
                final p = _productosMap[e.key];
                if (p == null) return const SizedBox.shrink();
                final nota = _notas[e.key] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Text('${e.value}×', style: const TextStyle(
                        color: _kGreen, fontWeight: FontWeight.bold,
                        fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(p.nombre, style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (nota.isNotEmpty)
                      const Text('📝', style: TextStyle(fontSize: 11)),
                    Text('\$${(p.precio * e.value).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white38,
                            fontSize: 11)),
                  ]),
                );
              }))
            else
              Text('${_carrito.values.fold(0, (s, v) => s + v)} productos '
                  'en la orden',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),

            const SizedBox(height: 8),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total (+ 15% imp.)',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text('\$${(_total * 1.15).toStringAsFixed(2)}',
                    style: const TextStyle(color: _kGreen,
                        fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _confirmar,
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, size: 18),
                  label: Text(_enviando ? 'Enviando...' : 'ENVIAR A COCINA',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

/// Tarjeta de mesa con timer y pulso animado
class _MesaCard extends StatefulWidget {
  final int numero, capacidad;
  final Map<String, dynamic>? pedido;
  final VoidCallback onTap;
  const _MesaCard({required this.numero, required this.capacidad,
      this.pedido, required this.onTap});
  @override State<_MesaCard> createState() => _MesaCardState();
}

class _MesaCardState extends State<_MesaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Timer _timer;
  late DateTime _ahora;

  @override
  void initState() {
    super.initState();
    _ahora = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30),
        (_) { if (mounted) setState(() => _ahora = DateTime.now()); });
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() { _timer.cancel(); _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ocupada = widget.pedido != null;
    final listo   = widget.pedido?['estado'] == 'Listo';
    final color   = listo ? Colors.green
        : ocupada ? Colors.orange : Colors.white24;

    // Tiempo ocupada
    String? tiempoStr;
    if (ocupada) {
      final fecha = widget.pedido!['fecha'];
      if (fecha is Timestamp) {
        final diff = _ahora.difference(fecha.toDate());
        tiempoStr = diff.inMinutes < 60
            ? '${diff.inMinutes}m' : '${diff.inHours}h';
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: ocupada ? color.withValues(alpha: 0.1) : _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: listo
                  ? Colors.green.withValues(alpha: 0.4 + _pulseCtrl.value * 0.4)
                  : color.withValues(alpha: 0.5),
              width: listo ? 2 : 1.5,
            ),
            boxShadow: listo ? [BoxShadow(
                color: Colors.green.withValues(alpha: 0.05 + _pulseCtrl.value * 0.12),
                blurRadius: 12, spreadRadius: 2)] : null,
          ),
          child: child,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(listo ? '✅' : ocupada ? '🔴' : '🟢',
              style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text('${widget.numero}', style: TextStyle(
              color: color == Colors.white24 ? Colors.white70 : color,
              fontSize: 22, fontWeight: FontWeight.w900)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people, size: 11, color: Colors.white24),
            Text(' ${widget.capacidad}',
                style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ]),
          if (tiempoStr != null)
            Text(tiempoStr, style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          if (!ocupada)
            const Text('Libre',
                style: TextStyle(color: Colors.white24, fontSize: 9)),
        ]),
      ),
    );
  }
}

/// Tarjeta de producto para nueva orden
class _ProductoOrdenCard extends StatelessWidget {
  final ProductoModel producto;
  final int cantidad;
  final String nota;
  final VoidCallback onAgregar, onQuitar;
  final VoidCallback? onNota;
  const _ProductoOrdenCard({
    required this.producto, required this.cantidad,
    required this.nota, required this.onAgregar,
    required this.onQuitar, this.onNota,
  });

  @override
  Widget build(BuildContext context) {
    final tiene = cantidad > 0;
    return GestureDetector(
      onTap: onAgregar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: tiene ? _kTeal.withValues(alpha: 0.15) : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tiene ? _kGreen.withValues(alpha: 0.6) : Colors.white12,
            width: tiene ? 1.5 : 1),
        ),
        child: Column(children: [
          // Imagen o emoji
          Expanded(child: Stack(children: [
            Center(
              child: producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11)),
                      child: Image.network(producto.imagenUrl!,
                          fit: BoxFit.cover, width: double.infinity,
                          errorBuilder: (_, __, ___) => Text(producto.icono,
                              style: const TextStyle(fontSize: 30))))
                  : Text(producto.icono,
                      style: const TextStyle(fontSize: 30)),
            ),
            // Badge nota
            if (nota.isNotEmpty)
              Positioned(top: 4, right: 4,
                child: GestureDetector(
                  onTap: onNota,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle),
                    child: const Text('📝',
                        style: TextStyle(fontSize: 8)),
                  ),
                ),
              ),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Column(children: [
              Text(producto.nombre, style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
              Text('\$${producto.precio.toStringAsFixed(2)}',
                  style: const TextStyle(color: _kGreen,
                      fontSize: 10, fontWeight: FontWeight.bold)),
              if (tiene)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  GestureDetector(onTap: onQuitar,
                    child: const Icon(Icons.remove_circle,
                        color: Colors.red, size: 18)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('$cantidad', style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 14))),
                  GestureDetector(onTap: onAgregar,
                    child: const Icon(Icons.add_circle,
                        color: _kGreen, size: 18)),
                  // Botón nota
                  if (onNota != null) ...[
                    const SizedBox(width: 2),
                    GestureDetector(onTap: onNota,
                      child: Icon(Icons.edit_note,
                          color: nota.isNotEmpty
                              ? Colors.amber : Colors.white24,
                          size: 16)),
                  ],
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _CatChip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: sel ? _kTeal.withValues(alpha: 0.2) : _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sel ? _kGreen : Colors.white12,
          width: sel ? 1.5 : 1),
      ),
      child: Text(label, style: TextStyle(
        color: sel ? _kGreen : Colors.white38,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12)),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final String emoji, label; final int count; final Color color;
  const _StatChip(this.emoji, this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text('$count $label', style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );
}

/// Mini timer para la tab de pedidos
class _MiniTimer extends StatefulWidget {
  final DateTime fecha;
  const _MiniTimer({required this.fecha});
  @override State<_MiniTimer> createState() => _MiniTimerState();
}

class _MiniTimerState extends State<_MiniTimer> {
  late Timer _timer;
  late DateTime _ahora;
  @override
  void initState() {
    super.initState();
    _ahora = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30),
        (_) { if (mounted) setState(() => _ahora = DateTime.now()); });
  }
  @override void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mins = _ahora.difference(widget.fecha).inMinutes;
    final color = mins >= 20 ? Colors.red
        : mins >= 10 ? Colors.orange : Colors.white24;
    return Text(mins == 0 ? 'Ahora' : '${mins}m',
        style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.bold));
  }
}

/// Bottom sheet de detalle de mesa mejorado
class _DetalleMesaSheet extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _DetalleMesaSheet({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final estado = pedido['estado'] as String? ?? '';
    final mesa   = pedido['numeroMesa'];
    final items  = (pedido['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total  = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final listo  = estado == 'Listo';
    final color  = listo ? Colors.green : Colors.orange;

    // Tiempo transcurrido
    String tiempoStr = '';
    final fecha = pedido['fecha'];
    if (fecha is Timestamp) {
      final diff = DateTime.now().difference(fecha.toDate());
      tiempoStr = diff.inMinutes < 60
          ? '${diff.inMinutes} min' : '${diff.inHours}h ${diff.inMinutes % 60}m';
    }

    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white12,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('$mesa',
                style: TextStyle(color: color, fontSize: 20,
                    fontWeight: FontWeight.bold)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mesa $mesa', style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(estado, style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12))),
              if (tiempoStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('⏱ $tiempoStr',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ]),
          ])),
          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(
              color: _kGreen, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const Divider(color: Colors.white10, height: 24),

        // Items
        ...items.map((item) {
          final nota = (item['notasEspeciales'] as String? ?? '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: _kTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Text('${item['cantidad']}',
                      style: const TextStyle(color: _kGreen,
                          fontWeight: FontWeight.bold)))),
                const SizedBox(width: 10),
                Expanded(child: Text(item['productoNombre'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14))),
                Text('\$${((item['precioTotal'] ?? 0.0) as num).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
              if (nota.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38, top: 2),
                  child: Text('📝 $nota',
                      style: const TextStyle(color: Colors.amber, fontSize: 11)),
                ),
            ]),
          );
        }),
        const SizedBox(height: 12),

        // Botones
        if (listo)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                await PedidoService().actualizarEstado(pedido['id'], 'Entregado');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Mesa marcada como entregada'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating));
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('MARCAR ENTREGADO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            ),
          ),
      ]),
    );
  }
}
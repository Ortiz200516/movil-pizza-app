import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../carrito/carrito_provider.dart';
import '../models/pedido_model.dart';
import '../cliente/fidelidad_page.dart';
import '../services/fidelidad_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kNar2  = Color(0xFFFF6B00);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);
const _kMor   = Color(0xFFA78BFA);
const _kAmb   = Color(0xFFFFD700);

// ── HomeScreen — pantalla de inicio del cliente ───────────────────────────────
class HomeScreen extends StatefulWidget {
  final VoidCallback onIrAlMenu;
  final VoidCallback onIrAPedidos;
  final VoidCallback onIrAlCarrito;
  final VoidCallback onIrAPuntos;
  const HomeScreen({
    super.key,
    required this.onIrAlMenu,
    required this.onIrAPedidos,
    required this.onIrAlCarrito,
    required this.onIrAPuntos,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user    = FirebaseAuth.instance.currentUser;
    final carrito = Provider.of<CarritoProvider>(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Hero banner ─────────────────────────────────────────────────
          _HeroBanner(
            user: user,
            carritoCant: carrito.cantidadTotal,
            onCarrito: widget.onIrAlCarrito,
          ),
          const SizedBox(height: 16),

          // ── Pedido activo (si existe) ───────────────────────────────────
          _PedidoActivoBanner(onTap: widget.onIrAPedidos),

          // ── Accesos rápidos ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _AccesosRapidos(
              onMenu:    widget.onIrAlMenu,
              onPedidos: widget.onIrAPedidos,
              onPuntos:  widget.onIrAPuntos,
            ),
          ),

          // ── Tarjeta de fidelidad ────────────────────────────────────────
          FidelidadCard(onTap: widget.onIrAPuntos),
          const SizedBox(height: 16),

          // ── Promociones activas ─────────────────────────────────────────
          _PromocionesHome(onVerMenu: widget.onIrAlMenu),

          // ── Info del local ──────────────────────────────────────────────
          const _InfoLocalCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── Hero banner superior ──────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final User? user;
  final int carritoCant;
  final VoidCallback onCarrito;
  const _HeroBanner({this.user, required this.carritoCant,
      required this.onCarrito});

  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️ Buenos días';
    if (h < 19) return '🌤️ Buenas tardes';
    return '🌙 Buenas noches';
  }

  String get _nombre {
    if (user?.displayName?.isNotEmpty == true) {
      return user!.displayName!.split(' ').first;
    }
    return 'amigo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(children: [
        // Fondo decorativo
        Positioned(
          right: -20, top: -20,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kNar.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          right: 20, bottom: 10,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kNar.withValues(alpha: 0.04),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Saludo + avatar
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kNar2, _kNar],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _kNar.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(child: Text(
                  _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 18),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_saludo, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12)),
                Text(_nombre, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900,
                    fontSize: 20)),
              ])),
              // Badge carrito
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCarrito();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: carritoCant > 0
                        ? _kNar.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: carritoCant > 0
                          ? _kNar.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.shopping_cart_outlined,
                        color: carritoCant > 0 ? _kNar : Colors.white38,
                        size: 18),
                    if (carritoCant > 0) ...[
                      const SizedBox(width: 6),
                      Text('$carritoCant',
                          style: const TextStyle(
                              color: _kNar, fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ],
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Frase motivadora
            Text('¿Qué te apetece hoy?',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13)),
            const SizedBox(height: 6),
            const Text('🍕 La mejor pizza de Guayaquil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 22)),
            const SizedBox(height: 4),
            Text('Hecha con ingredientes frescos, lista en minutos',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

// ── Pedido activo (si el cliente tiene uno en curso) ──────────────────────────
class _PedidoActivoBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PedidoActivoBanner({required this.onTap});

  Color _estadoColor(String e) {
    switch (e) {
      case 'Preparando': return _kNar;
      case 'Listo':      return _kAmb;
      case 'En camino':  return _kAzul;
      default:           return Colors.white38;
    }
  }

  String _estadoMsg(String e) {
    switch (e) {
      case 'Pendiente':  return 'Tu pedido fue recibido ⏳';
      case 'Preparando': return 'El cocinero está preparando tu pedido 👨‍🍳';
      case 'Listo':      return '¡Tu pedido está listo! 🎉';
      case 'En camino':  return 'Tu pedido viene en camino 🛵';
      default:           return e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('clienteId', isEqualTo: uid)
          .where('estado', whereIn: ['Pendiente','Preparando','Listo','En camino'])
          .orderBy('fecha', descending: true)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final doc    = snap.data!.docs.first;
        final pedido = PedidoModel.fromFirestore(
            doc.id, doc.data() as Map<String, dynamic>);
        final color  = _estadoColor(pedido.estado);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4),
                  width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  pedido.estado == 'En camino' ? '🛵' :
                  pedido.estado == 'Listo'     ? '✅' :
                  pedido.estado == 'Preparando'? '👨‍🍳' : '⏳',
                  style: const TextStyle(fontSize: 22),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pedido activo', style: TextStyle(
                    color: color, fontWeight: FontWeight.w800,
                    fontSize: 13)),
                Text(_estadoMsg(pedido.estado), style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12)),
                Text('\$${pedido.total.toStringAsFixed(2)} · '
                    '${pedido.tipoPedido}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11)),
              ])),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.6), size: 22),
            ]),
          ),
        );
      },
    );
  }
}

// ── Accesos rápidos ───────────────────────────────────────────────────────────
class _AccesosRapidos extends StatelessWidget {
  final VoidCallback onMenu, onPedidos, onPuntos;
  const _AccesosRapidos({required this.onMenu,
      required this.onPedidos, required this.onPuntos});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.restaurant_menu_rounded, '🍕', 'Ver menú',     _kNar,   onMenu),
      (Icons.receipt_long_rounded,    '📦', 'Mis pedidos',  _kAzul,  onPedidos),
      (Icons.stars_rounded,           '⭐', 'Mis puntos',   _kAmb,   onPuntos),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(child: Padding(
          padding: EdgeInsets.only(
              right: item == items.last ? 0 : 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              item.$5();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: item.$4.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: item.$4.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(item.$2,
                      style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(height: 8),
                Text(item.$3, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        ));
      }).toList(),
    );
  }
}

// ── Promociones activas (carrusel) ────────────────────────────────────────────
class _PromocionesHome extends StatefulWidget {
  final VoidCallback onVerMenu;
  const _PromocionesHome({required this.onVerMenu});
  @override
  State<_PromocionesHome> createState() => _PromocionesHomeState();
}

class _PromocionesHomeState extends State<_PromocionesHome> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promociones')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final promos = snap.data!.docs.where((d) {
          final data  = d.data() as Map<String, dynamic>;
          final fin   = (data['fin'] as Timestamp?)?.toDate();
          final inicio = (data['inicio'] as Timestamp?)?.toDate();
          if (fin != null && fin.isBefore(now)) return false;
          if (inicio != null && inicio.isAfter(now)) return false;
          return true;
        }).toList();

        if (promos.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Text('🔥 OFERTAS', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onVerMenu,
                child: Text('Ver todas', style: TextStyle(
                    color: _kNar.withValues(alpha: 0.8),
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          SizedBox(
            height: 130,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.88),
              onPageChanged: (i) => setState(() => _pagina = i),
              itemCount: promos.length,
              itemBuilder: (_, i) {
                final data = promos[i].data() as Map<String, dynamic>;
                final titulo   = data['titulo']      as String? ?? '';
                final desc     = data['descripcion'] as String? ?? '';
                final descuento = data['descuento']  as String? ?? '';
                final colHex   = data['color']       as String? ?? 'FF6B35';

                Color color;
                try {
                  color = Color(int.parse('FF$colHex', radix: 16));
                } catch (_) { color = _kNar; }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(
                      right: 10,
                      left: i == 0 ? 16 : 0,
                      bottom: _pagina == i ? 0 : 6,
                      top: _pagina == i ? 0 : 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: color.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text(titulo, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: 15), maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(desc, style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12), maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: widget.onVerMenu,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: color.withValues(alpha: 0.4)),
                          ),
                          child: Text('Ver en menú →',
                              style: TextStyle(color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ),
                      ),
                    ])),
                    if (descuento.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 2),
                        ),
                        child: Center(child: Text(descuento,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w900,
                                fontSize: 14))),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ),

          // Dots indicadores
          if (promos.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(promos.length, (i) =>
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _pagina == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _pagina == i
                          ? _kNar
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ]);
      },
    );
  }
}

// ── Info del local ────────────────────────────────────────────────────────────
class _InfoLocalCard extends StatelessWidget {
  const _InfoLocalCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config_local').doc('info').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final d        = snap.data!.data() as Map<String, dynamic>;
        final nombre   = d['nombre']   as String? ?? 'La Italiana';
        final horario  = d['horario']  as String? ?? '';
        final telefono = d['telefono'] as String? ?? '';
        final slogan   = d['slogan']   as String? ?? '';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kNar.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🍕',
                    style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 15)),
                if (slogan.isNotEmpty)
                  Text(slogan, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11)),
              ])),
            ]),
            if (horario.isNotEmpty || telefono.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
              const SizedBox(height: 12),
              if (horario.isNotEmpty)
                _InfoFila('🕐', horario),
              if (telefono.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InfoFila('📞', telefono),
              ],
            ],
          ]),
        );
      },
    );
  }
}

class _InfoFila extends StatelessWidget {
  final String emoji, texto;
  const _InfoFila(this.emoji, this.texto);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 8),
    Expanded(child: Text(texto, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45), fontSize: 12))),
  ]);
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../cliente/menu_page.dart';
import '../cliente/mis_pedidos_page.dart';
import '../cliente/perfil_page.dart';
import '../carrito/carrito_page.dart';
import '../carrito/carrito_provider.dart';
import '../cliente/fidelidad_page.dart';
import '../cliente/home_screen.dart';
import '../cliente/reservas_page.dart';
import '../services/theme_provider.dart';

const _kNaranja  = Color(0xFFFF6B35);
const _kNaranja2 = Color(0xFFFF6B00);
const _kBg       = Color(0xFF0F172A);

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});
  @override
  State<HomeCliente> createState() => _HomeClienteState();
}

class _HomeClienteState extends State<HomeCliente>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _cambiarTab(int i) {
    if (i == _idx) return;
    _animCtrl.forward(from: 0);
    setState(() => _idx = i);
  }

  static const _titles = ['Inicio', 'Menú', 'Mis Pedidos', 'Carrito', 'Puntos', 'Reservas', 'Perfil'];
  static const _colores = [
    _kNaranja,
    _kNaranja,
    Color(0xFF38BDF8),
    Color(0xFF4ADE80),
    Color(0xFFFFD700),
    Color(0xFF4ADE80),
    Color(0xFFA78BFA),
  ];

  @override
  Widget build(BuildContext context) {
    final user    = FirebaseAuth.instance.currentUser;
    final carrito = Provider.of<CarritoProvider>(context);

    // ThemeProvider opcional — no rompe si no está registrado
    ThemeProvider? theme;
    try { theme = Provider.of<ThemeProvider>(context); } catch (_) {}
    final isDark = theme?.isDark ?? true;

    final pages = [
      HomeScreen(
        onIrAlMenu:     () => _cambiarTab(1),
        onIrAPedidos:   () => _cambiarTab(2),
        onIrAlCarrito:  () => _cambiarTab(3),
        onIrAPuntos:    () => _cambiarTab(4),
      ),
      const MenuPage(),
      const MisPedidosPage(),
      const CarritoPage(),
      const FidelidadPage(),
      const ReservasPage(),
      const PerfilPage(),
    ];

    return Scaffold(
      backgroundColor: isDark ? _kBg : const Color(0xFFF1F5F9),
      appBar: _idx == 0 || _idx == 3
          ? null
          : AppBar(
              backgroundColor: isDark ? _kBg : Colors.white,
              elevation: 0,
              titleSpacing: 16,
              title: _idx == 0
                  ? _AppBarSaludo(user: user)
                  : Text(
                      _titles[_idx],
                      style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w900,
                          fontSize: 18),
                    ),
              actions: [
                // Toggle tema
                if (theme != null)
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: isDark ? Colors.white38 : Colors.black38,
                      size: 20),
                    onPressed: () => theme!.toggleTheme(),
                  ),
                // Badge carrito
                if (_idx != 3)
                  GestureDetector(
                    onTap: () => _cambiarTab(2),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: carrito.cantidadTotal > 0
                            ? _kNaranja.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: carrito.cantidadTotal > 0
                              ? _kNaranja.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.shopping_cart_outlined,
                            color: carrito.cantidadTotal > 0
                                ? _kNaranja
                                : Colors.white38,
                            size: 16),
                        if (carrito.cantidadTotal > 0) ...[
                          const SizedBox(width: 5),
                          Text(
                            '${carrito.cantidadTotal}',
                            style: const TextStyle(
                                color: _kNaranja,
                                fontWeight: FontWeight.w900,
                                fontSize: 13),
                          ),
                        ],
                      ]),
                    ),
                  ),
              ],
            ),
      body: user == null
          ? const Center(
              child: Text('Error',
                  style: TextStyle(color: Colors.white)))
          : FadeTransition(
              opacity: _animCtrl,
              child: pages[_idx],
            ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _idx,
        carritoCant: carrito.cantidadTotal,
        colors: _colores,
        isDark: isDark,
        onTap: _cambiarTab,
      ),
    );
  }
}

// ── Saludo en AppBar ──────────────────────────────────────────────────────────
class _AppBarSaludo extends StatelessWidget {
  final User? user;
  const _AppBarSaludo({this.user});

  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _nombre {
    if (user?.displayName?.isNotEmpty == true) {
      return user!.displayName!.split(' ').first;
    }
    return 'amigo';
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kNaranja2, _kNaranja]),
            shape: BoxShape.circle),
        child: Center(
            child: Text(
          _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15),
        )),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Text('$_saludo, $_nombre 👋',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
          const Text('¿Qué te apetece hoy?',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
        ]),
      ),
    ]);
  }
}

// ── Bottom Nav animado ────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final int carritoCant;
  final List<Color> colors;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.selectedIndex,
    required this.carritoCant,
    required this.colors,
    required this.isDark,
    required this.onTap,
  });

  static const _labels = ['Inicio', 'Menú', 'Pedidos', 'Carrito', 'Puntos', 'Reservas', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.restaurant_menu_outlined,
    Icons.receipt_long_outlined,
    Icons.shopping_cart_outlined,
    Icons.stars_outlined,
    Icons.table_restaurant_outlined,
    Icons.person_outline,
  ];
  static const _iconsActive = [
    Icons.home_rounded,
    Icons.restaurant_menu,
    Icons.receipt_long,
    Icons.shopping_cart,
    Icons.stars,
    Icons.table_restaurant,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kBg : Colors.white,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final sel       = selectedIndex == i;
              final color     = colors[i];
              final isCarrito = i == 3;

              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: EdgeInsets.symmetric(
                      horizontal: sel ? 14 : 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(
                        sel ? _iconsActive[i] : _icons[i],
                        color: sel ? color : Colors.white38,
                        size: 22,
                      ),
                      if (isCarrito && carritoCant > 0)
                        Positioned(
                          top: -5, right: -5,
                          child: Container(
                            width: 15, height: 15,
                            decoration: const BoxDecoration(
                                color: _kNaranja,
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text(
                              '$carritoCant',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            )),
                          ),
                        ),
                    ]),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      Text(_labels[i],
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
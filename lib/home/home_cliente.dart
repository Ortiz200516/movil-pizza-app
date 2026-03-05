import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../cliente/menu_page.dart';
import '../cliente/mis_pedidos_page.dart';
import '../cliente/perfil_page.dart';
import '../cliente/notificaciones_page.dart';
import '../carrito/carrito_page.dart';
import '../carrito/carrito_provider.dart';

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});
  @override
  State<HomeCliente> createState() => _HomeClienteState();
}

class _HomeClienteState extends State<HomeCliente> {
  int _selectedIndex = 0;

  static const _titles = ['MENU', 'MIS PEDIDOS', 'CARRITO', 'PERFIL'];
  static const _emojis = ['🍽️', '📋', '🛒', '👤'];

  @override
  Widget build(BuildContext context) {
    final user    = FirebaseAuth.instance.currentUser;
    final carrito = Provider.of<CarritoProvider>(context);

    final pages = [
      const MenuPage(),
      const MisPedidosPage(),
      const CarritoPage(),
      const PerfilPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 20,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF6B00).withOpacity(0.4)),
            ),
            child: const Row(children: [
              Text('🍕', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('LA PIZZERIA',
                  style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2)),
            ]),
          ),
          const SizedBox(width: 12),
          Text(_emojis[_selectedIndex],
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(_titles[_selectedIndex],
              style: const TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5)),
        ]),
        actions: [
          // Botón notificaciones con badge
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notificaciones')
                  .where('uid', isEqualTo: user.uid)
                  .where('leida', isEqualTo: false)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                final noLeidas = snap.data?.docs.length ?? 0;
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificacionesPage())),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: noLeidas > 0
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: noLeidas > 0
                            ? Colors.orange.withOpacity(0.5)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Stack(children: [
                      Icon(
                          noLeidas > 0
                              ? Icons.notifications
                              : Icons.notifications_outlined,
                          color: noLeidas > 0
                              ? Colors.orange
                              : Colors.white54,
                          size: 20),
                      if (noLeidas > 0)
                        Positioned(
                          right: 0, top: 0,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF0F172A),
                                    width: 1.5)),
                            child: Center(
                                child: Text(
                                    noLeidas > 9 ? '9+' : '$noLeidas',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w900))),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),

          // Badge carrito
          if (_selectedIndex != 2)
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: carrito.cantidadTotal > 0
                      ? const Color(0xFFFF6B35).withOpacity(0.15)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: carrito.cantidadTotal > 0
                        ? const Color(0xFFFF6B35).withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white54, size: 16),
                  if (carrito.cantidadTotal > 0) ...[
                    const SizedBox(width: 6),
                    Text('${carrito.cantidadTotal}',
                        style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ],
                ]),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('Error', style: TextStyle(color: Colors.white)))
          : pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icono: Icons.restaurant_menu_outlined,
                  iconoActivo: Icons.restaurant_menu,
                  label: 'Menú',
                  selected: _selectedIndex == 0,
                  color: const Color(0xFFFF6B35),
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavItem(
                  icono: Icons.receipt_long_outlined,
                  iconoActivo: Icons.receipt_long,
                  label: 'Pedidos',
                  selected: _selectedIndex == 1,
                  color: const Color(0xFF38BDF8),
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _NavItemCarrito(
                  selected: _selectedIndex == 2,
                  count: carrito.cantidadTotal,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _NavItem(
                  icono: Icons.person_outline,
                  iconoActivo: Icons.person,
                  label: 'Perfil',
                  selected: _selectedIndex == 3,
                  color: const Color(0xFFA78BFA),
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icono, iconoActivo;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? color.withOpacity(0.3)
                    : Colors.transparent),
          ),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(selected ? iconoActivo : icono,
                color: selected ? color : Colors.white24, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white24,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ]),
        ),
      );
}

class _NavItemCarrito extends StatelessWidget {
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _NavItemCarrito(
      {required this.selected,
      required this.count,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4ADE80);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? color.withOpacity(0.3)
                  : Colors.transparent),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Icon(
                selected
                    ? Icons.shopping_cart
                    : Icons.shopping_cart_outlined,
                color: selected ? color : Colors.white24,
                size: 22),
            if (count > 0)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 1.5)),
                  child: Center(
                      child: Text('$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900))),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text('Carrito',
              style: TextStyle(
                  color: selected ? color : Colors.white24,
                  fontSize: 11,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w400)),
        ]),
      ),
    );
  }
}
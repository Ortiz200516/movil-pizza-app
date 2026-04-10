import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../carrito/carrito_provider.dart';

// ── Carrito flotante que persiste en toda la app ──────────────────────────────
// Se envuelve en el Scaffold de HomeCliente sobre el body
class CarritoFlotante extends StatefulWidget {
  final Widget child;
  final VoidCallback onIrAlCarrito;
  final int tabActual;
  const CarritoFlotante({
    super.key,
    required this.child,
    required this.onIrAlCarrito,
    required this.tabActual,
  });
  @override
  State<CarritoFlotante> createState() => _CarritoFlotanteState();
}

class _CarritoFlotanteState extends State<CarritoFlotante>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _bounceAnim;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onCantidadCambia(int nuevaCant) {
    if (nuevaCant > _prevCount && nuevaCant > 0) {
      // Producto agregado — bounce
      _ctrl.forward(from: 0);
      HapticFeedback.lightImpact();
    } else if (nuevaCant == 0 && _prevCount > 0) {
      // Carrito vaciado
      _ctrl.reverse();
    }
    _prevCount = nuevaCant;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarritoProvider>(
      builder: (_, carrito, child) {
        final cant = carrito.cantidadTotal;
        // Detectar cambio
        if (cant != _prevCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onCantidadCambia(cant);
          });
        }

        // No mostrar si está en tab carrito (3) o si está vacío
        final mostrar = cant > 0 && widget.tabActual != 3;

        return Stack(children: [
          widget.child!,

          // Botón flotante
          if (mostrar)
            Positioned(
              bottom: 16, left: 20, right: 20,
              child: AnimatedBuilder(
                animation: _scaleAnim,
                builder: (_, __) => Transform.scale(
                  scale: _scaleAnim.value.clamp(0.0, 1.0),
                  child: _BotonCarritoFlotante(
                    cantidad: cant,
                    total: carrito.total,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onIrAlCarrito();
                    },
                    bounceValue: _bounceAnim.value,
                  ),
                ),
              ),
            ),
        ]);
      },
      child: widget.child,
    );
  }
}

class _BotonCarritoFlotante extends StatelessWidget {
  final int cantidad;
  final double total;
  final VoidCallback onTap;
  final double bounceValue;
  const _BotonCarritoFlotante({
    required this.cantidad, required this.total,
    required this.onTap, required this.bounceValue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.45),
              blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          // Badge cantidad
          Transform.scale(
            scale: bounceValue.clamp(1.0, 1.3),
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$cantidad',
                  style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w900, fontSize: 14))),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Ver mi carrito',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('\$${total.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ]),
      ),
    );
  }
}
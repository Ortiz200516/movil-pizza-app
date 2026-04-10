import 'package:flutter/material.dart';

/// Shimmer genérico reutilizable en toda la app
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.65).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _anim,
        builder: (_, __) => ShimmerBox(opacity: _anim.value, child: widget.child));
}

/// Caja de shimmer — recibe opacity del padre
class ShimmerBox extends StatelessWidget {
  final Widget child;
  final double opacity;
  const ShimmerBox({super.key, required this.child, this.opacity = 0.5});

  @override
  Widget build(BuildContext context) => Opacity(opacity: opacity, child: child);
}

/// Rectángulo skeleton con bordes redondeados
class SkeletonRect extends StatelessWidget {
  final double width, height;
  final double radius;
  const SkeletonRect({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ── Skeleton: tarjeta de menú (grid) ─────────────────────────────────────────
class SkeletonMenuCard extends StatefulWidget {
  const SkeletonMenuCard({super.key});
  @override State<SkeletonMenuCard> createState() => _SkeletonMenuCardState();
}

class _SkeletonMenuCardState extends State<SkeletonMenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        // Área imagen
        Expanded(flex: 6, child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _anim.value * 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        )),
        // Info
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Container(height: 12, width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _anim.value * 0.1),
                    borderRadius: BorderRadius.circular(6))),
            Container(height: 10, width: 70,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _anim.value * 0.06),
                    borderRadius: BorderRadius.circular(6))),
            Row(children: [
              Container(height: 10, width: 50,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.09),
                      borderRadius: BorderRadius.circular(6))),
              const Spacer(),
              Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.06),
                      shape: BoxShape.circle)),
            ]),
          ]),
        )),
      ]),
    ),
  );
}

// ── Skeleton: grid completo del menú ─────────────────────────────────────────
class SkeletonMenuGrid extends StatelessWidget {
  final int cantidad;
  const SkeletonMenuGrid({super.key, this.cantidad = 6});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    childAspectRatio: 0.72,
    padding: const EdgeInsets.all(14),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: List.generate(cantidad, (_) => const SkeletonMenuCard()),
  );
}

// ── Skeleton: fila de pedido ──────────────────────────────────────────────────
class SkeletonPedidoRow extends StatefulWidget {
  const SkeletonPedidoRow({super.key});
  @override State<SkeletonPedidoRow> createState() => _SkeletonPedidoRowState();
}

class _SkeletonPedidoRowState extends State<SkeletonPedidoRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _anim.value * 0.08),
                borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 13, width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _anim.value * 0.1),
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 8),
          Container(height: 10, width: 120,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _anim.value * 0.06),
                  borderRadius: BorderRadius.circular(6))),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(height: 14, width: 55,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _anim.value * 0.09),
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 6),
          Container(height: 18, width: 70,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _anim.value * 0.06),
                  borderRadius: BorderRadius.circular(8))),
        ]),
      ]),
    ),
  );
}

// ── Skeleton: lista de pedidos ────────────────────────────────────────────────
class SkeletonPedidosList extends StatelessWidget {
  final int cantidad;
  const SkeletonPedidosList({super.key, this.cantidad = 4});

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(cantidad,
        (i) => SkeletonPedidoRow(key: ValueKey(i))));
}

// ── Skeleton: chip de categoría ───────────────────────────────────────────────
class SkeletonCatChip extends StatefulWidget {
  final double width;
  const SkeletonCatChip({super.key, this.width = 80});
  @override State<SkeletonCatChip> createState() => _SkeletonCatChipState();
}

class _SkeletonCatChipState extends State<SkeletonCatChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.6).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width, height: 34,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _anim.value * 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
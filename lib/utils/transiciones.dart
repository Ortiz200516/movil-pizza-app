import 'package:flutter/material.dart';

/// Colección de transiciones animadas para NavigationRoutes
/// Uso: Navigator.push(context, Transicion.fadeSlide(MiPantalla()))
class Transicion {

  // ── Fade simple ────────────────────────────────────────────────────────────
  static PageRouteBuilder fade(Widget pagina,
      {Duration duracion = const Duration(milliseconds: 280)}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => pagina,
      transitionDuration: duracion,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  // ── Slide desde abajo (para modals, detalles) ─────────────────────────────
  static PageRouteBuilder slideAbajo(Widget pagina,
      {Duration duracion = const Duration(milliseconds: 320)}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => pagina,
      transitionDuration: duracion,
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, anim, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );
  }

  // ── Slide desde la derecha (navegación estándar) ──────────────────────────
  static PageRouteBuilder slideDerecha(Widget pagina,
      {Duration duracion = const Duration(milliseconds: 300)}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => pagina,
      transitionDuration: duracion,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, anim, secAnim, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: anim,
                curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );
  }

  // ── Fade + Scale (para splash → login, detalles de producto) ─────────────
  static PageRouteBuilder fadeScale(Widget pagina,
      {Duration duracion = const Duration(milliseconds: 350)}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => pagina,
      transitionDuration: duracion,
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, anim, __, child) {
        final fade  = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  // ── Shared axis horizontal (para tabs/onboarding) ─────────────────────────
  static PageRouteBuilder axisHorizontal(Widget pagina,
      {bool reverse = false,
       Duration duracion = const Duration(milliseconds: 300)}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => pagina,
      transitionDuration: duracion,
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, anim, secAnim, child) {
        final begin = Offset(reverse ? -0.08 : 0.08, 0);
        final slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        final fade  = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: anim,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );
  }
}

/// Widget que anima la entrada de sus hijos en secuencia (stagger)
/// Útil para listas, cards, pantallas de onboarding
class AnimacionEntrada extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duracion;
  final Offset offsetInicial;

  const AnimacionEntrada({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duracion = const Duration(milliseconds: 400),
    this.offsetInicial = const Offset(0, 0.06),
  });

  @override
  State<AnimacionEntrada> createState() => _AnimacionEntradaState();
}

class _AnimacionEntradaState extends State<AnimacionEntrada>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duracion);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
            begin: widget.offsetInicial, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

/// Stagger automático para una lista de widgets
class AnimacionStagger extends StatelessWidget {
  final List<Widget> children;
  final Duration delayBase;
  final Duration duracion;

  const AnimacionStagger({
    super.key,
    required this.children,
    this.delayBase = const Duration(milliseconds: 60),
    this.duracion  = const Duration(milliseconds: 350),
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: children.asMap().entries.map((e) =>
      AnimacionEntrada(
        delay:   delayBase * e.key,
        duracion: duracion,
        child:   e.value,
      ),
    ).toList());
  }
}

/// Extensión en BuildContext para navegar con transiciones fácilmente
extension NavTransicion on BuildContext {
  Future<T?> pushFade<T>(Widget pagina) =>
      Navigator.of(this).push<T>(Transicion.fade(pagina) as Route<T>);

  Future<T?> pushSlide<T>(Widget pagina) =>
      Navigator.of(this).push<T>(Transicion.slideDerecha(pagina) as Route<T>);

  Future<T?> pushModal<T>(Widget pagina) =>
      Navigator.of(this).push<T>(Transicion.slideAbajo(pagina) as Route<T>);

  Future<T?> pushFadeScale<T>(Widget pagina) =>
      Navigator.of(this).push<T>(Transicion.fadeScale(pagina) as Route<T>);

  void replaceFade(Widget pagina) =>
      Navigator.of(this).pushReplacement(Transicion.fade(pagina));

  void replaceFadeScale(Widget pagina) =>
      Navigator.of(this).pushReplacement(Transicion.fadeScale(pagina));
}
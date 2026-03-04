import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ctrl = PageController();
  int _pagina = 0;

  static const _paginas = [
    _PaginaData(
      emoji: '🍕',
      titulo: 'Tu pizzería\nen tu bolsillo',
      descripcion:
          'Explora nuestro menú completo, personaliza tu pedido y paga sin filas ni esperas.',
      color: Color(0xFFFF6B00),
      fondo: Color(0xFF1A0800),
    ),
    _PaginaData(
      emoji: '🛵',
      titulo: 'Seguimiento\nen tiempo real',
      descripcion:
          'Sigue tu pedido desde la cocina hasta tu puerta. Siempre sabes dónde está.',
      color: Color(0xFF38BDF8),
      fondo: Color(0xFF001A24),
    ),
    _PaginaData(
      emoji: '⭐',
      titulo: 'Ofertas y\nrecompensas',
      descripcion:
          'Cupones de descuento, ofertas del día y califica tu experiencia para mejorar.',
      color: Color(0xFF4ADE80),
      fondo: Color(0xFF00180A),
    ),
  ];

  void _irASiguiente() {
    if (_pagina < _paginas.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _terminar();
    }
  }

  Future<void> _terminar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_visto', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginPage(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _paginas[_pagina];
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [

        // Fondo animado con color según página
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                pagina.fondo,
                const Color(0xFF0F172A),
              ],
            ),
          ),
        ),

        // Círculos decorativos
        Positioned(top: -40, right: -40,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pagina.color.withOpacity(0.07)),
          ),
        ),
        Positioned(bottom: -60, left: -60,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pagina.color.withOpacity(0.05)),
          ),
        ),

        SafeArea(
          child: Column(children: [

            // Botón saltar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_pagina < _paginas.length - 1)
                    TextButton(
                      onPressed: _terminar,
                      child: Text('Saltar',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 14)),
                    ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _paginas.length,
                itemBuilder: (_, i) =>
                    _PantallaOnboarding(data: _paginas[i]),
              ),
            ),

            // Indicadores + botón
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
              child: Column(children: [

                // Dots
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_paginas.length, (i) {
                  final activo = i == _pagina;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: activo ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activo
                          ? pagina.color
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                })),
                const SizedBox(height: 28),

                // Botón siguiente / empezar
                GestureDetector(
                  onTap: _irASiguiente,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 56,
                    decoration: BoxDecoration(
                      color: pagina.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: pagina.color.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6))],
                    ),
                    child: Center(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(
                          _pagina == _paginas.length - 1
                              ? '¡Comenzar!'
                              : 'Siguiente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 18),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Pantalla individual ──────────────────────────────────────
class _PantallaOnboarding extends StatefulWidget {
  final _PaginaData data;
  const _PantallaOnboarding({required this.data});
  @override
  State<_PantallaOnboarding> createState() =>
      _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<_PantallaOnboarding>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [

        // Emoji animado
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.data.color.withOpacity(0.1),
              border: Border.all(
                  color: widget.data.color.withOpacity(0.3),
                  width: 2),
              boxShadow: [BoxShadow(
                  color: widget.data.color.withOpacity(0.2),
                  blurRadius: 40, spreadRadius: 5)],
            ),
            child: Center(
              child: Text(widget.data.emoji,
                  style: const TextStyle(fontSize: 70)),
            ),
          ),
        ),
        const SizedBox(height: 48),

        // Título
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Text(
              widget.data.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Descripción
        FadeTransition(
          opacity: _fadeAnim,
          child: Text(
            widget.data.descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Modelo de página ─────────────────────────────────────────
class _PaginaData {
  final String emoji, titulo, descripcion;
  final Color color, fondo;
  const _PaginaData({
    required this.emoji,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.fondo,
  });
}
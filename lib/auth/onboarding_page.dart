import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {

  final PageController _pageCtrl = PageController();
  int _paginaActual = 0;

  late AnimationController _iconCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<Offset> _slideAnim;

  static const _paginas = [
    _PaginaData(
      emoji: '🍕',
      emojisBg: ['🧀', '🌿', '🧄', '🍅'],
      titulo: 'La mejor pizza\nde Guayaquil',
      subtitulo: 'Ingredientes frescos',
      descripcion: 'Masa artesanal preparada cada día, mozzarella importada y horneada en horno a leña. Una experiencia gastronómica única.',
      color: Color(0xFFFF6B35),
      colorSec: Color(0xFFFF9A3C),
      caracteristicas: ['🔥 Horno a leña', '🌿 Ingredientes frescos', '👨‍🍳 Recetas artesanales'],
    ),
    _PaginaData(
      emoji: '⚡',
      emojisBg: ['📱', '✅', '🔔', '⭐'],
      titulo: 'Pedidos en\nsegundos',
      subtitulo: 'Simple y rápido',
      descripcion: 'Elige, personaliza y confirma tu pizza favorita en pocos toques. Confirmación instantánea y seguimiento en vivo.',
      color: Color(0xFF38BDF8),
      colorSec: Color(0xFF0EA5E9),
      caracteristicas: ['📲 Menú digital completo', '⚡ Confirmación al instante', '🎟️ Cupones y descuentos'],
    ),
    _PaginaData(
      emoji: '🛵',
      emojisBg: ['📍', '🗺️', '🏠', '⏱️'],
      titulo: 'Rastrea tu\npedido en vivo',
      subtitulo: 'GPS en tiempo real',
      descripcion: 'Sigue a tu repartidor en el mapa, recibe notificaciones de cada etapa y sabe exactamente cuándo llegará tu pizza.',
      color: Color(0xFF4ADE80),
      colorSec: Color(0xFF22C55E),
      caracteristicas: ['🗺️ Mapa en tiempo real', '🔔 Notificaciones push', '✅ Código de verificación'],
    ),
    _PaginaData(
      emoji: '🏆',
      emojisBg: ['🎁', '💰', '❤️', '🌟'],
      titulo: 'Gana puntos\ncada pedido',
      subtitulo: 'Programa de fidelidad',
      descripcion: 'Acumula puntos con cada compra, sube de nivel y canjéalos por descuentos. Bronce, Plata, Oro y Platino te esperan.',
      color: Color(0xFFFFD700),
      colorSec: Color(0xFFF59E0B),
      caracteristicas: ['⭐ Puntos por compra', '🎁 Descuentos exclusivos', '💎 4 niveles de membresía'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _iconCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _iconCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    HapticFeedback.lightImpact();
    if (_paginaActual < _paginas.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic);
    } else {
      _terminar();
    }
  }

  Future<void> _terminar() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_visto', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, PageRouteBuilder(
          pageBuilder: (_, a, __) => const LoginPage(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
  }

  void _onPageChanged(int i) {
    setState(() => _paginaActual = i);
    _iconCtrl.forward(from: 0);
    _slideCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _paginas[_paginaActual];
    final size   = MediaQuery.of(context).size;
    final isLast = _paginaActual == _paginas.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [

        // Fondo radial animado
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.6),
              radius: 1.3,
              colors: [
                pagina.color.withValues(alpha: 0.10),
                const Color(0xFF0F172A),
              ],
            ),
          ),
        ),

        // Círculo decorativo grande
        Positioned(
          top: -60, right: -60,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pagina.color.withValues(alpha: 0.05),
              border: Border.all(
                  color: pagina.color.withValues(alpha: 0.1), width: 1),
            ),
          ),
        ),
        Positioned(
          bottom: 80, left: -40,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pagina.colorSec.withValues(alpha: 0.04),
            ),
          ),
        ),

        // Emojis flotantes
        ...List.generate(pagina.emojisBg.length, (i) {
          final positions = [
            [0.07, 0.15], [0.80, 0.12], [0.78, 0.68], [0.06, 0.65],
          ];
          final pos = positions[i % positions.length];
          return Positioned(
            left: size.width * pos[0],
            top: size.height * pos[1],
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: 0.25,
              child: Text(pagina.emojisBg[i],
                  style: const TextStyle(fontSize: 26)),
            ),
          );
        }),

        // ── Contenido ─────────────────────────────────────────────────
        SafeArea(child: Column(children: [

          // Barra superior: indicadores + saltar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
            child: Row(children: [
              // Dots indicadores
              Row(children: List.generate(_paginas.length, (i) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 6),
                  width: _paginaActual == i ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _paginaActual == i
                        ? pagina.color
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
              const Spacer(),
              if (!isLast)
                GestureDetector(
                  onTap: _terminar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Saltar',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13)),
                  ),
                ),
            ]),
          ),

          // PageView
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: _onPageChanged,
              itemCount: _paginas.length,
              itemBuilder: (_, i) {
                final p = _paginas[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                    // Icono principal animado
                    AnimatedBuilder(
                      animation: _iconCtrl,
                      builder: (_, child) => Transform.scale(
                        scale: _iconScale.value,
                        child: Opacity(
                            opacity: _iconOpacity.value, child: child),
                      ),
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.color.withValues(alpha: 0.1),
                          border: Border.all(
                              color: p.color.withValues(alpha: 0.3),
                              width: 2),
                          boxShadow: [BoxShadow(
                              color: p.color.withValues(alpha: 0.15),
                              blurRadius: 30, spreadRadius: 5)],
                        ),
                        child: Center(child: Text(p.emoji,
                            style: const TextStyle(fontSize: 60))),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Subtítulo
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _iconOpacity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: p.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(p.subtitulo, style: TextStyle(
                              color: p.color, fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _iconOpacity,
                        child: Text(p.titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28, fontWeight: FontWeight.w900,
                                height: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Descripción
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _iconOpacity,
                        child: Text(p.descripcion,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14, height: 1.6)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Características
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _iconOpacity,
                        child: Column(children: p.caracteristicas.map((c) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Text(c.split(' ')[0],
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(c.substring(c.indexOf(' ')+1),
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 13)),
                            ]),
                          ),
                        ).toList()),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),

          // ── Botón siguiente / comenzar ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
            child: GestureDetector(
              onTap: _siguiente,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: pagina.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: pagina.color.withValues(alpha: 0.35),
                      blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(
                    isLast ? '¡Comenzar ahora!' : 'Siguiente',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

class _PaginaData {
  final String emoji, titulo, subtitulo, descripcion;
  final List<String> emojisBg, caracteristicas;
  final Color color, colorSec;
  const _PaginaData({
    required this.emoji, required this.emojisBg,
    required this.titulo, required this.subtitulo,
    required this.descripcion, required this.color,
    required this.colorSec, required this.caracteristicas,
  });
}
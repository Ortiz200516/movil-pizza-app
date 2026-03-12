import 'package:flutter/material.dart';
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

  late AnimationController _ilustCtrl;
  late Animation<double> _ilustScale;
  late Animation<double> _ilustOpacity;

  static const _paginas = [
    _PaginaData(
      emoji: '🍕',
      titulo: 'Pizzas artesanales',
      descripcion:
          'Masa fresca todos los días, ingredientes importados de Italia y horneadas en horno de leña. Una experiencia única.',
      color: Color(0xFFFF6B35),
      emojisFlotantes: ['🧄', '🫙', '🌿', '🧀'],
    ),
    _PaginaData(
      emoji: '⚡',
      titulo: 'Pedidos en segundos',
      descripcion:
          'Elige tu pizza favorita, personalízala a tu gusto y recibe una confirmación instantánea. ¡Así de fácil!',
      color: Color(0xFF38BDF8),
      emojisFlotantes: ['📱', '✅', '🔔', '⭐'],
    ),
    _PaginaData(
      emoji: '🛵',
      titulo: 'Seguimiento en vivo',
      descripcion:
          'Rastrea tu pedido en tiempo real. Sabe exactamente cuándo llegará tu pizza a tu puerta.',
      color: Color(0xFF4ADE80),
      emojisFlotantes: ['📍', '🗺️', '🏠', '⏱️'],
    ),
    _PaginaData(
      emoji: '🎉',
      titulo: '¡Únete a nosotros!',
      descripcion:
          'Ofertas exclusivas, puntos de recompensa y notificaciones de promociones especiales. ¡La mejor pizzería, en tu bolsillo!',
      color: Color(0xFFA78BFA),
      emojisFlotantes: ['🎁', '💰', '❤️', '🌟'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ilustCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ilustScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ilustCtrl, curve: Curves.elasticOut));
    _ilustOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ilustCtrl, curve: Curves.easeOut));
    _ilustCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ilustCtrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_paginaActual < _paginas.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    } else {
      _terminar();
    }
  }

  Future<void> _terminar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_visto', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _onPageChanged(int i) {
    setState(() => _paginaActual = i);
    _ilustCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _paginas[_paginaActual];
    final color  = pagina.color;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [

        // Fondo degradado según página
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.2,
              colors: [
                color.withValues(alpha: 0.12),
                const Color(0xFF0F172A),
              ],
            ),
          ),
        ),

        // Emojis flotantes decorativos
        ...List.generate(pagina.emojisFlotantes.length, (i) {
          final positions = [
            [0.08, 0.12], [0.82, 0.10], [0.75, 0.65], [0.05, 0.70],
          ];
          final pos = positions[i % positions.length];
          return Positioned(
            left: size.width * pos[0],
            top: size.height * pos[1],
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: 0.35,
              child: Text(pagina.emojisFlotantes[i],
                  style: const TextStyle(fontSize: 28)),
            ),
          );
        }),

        // Contenido principal
        SafeArea(
          child: Column(children: [

            // Botón saltar
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: _paginaActual < _paginas.length - 1
                    ? TextButton(
                        onPressed: _terminar,
                        child: Text('Saltar',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13)),
                      )
                    : const SizedBox(height: 36),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: _onPageChanged,
                itemCount: _paginas.length,
                itemBuilder: (_, i) => _PaginaWidget(
                  data: _paginas[i],
                  ilustCtrl: _ilustCtrl,
                  ilustScale: _ilustScale,
                  ilustOpacity: _ilustOpacity,
                ),
              ),
            ),

            // Indicadores + botón
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Column(children: [

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_paginas.length, (i) {
                    final sel = i == _paginaActual;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: sel ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: sel
                            ? color
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // Botón siguiente / empezar
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _siguiente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      shadowColor: color.withValues(alpha: 0.4),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text(
                        _paginaActual == _paginas.length - 1
                            ? '¡Comenzar ahora!'
                            : 'Siguiente',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _paginaActual == _paginas.length - 1
                            ? Icons.rocket_launch_outlined
                            : Icons.arrow_forward_rounded,
                        size: 18),
                    ]),
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

// ── Datos de cada página ──────────────────────────────────────────────────────
class _PaginaData {
  final String emoji;
  final String titulo;
  final String descripcion;
  final Color color;
  final List<String> emojisFlotantes;

  const _PaginaData({
    required this.emoji,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.emojisFlotantes,
  });
}

// ── Widget de cada página ─────────────────────────────────────────────────────
class _PaginaWidget extends StatelessWidget {
  final _PaginaData data;
  final AnimationController ilustCtrl;
  final Animation<double> ilustScale;
  final Animation<double> ilustOpacity;

  const _PaginaWidget({
    required this.data,
    required this.ilustCtrl,
    required this.ilustScale,
    required this.ilustOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Ilustración principal
          AnimatedBuilder(
            animation: ilustCtrl,
            builder: (_, child) => Transform.scale(
              scale: ilustScale.value,
              child: Opacity(opacity: ilustOpacity.value, child: child),
            ),
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.color.withValues(alpha: 0.1),
                border: Border.all(
                    color: data.color.withValues(alpha: 0.2), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: data.color.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Center(
                child: Text(data.emoji,
                    style: const TextStyle(fontSize: 80)),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Título
          Text(
            data.titulo,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Descripción
          Text(
            data.descripcion,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 15,
                height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
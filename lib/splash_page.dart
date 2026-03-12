import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_page.dart';
import 'auth/onboarding_page.dart';
import 'home/home_admin.dart';
import 'home/home_cliente.dart';
import 'home/home_cocinero.dart';
import 'home/home_mesero.dart';
import 'home/home_repartidor.dart';
import 'services/auth_services.dart';
import 'services/notificacion_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {

  // Controladores de animación
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _barraCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset>  _textSlide;
  late Animation<double> _barraWidth;
  late Animation<double> _particleOpacity;

  @override
  void initState() {
    super.initState();

    // Logo: escala + opacidad
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    // Texto: slide + fade
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Barra de progreso
    _barraCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _barraWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _barraCtrl, curve: Curves.easeInOut));

    // Partículas flotantes
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _particleOpacity = Tween<double>(begin: 0.3, end: 0.8).animate(
        CurvedAnimation(parent: _particleCtrl, curve: Curves.easeInOut));

    _iniciarSecuencia();
  }

  Future<void> _iniciarSecuencia() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _barraCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 2200));
    await _navegar();
  }

  Future<void> _navegar() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final visto = prefs.getBool('onboarding_visto') ?? false;
      _ir(visto ? const LoginPage() : const OnboardingPage());
      return;
    }

    try {
      final rol = await AuthService().obtenerRol(user.uid);
      await NotificacionService().guardarToken(user.uid);

      Widget dest;
      switch (rol.toLowerCase()) {
        case 'admin':      dest = const HomeAdmin();      break;
        case 'cocinero':   dest = const HomeCocinero();   break;
        case 'repartidor': dest = const HomeRepartidor(); break;
        case 'mesero':     dest = const HomeMesero();     break;
        default:           dest = const HomeCliente();
      }
      _ir(dest);
    } catch (_) {
      _ir(const LoginPage());
    }
  }

  void _ir(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _barraCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [

        // ── Fondo con círculos decorativos ───────────────────────────────────
        Positioned(top: -80, right: -60,
          child: _Circulo(size: 260,
              color: const Color(0xFFFF6B00).withValues(alpha: 0.07))),
        Positioned(bottom: -100, left: -80,
          child: _Circulo(size: 320,
              color: const Color(0xFFFF6B00).withValues(alpha: 0.05))),
        Positioned(top: size.height * 0.3, left: -40,
          child: _Circulo(size: 120,
              color: const Color(0xFFFF6B35).withValues(alpha: 0.04))),

        // ── Partículas flotantes ─────────────────────────────────────────────
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => Stack(children: [
            _Particula(x: size.width * 0.1, y: size.height * 0.2,
                opacity: _particleOpacity.value * 0.5, emoji: '🍕', size: 18),
            _Particula(x: size.width * 0.85, y: size.height * 0.15,
                opacity: _particleOpacity.value * 0.4, emoji: '🧀', size: 16),
            _Particula(x: size.width * 0.75, y: size.height * 0.7,
                opacity: _particleOpacity.value * 0.5, emoji: '🫙', size: 14),
            _Particula(x: size.width * 0.15, y: size.height * 0.75,
                opacity: _particleOpacity.value * 0.3, emoji: '🌿', size: 16),
          ]),
        ),

        // ── Contenido central ────────────────────────────────────────────────
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo animado
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (_, child) => Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(opacity: _logoOpacity.value, child: child),
                ),
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.45),
                        blurRadius: 40, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Center(
                    child: Text('🍕', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Nombre y tagline
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(children: [
                    const Text('La Italiana',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('Auténtica pizza italiana',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                            letterSpacing: 1)),
                  ]),
                ),
              ),

              const SizedBox(height: 60),

              // Barra de progreso
              FadeTransition(
                opacity: _textOpacity,
                child: SizedBox(
                  width: 160,
                  child: Column(children: [
                    AnimatedBuilder(
                      animation: _barraCtrl,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _barraWidth.value,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFFF6B35)),
                          minHeight: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Cargando...',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // ── Versión en el footer ─────────────────────────────────────────────
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: FadeTransition(
            opacity: _textOpacity,
            child: Text('v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.15),
                    fontSize: 11)),
          ),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Circulo extends StatelessWidget {
  final double size;
  final Color color;
  const _Circulo({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Particula extends StatelessWidget {
  final double x, y, opacity, size;
  final String emoji;
  const _Particula({
    required this.x, required this.y,
    required this.opacity, required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) => Positioned(
    left: x, top: y,
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(emoji, style: TextStyle(fontSize: size)),
    ),
  );
}
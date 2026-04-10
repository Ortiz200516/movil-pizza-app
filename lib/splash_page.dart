import 'dart:math';
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

  // ── Controladores ─────────────────────────────────────────────────────────
  late AnimationController _ringCtrl;      // anillo exterior pulsante
  late AnimationController _logoCtrl;      // logo entrada
  late AnimationController _textCtrl;      // texto entrada
  late AnimationController _barraCtrl;     // barra progreso
  late AnimationController _rotCtrl;       // slice pizza girando
  late AnimationController _particleCtrl; // partículas flotantes

  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset>  _textSlide;
  late Animation<double> _barraWidth;
  late Animation<double> _rotAngle;
  late Animation<double> _particleOpacity;

  @override
  void initState() {
    super.initState();

    // Anillo exterior — aparece primero, pulsa
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _ringScale = Tween<double>(begin: 0.6, end: 1.15).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ringCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    // Logo pizza — entrada elástica
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    // Texto — slide desde abajo
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Barra de carga
    _barraCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _barraWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _barraCtrl, curve: Curves.easeInOut));

    // Rotación sutil del logo
    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _rotAngle = Tween<double>(begin: -0.05, end: 0.05).animate(
        CurvedAnimation(parent: _rotCtrl, curve: Curves.easeInOut))
      ..addListener(() {
        if (_rotCtrl.value > 0.5) _rotCtrl.reverse();
      });

    // Partículas decorativas
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _particleOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(
        CurvedAnimation(parent: _particleCtrl, curve: Curves.easeInOut));

    _iniciarSecuencia();
  }

  Future<void> _iniciarSecuencia() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _barraCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
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
    } catch (_) { _ir(const LoginPage()); }
  }

  void _ir(Widget dest) {
    if (!mounted) return;
    Navigator.pushReplacement(context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => dest,
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _barraCtrl.dispose();
    _rotCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(children: [

        // ── Fondo degradado radial ─────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [Color(0xFF1A0F00), Color(0xFF0A0F1E)],
            ),
          ),
        ),

        // ── Partículas flotantes (emojis decorativos) ─────────────────
        AnimatedBuilder(
          animation: _particleOpacity,
          builder: (_, __) => Stack(children: [
            _Particula('🍕', 0.08, 0.18, 22, _particleOpacity.value),
            _Particula('🧀', 0.82, 0.12, 16, _particleOpacity.value * 0.7),
            _Particula('🌿', 0.75, 0.72, 14, _particleOpacity.value * 0.5),
            _Particula('🍅', 0.05, 0.68, 16, _particleOpacity.value * 0.6),
            _Particula('🧄', 0.88, 0.42, 14, _particleOpacity.value * 0.4),
            _Particula('⭐', 0.15, 0.52, 12, _particleOpacity.value * 0.5),
          ]),
        ),

        // ── Contenido central ──────────────────────────────────────────
        Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Anillo exterior animado
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, child) => Transform.scale(
                scale: _ringScale.value,
                child: Opacity(opacity: _ringOpacity.value, child: child),
              ),
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
                      width: 1.5),
                ),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                        width: 1),
                  ),
                ),
              ),
            ),

            // Logo pizza (sobre el anillo)
            AnimatedBuilder(
              animation: Listenable.merge([_logoCtrl, _rotCtrl]),
              builder: (_, child) => Transform.scale(
                scale: _logoScale.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.rotate(
                    angle: sin(_rotCtrl.value * pi * 2) * 0.04,
                    child: child,
                  ),
                ),
              ),
              child: Container(
                width: 120, height: 120,
                margin: const EdgeInsets.only(bottom: 140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
                      width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                        blurRadius: 30, spreadRadius: 5),
                  ],
                ),
                child: const Center(
                  child: Text('🍕', style: TextStyle(fontSize: 56)),
                ),
              ),
            ),
          ],
        )),

        // ── Logo y texto posicionado en centro ────────────────────────
        Positioned(
          top: size.height * 0.42,
          left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, child) => Transform.scale(
              scale: _logoScale.value,
              child: Opacity(opacity: _logoOpacity.value, child: child),
            ),
            child: const Column(children: [
              Text('🍕', style: TextStyle(fontSize: 64)),
            ]),
          ),
        ),

        // ── Texto nombre + slogan ─────────────────────────────────────
        Positioned(
          top: size.height * 0.56,
          left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _textCtrl,
            builder: (_, child) => FadeTransition(
              opacity: _textOpacity,
              child: SlideTransition(position: _textSlide, child: child),
            ),
            child: Column(children: [
              const Text('LA ITALIANA',
                  style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 32, fontWeight: FontWeight.w900,
                      letterSpacing: 6)),
              const SizedBox(height: 6),
              Text('Pizzería Artesanal',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14, letterSpacing: 2,
                      fontWeight: FontWeight.w300)),
            ]),
          ),
        ),

        // ── Barra de progreso ─────────────────────────────────────────
        Positioned(
          bottom: size.height * 0.12,
          left: size.width * 0.2,
          right: size.width * 0.2,
          child: Column(children: [
            AnimatedBuilder(
              animation: _barraWidth,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _barraWidth.value,
                  minHeight: 3,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFFFF6B35)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _barraWidth,
              builder: (_, __) => Text(
                _barraWidth.value < 0.3 ? 'Iniciando...'
                    : _barraWidth.value < 0.7 ? 'Cargando tu experiencia...'
                    : 'Bienvenido 🍕',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11, letterSpacing: 0.5),
              ),
            ),
          ]),
        ),

        // ── Versión ───────────────────────────────────────────────────
        Positioned(
          bottom: 28, left: 0, right: 0,
          child: Text('v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15),
                  fontSize: 11)),
        ),
      ]),
    );
  }
}

// ── Widget partícula ──────────────────────────────────────────────────────────
class _Particula extends StatelessWidget {
  final String emoji;
  final double x, y, size, opacity;
  const _Particula(this.emoji, this.x, this.y, this.size, this.opacity);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return Positioned(
      left: w * x, top: h * y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }
}
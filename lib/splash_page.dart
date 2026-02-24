import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_page.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;
  late Animation<double>   _barra;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));

    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut)));

    _barra = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));

    _ctrl.forward();

    // Navegar después de la animación
    Future.delayed(const Duration(milliseconds: 2600), _navegar);
  }

  Future<void> _navegar() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _ir(const LoginPage());
      return;
    }
    // Usuario ya logueado — obtener rol
    try {
      final rol = await AuthService().obtenerRol(user.uid);
      // Guardar token FCM si hay sesión activa
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
    Navigator.pushReplacement(context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        // Círculos decorativos de fondo
        Positioned(top: -60, right: -60,
          child: _Circulo(size: 220, color: const Color(0xFFFF6B00).withOpacity(0.07))),
        Positioned(bottom: -80, left: -80,
          child: _Circulo(size: 280, color: const Color(0xFFFF6B00).withOpacity(0.05))),
        Positioned(top: 140, left: -40,
          child: _Circulo(size: 140, color: Colors.white.withOpacity(0.02))),

        // Contenido central
        Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFF6B00).withOpacity(0.5), width: 3),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.25),
                              blurRadius: 40, spreadRadius: 5),
                        ],
                      ),
                      child: const Center(
                        child: Text('🍕', style: TextStyle(fontSize: 54)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Nombre
                FadeTransition(
                  opacity: _fade,
                  child: Column(children: [
                    const Text('LA PIZZERÍA',
                      style: TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Sistema de gestión',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 48),

                // Barra de progreso
                FadeTransition(
                  opacity: _fade,
                  child: SizedBox(
                    width: 180,
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _barra.value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B00)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _barra.value < 0.4 ? 'Iniciando...'
                            : _barra.value < 0.8 ? 'Conectando a Firebase...'
                            : 'Listo ✓',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Versión abajo
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: FadeTransition(
            opacity: _fade,
            child: Text('v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.12), fontSize: 11),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Circulo extends StatelessWidget {
  final double size; final Color color;
  const _Circulo({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
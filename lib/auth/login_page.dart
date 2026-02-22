import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../home/home_admin.dart';
import '../home/home_cliente.dart';
import '../home/home_cocinero.dart';
import '../home/home_mesero.dart';
import '../home/home_repartidor.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final _authService  = AuthService();
  bool _cargando      = false;
  bool _verPass       = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final rol = await _authService.login(
        _emailCtrl.text.trim(), _passCtrl.text.trim());
      Widget destino;
      switch (rol.toLowerCase()) {
        case 'admin':       destino = const HomeAdmin(); break;
        case 'cocinero':    destino = const HomeCocinero(); break;
        case 'repartidor':  destino = const HomeRepartidor(); break;
        case 'mesero':      destino = const HomeMesero(); break;
        default:            destino = const HomeCliente();
      }
      if (mounted) Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => destino));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        // Fondo decorativo
        Positioned(top: -80, right: -60,
          child: Container(width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.07)))),
        Positioned(bottom: -100, left: -80,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.05)))),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      // Logo
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4), width: 2),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.2),
                            blurRadius: 24, spreadRadius: 4)],
                        ),
                        child: const Center(child: Text('🍕', style: TextStyle(fontSize: 42))),
                      ),
                      const SizedBox(height: 20),
                      const Text('LA PIZZERÍA',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6B00), letterSpacing: 4)),
                      const SizedBox(height: 6),
                      Text('Inicia sesión para continuar',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 40),

                      // Email
                      _Campo(
                        ctrl: _emailCtrl,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        tipo: TextInputType.emailAddress,
                        validar: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      _Campo(
                        ctrl: _passCtrl,
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        ocultar: !_verPass,
                        sufijo: IconButton(
                          icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade500, size: 20),
                          onPressed: () => setState(() => _verPass = !_verPass),
                        ),
                        validar: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Botón login
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _cargando
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('INICIAR SESIÓN',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('¿No tienes cuenta?',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                      ]),
                      const SizedBox(height: 16),

                      // Botón registro
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const RegisterPage())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B00),
                            side: BorderSide(color: const Color(0xFFFF6B00).withOpacity(0.5), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('CREAR CUENTA',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Campo reutilizable ────────────────────────────────────────
class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  final bool ocultar;
  final Widget? sufijo;
  final String? Function(String?)? validar;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.tipo = TextInputType.text,
    this.ocultar = false,
    this.sufijo,
    this.validar,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: tipo,
    obscureText: ocultar,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    validator: validar,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
      errorStyle: TextStyle(color: Colors.red.shade400, fontSize: 12),
    ),
  );
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../services/notificacion_service.dart';
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

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _authService = AuthService();

  bool _cargando = false;
  bool _verPass  = false;
  bool _recordar = true;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_emailFocus);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String _traducirError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('no user')) {
      return 'No existe una cuenta con ese correo';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Contraseña incorrecta';
    }
    if (msg.contains('too-many-requests')) {
      return 'Demasiados intentos. Espera unos minutos';
    }
    if (msg.contains('user-disabled')) {
      return 'Esta cuenta ha sido deshabilitada';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Sin conexión. Verifica tu internet';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final rol = await _authService.login(
          _emailCtrl.text.trim(), _passCtrl.text.trim());

      final uid = _authService.currentUserId;
      if (uid != null) await NotificacionService().guardarToken(uid);

      Widget destino;
      switch (rol.toLowerCase()) {
        case 'admin':
          destino = const HomeAdmin();
          break;
        case 'cocinero':
          destino = const HomeCocinero();
          break;
        case 'repartidor':
          destino = const HomeRepartidor();
          break;
        case 'mesero':
          destino = const HomeMesero();
          break;
        default:
          destino = const HomeCliente();
      }
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => destino));
      }
    } catch (e) {
      if (mounted) _mostrarError(_traducirError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF991B1B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _olvideMiContrasena() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _mostrarError('Ingresa tu correo primero para recuperar la contraseña');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Recuperar contraseña',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📧', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Enviaremos un enlace de recuperación a:',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(email,
              style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enviar enlace',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Text('✅', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Expanded(child: Text('Revisa tu correo para restablecer la contraseña',
                style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(14),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) _mostrarError(_traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        // Fondo decorativo
        Positioned(top: -80, right: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withValues(alpha: 0.07)))),
        Positioned(bottom: -100, left: -80,
          child: Container(width: 320, height: 320,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withValues(alpha: 0.04)))),
        Positioned(top: 200, left: 20,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.015)))),

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
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                              blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Center(
                          child: Text('🍕', style: TextStyle(fontSize: 44)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Título
                      const Text('La Italiana',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text('Bienvenido de nuevo',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14)),
                      const SizedBox(height: 36),

                      // Campo Email
                      TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'Correo electrónico',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Campo Contraseña
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_verPass,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'Contraseña',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _verPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38, size: 20),
                            onPressed: () =>
                                setState(() => _verPass = !_verPass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Recordar + Olvidé contraseña
                      Row(children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _recordar = !_recordar),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: _recordar
                                    ? const Color(0xFFFF6B00)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _recordar
                                      ? const Color(0xFFFF6B00)
                                      : Colors.white24,
                                ),
                              ),
                              child: _recordar
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 13)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text('Recordarme',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13)),
                          ]),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _olvideMiContrasena,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero),
                          child: const Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                  color: Color(0xFFFF6B00),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 26),

                      // Botón Ingresar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFFF6B00).withValues(alpha: 0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Ingresar',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ir a registro
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿No tienes cuenta?',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 14)),
                          TextButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterPage())),
                            child: const Text('Regístrate',
                                style: TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3),
          fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFFF6B00), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
    );
  }
}
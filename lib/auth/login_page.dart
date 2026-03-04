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
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  final _emailFocus  = FocusNode();
  final _authService = AuthService();

  bool _cargando  = false;
  bool _verPass   = false;
  bool _recordar  = true;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    // Auto-focus email al abrir
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
    if (msg.contains('user-not-found') || msg.contains('no user'))
      return 'No existe una cuenta con ese correo';
    if (msg.contains('wrong-password') || msg.contains('invalid-credential'))
      return 'Contraseña incorrecta';
    if (msg.contains('too-many-requests'))
      return 'Demasiados intentos. Espera unos minutos';
    if (msg.contains('user-disabled'))
      return 'Esta cuenta ha sido deshabilitada';
    if (msg.contains('network') || msg.contains('socket'))
      return 'Sin conexión. Verifica tu internet';
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
        case 'admin':      destino = const HomeAdmin();      break;
        case 'cocinero':   destino = const HomeCocinero();   break;
        case 'repartidor': destino = const HomeRepartidor(); break;
        case 'mesero':     destino = const HomeMesero();     break;
        default:           destino = const HomeCliente();
      }
      if (mounted) Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => destino));
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
              style: TextStyle(color: Colors.white.withOpacity(0.6),
                  fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(email,
              style: const TextStyle(color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.white.withOpacity(0.4))),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Text('✅', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(child: Text('Revisa tu correo para restablecer la contraseña',
              style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
        duration: const Duration(seconds: 5),
      ));
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
              color: const Color(0xFFFF6B00).withOpacity(0.07)))),
        Positioned(bottom: -100, left: -80,
          child: Container(width: 320, height: 320,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.04)))),
        Positioned(top: 200, left: 20,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.015)))),

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
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFF6B00).withOpacity(0.45),
                              width: 2.5),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.22),
                            blurRadius: 28, spreadRadius: 4)],
                        ),
                        child: const Center(
                            child: Text('🍕',
                                style: TextStyle(fontSize: 46))),
                      ),
                      const SizedBox(height: 20),

                      const Text('LA PIZZERÍA',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6B00),
                            letterSpacing: 5)),
                      const SizedBox(height: 6),
                      Text('Inicia sesión para continuar',
                        style: TextStyle(fontSize: 14,
                            color: Colors.white.withOpacity(0.35))),
                      const SizedBox(height: 40),

                      // Email
                      _Campo(
                        ctrl: _emailCtrl,
                        focusNode: _emailFocus,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        tipo: TextInputType.emailAddress,
                        validar: (v) {
                          if (v == null || v.isEmpty)
                            return 'Ingresa tu correo';
                          if (!v.contains('@') || !v.contains('.'))
                            return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Contraseña
                      _Campo(
                        ctrl: _passCtrl,
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        ocultar: !_verPass,
                        sufijo: IconButton(
                          icon: Icon(
                            _verPass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white.withOpacity(0.3), size: 20),
                          onPressed: () =>
                              setState(() => _verPass = !_verPass),
                        ),
                        validar: (v) {
                          if (v == null || v.isEmpty)
                            return 'Ingresa tu contraseña';
                          if (v.length < 6)
                            return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Fila: recordar + olvidé
                      Row(children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _recordar = !_recordar),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: _recordar
                                    ? const Color(0xFFFF6B00)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _recordar
                                      ? const Color(0xFFFF6B00)
                                      : Colors.white.withOpacity(0.25),
                                  width: 1.5),
                              ),
                              child: _recordar
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 13)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text('Recordar sesión',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 13)),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _olvideMiContrasena,
                          child: Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ]),
                      const SizedBox(height: 28),

                      // Botón login
                      _BtnPrimario(
                        texto: 'INICIAR SESIÓN',
                        cargando: _cargando,
                        onTap: _login,
                      ),
                      const SizedBox(height: 28),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(
                            color: Colors.white.withOpacity(0.07))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('¿No tienes cuenta?',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 12)),
                        ),
                        Expanded(child: Divider(
                            color: Colors.white.withOpacity(0.07))),
                      ]),
                      const SizedBox(height: 16),

                      // Botón registro
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterPage())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B00),
                            side: BorderSide(
                                color: const Color(0xFFFF6B00).withOpacity(0.4),
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('CREAR CUENTA',
                              style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
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

// ── Botón primario animado ────────────────────────────────────
class _BtnPrimario extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback onTap;
  const _BtnPrimario(
      {required this.texto, required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: cargando ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      decoration: BoxDecoration(
        color: cargando
            ? const Color(0xFFFF6B00).withOpacity(0.5)
            : const Color(0xFFFF6B00),
        borderRadius: BorderRadius.circular(14),
        boxShadow: cargando
            ? []
            : [BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Center(
        child: cargando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                )),
      ),
    ),
  );
}

// ── Campo reutilizable ────────────────────────────────────────
class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  final bool ocultar;
  final Widget? sufijo;
  final FocusNode? focusNode;
  final String? Function(String?)? validar;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.tipo = TextInputType.text,
    this.ocultar = false,
    this.sufijo,
    this.focusNode,
    this.validar,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    focusNode: focusNode,
    keyboardType: tipo,
    obscureText: ocultar,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    validator: validar,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.35), fontSize: 14),
      prefixIcon: Icon(icon,
          color: Colors.white.withOpacity(0.3), size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.07))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFFF6B00), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.red.shade400, width: 1.5)),
      errorStyle:
          TextStyle(color: Colors.red.shade400, fontSize: 12),
    ),
  );
}
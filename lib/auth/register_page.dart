import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../utils/paises.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _nombreCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _cedulaCtrl   = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final _authService  = AuthService();

  bool _cargando   = false;
  bool _verPass    = false;
  String _pais     = 'EC';

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _telefonoCtrl.dispose(); _cedulaCtrl.dispose(); _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        rol: 'cliente',
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        cedula: _cedulaCtrl.text.trim(),
        pais: _pais,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cuenta creada — ya puedes iniciar sesión'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear cuenta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: Stack(children: [
        // Decoración fondo
        Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.06)))),

        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Header compacto
                    Center(
                      child: Column(children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 1.5),
                          ),
                          child: const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
                        ),
                        const SizedBox(height: 12),
                        const Text('Regístrate como cliente',
                            style: TextStyle(fontSize: 15, color: Colors.white70)),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // Sección: Datos personales
                    _SeccionLabel('Datos personales'),
                    const SizedBox(height: 10),

                    _Campo(
                      ctrl: _nombreCtrl, label: 'Nombre completo', icon: Icons.person_outline,
                      validar: (v) => (v == null || v.isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 12),

                    // País
                    _DropdownPais(
                      valor: _pais,
                      onChanged: (v) => setState(() => _pais = v!),
                    ),
                    const SizedBox(height: 12),

                    _Campo(
                      ctrl: _cedulaCtrl, label: 'Cédula / Pasaporte', icon: Icons.badge_outlined,
                      tipo: TextInputType.number,
                      validar: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu cédula';
                        if (v.length < 6) return 'Mínimo 6 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    _Campo(
                      ctrl: _telefonoCtrl, label: 'Teléfono', icon: Icons.phone_outlined,
                      tipo: TextInputType.phone,
                      validar: (v) => (v == null || v.isEmpty) ? 'Ingresa tu teléfono' : null,
                    ),
                    const SizedBox(height: 24),

                    // Sección: Acceso
                    _SeccionLabel('Acceso'),
                    const SizedBox(height: 10),

                    _Campo(
                      ctrl: _emailCtrl, label: 'Correo electrónico', icon: Icons.email_outlined,
                      tipo: TextInputType.emailAddress,
                      validar: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu correo';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    _Campo(
                      ctrl: _passCtrl, label: 'Contraseña', icon: Icons.lock_outline,
                      ocultar: !_verPass,
                      sufijo: IconButton(
                        icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade500, size: 20),
                        onPressed: () => setState(() => _verPass = !_verPass),
                      ),
                      validar: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botón crear cuenta
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _registrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _cargando
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('CREAR CUENTA',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ya tengo cuenta
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('¿Ya tienes cuenta? Inicia sesión',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ),
                    ),

                    // Términos
                    Center(
                      child: Text('Al registrarte aceptas nuestros términos y condiciones',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Sección label ─────────────────────────────────────────────
class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel(this.texto);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: const Color(0xFFFF6B00),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(texto, style: const TextStyle(
        color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
  ]);
}

// ── Dropdown país ─────────────────────────────────────────────
class _DropdownPais extends StatelessWidget {
  final String valor;
  final ValueChanged<String?> onChanged;
  const _DropdownPais({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: valor,
        dropdownColor: const Color(0xFF1E293B),
        isExpanded: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: 'País',
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.flag_outlined, color: Colors.grey.shade600, size: 20),
          contentPadding: EdgeInsets.zero,
        ),
        items: Paises.lista.map((p) => DropdownMenuItem<String>(
          value: p['codigo'],
          child: Text('${p['bandera']} ${p['nombre']}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        )).toList(),
        onChanged: onChanged,
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
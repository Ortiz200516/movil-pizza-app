import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../utils/paises.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _nombreCtrl    = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _cedulaCtrl    = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  final _authService   = AuthService();

  bool   _cargando      = false;
  bool   _verPass       = false;
  bool   _verConfirm    = false;
  String _pais          = 'EC';
  int    _paso          = 0; // 0 = personal, 1 = acceso
  double _fuerzaPass    = 0;
  bool?  _emailDisponible; // null=sin verificar, true=libre, false=ocupado
  bool   _verificandoEmail = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _passCtrl.addListener(_calcularFuerza);
  }

  void _calcularFuerza() {
    final p = _passCtrl.text;
    double f = 0;
    if (p.length >= 6)  f += 0.25;
    if (p.length >= 10) f += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) f += 0.25;
    if (p.contains(RegExp(r'[0-9!@#\$%^&*]'))) f += 0.25;
    setState(() => _fuerzaPass = f);
  }

  Color get _colorFuerza {
    if (_fuerzaPass <= 0.25) return Colors.red;
    if (_fuerzaPass <= 0.5)  return Colors.orange;
    if (_fuerzaPass <= 0.75) return Colors.yellow;
    return Colors.green;
  }

  String get _labelFuerza {
    if (_fuerzaPass <= 0.25) return 'Muy débil';
    if (_fuerzaPass <= 0.5)  return 'Débil';
    if (_fuerzaPass <= 0.75) return 'Buena';
    return 'Fuerte 💪';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _confirmCtrl.dispose(); _telefonoCtrl.dispose(); _cedulaCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarEmail(String email) async {
    if (!email.contains('@') || !email.contains('.')) return;
    setState(() { _verificandoEmail = true; _emailDisponible = null; });
    try {
      // fetchSignInMethodsForEmail fue deprecado — usamos signInWithEmailAndPassword
      // con contraseña inválida para detectar si el usuario existe
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: '___invalid___');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // No existe → disponible
          setState(() { _emailDisponible = true; _verificandoEmail = false; });
        } else if (e.code == 'wrong-password' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
          // Existe pero contraseña incorrecta → ya registrado
          setState(() { _emailDisponible = false; _verificandoEmail = false; });
        } else {
          // Otro error (red, etc.) → no mostrar feedback
          setState(() { _emailDisponible = null; _verificandoEmail = false; });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _emailDisponible = null; _verificandoEmail = false; });
      }
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      _snack('Las contraseñas no coinciden', Colors.red);
      return;
    }
    setState(() => _cargando = true);
    try {
      await _authService.register(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        rol:      'cliente',
        nombre:   _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        cedula:   _cedulaCtrl.text.trim(),
        pais:     _pais,
      );
      if (mounted) {
        _snack('✅ ¡Cuenta creada! Ya puedes iniciar sesión', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        // Fondo decorativo
        Positioned(top: -80, right: -60,
          child: Container(width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.06)))),
        Positioned(bottom: -60, left: -60,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.04)))),

        SafeArea(
          child: Column(children: [
            // AppBar custom
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(child: Text('Crear cuenta',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 17),
                    textAlign: TextAlign.center)),
                const SizedBox(width: 40),
              ]),
            ),

            // Indicador de pasos
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                _PasoIndicador(num: 1, label: 'Datos', activo: _paso >= 0, completado: _paso > 0),
                Expanded(child: Container(height: 2,
                    color: _paso > 0 ? const Color(0xFFFF6B00) : Colors.white12)),
                _PasoIndicador(num: 2, label: 'Acceso', activo: _paso >= 1, completado: false),
              ]),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: _paso == 0 ? _buildPaso1() : _buildPaso2(),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Paso 1: Datos personales ──────────────────────────────
  Widget _buildPaso1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Column(children: [
      Container(width: 68, height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 1.5),
        ),
        child: const Center(child: Text('👤', style: TextStyle(fontSize: 32)))),
      const SizedBox(height: 10),
      const Text('Datos personales',
          style: TextStyle(color: Colors.white70, fontSize: 14)),
    ])),
    const SizedBox(height: 24),

    _Campo(ctrl: _nombreCtrl, label: 'Nombre completo', icon: Icons.person_outline,
        validar: (v) => (v?.isEmpty ?? true) ? 'Ingresa tu nombre' : null),
    const SizedBox(height: 12),

    _DropdownPais(valor: _pais, onChanged: (v) => setState(() => _pais = v!)),
    const SizedBox(height: 12),

    _Campo(ctrl: _cedulaCtrl, label: 'Cédula / Pasaporte', icon: Icons.badge_outlined,
        tipo: TextInputType.number,
        validar: (v) {
          if (v?.isEmpty ?? true) return 'Ingresa tu cédula';
          if ((v?.length ?? 0) < 6) return 'Mínimo 6 dígitos';
          return null;
        }),
    const SizedBox(height: 12),

    _Campo(ctrl: _telefonoCtrl, label: 'Teléfono', icon: Icons.phone_outlined,
        tipo: TextInputType.phone,
        validar: (v) => (v?.isEmpty ?? true) ? 'Ingresa tu teléfono' : null),
    const SizedBox(height: 32),

    SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: () {
          // Validar solo los campos del paso 1
          if (_nombreCtrl.text.isEmpty || _cedulaCtrl.text.isEmpty || _telefonoCtrl.text.isEmpty) {
            _snack('Completa todos los campos', Colors.orange);
            return;
          }
          setState(() => _paso = 1);
          _animCtrl.reset();
          _animCtrl.forward();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('CONTINUAR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 18),
        ]),
      ),
    ),
  ]);

  // ── Paso 2: Acceso ────────────────────────────────────────
  Widget _buildPaso2() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Column(children: [
      Container(width: 68, height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 1.5),
        ),
        child: const Center(child: Text('🔐', style: TextStyle(fontSize: 32)))),
      const SizedBox(height: 10),
      const Text('Configura tu acceso',
          style: TextStyle(color: Colors.white70, fontSize: 14)),
    ])),
    const SizedBox(height: 24),

    _CampoConFeedback(
      ctrl: _emailCtrl, label: 'Correo electrónico',
      icon: Icons.email_outlined,
      tipo: TextInputType.emailAddress,
      verificando: _verificandoEmail,
      disponible: _emailDisponible,
      onChanged: (v) {
        if (v.length > 5) _verificarEmail(v.trim());
      },
      validar: (v) {
        if (v?.isEmpty ?? true) return 'Ingresa tu correo';
        if (!(v?.contains('@') ?? false)) return 'Correo inválido';
        if (_emailDisponible == false) return 'Este correo ya está registrado';
        return null;
      }),
    const SizedBox(height: 12),

    _Campo(ctrl: _passCtrl, label: 'Contraseña', icon: Icons.lock_outline,
        ocultar: !_verPass,
        sufijo: IconButton(
          icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade500, size: 20),
          onPressed: () => setState(() => _verPass = !_verPass),
        ),
        validar: (v) {
          if (v?.isEmpty ?? true) return 'Ingresa una contraseña';
          if ((v?.length ?? 0) < 6) return 'Mínimo 6 caracteres';
          return null;
        }),

    // Indicador de fortaleza
    if (_passCtrl.text.isNotEmpty) ...[
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _fuerzaPass, minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(_colorFuerza),
          ),
        )),
        const SizedBox(width: 10),
        Text(_labelFuerza,
            style: TextStyle(color: _colorFuerza, fontSize: 11,
                fontWeight: FontWeight.bold)),
      ]),
    ],
    const SizedBox(height: 12),

    _Campo(ctrl: _confirmCtrl, label: 'Confirmar contraseña', icon: Icons.lock_outline,
        ocultar: !_verConfirm,
        sufijo: IconButton(
          icon: Icon(_verConfirm ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade500, size: 20),
          onPressed: () => setState(() => _verConfirm = !_verConfirm),
        ),
        validar: (v) {
          if (v?.isEmpty ?? true) return 'Confirma tu contraseña';
          if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
          return null;
        }),

    const SizedBox(height: 16),

    // Términos
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Text(
        '🔒 Tu información está protegida y solo se usa para gestionar tus pedidos. No compartimos datos con terceros.',
        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ),

    const SizedBox(height: 24),

    Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () {
            setState(() => _paso = 0);
            _animCtrl.reset();
            _animCtrl.forward();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white12),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Atrás'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _cargando ? null : _registrar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _cargando
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('CREAR CUENTA',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
    ]),
  ]);
}

// ── Indicador de paso ─────────────────────────────────────────
class _PasoIndicador extends StatelessWidget {
  final int num; final String label;
  final bool activo, completado;
  const _PasoIndicador({required this.num, required this.label,
      required this.activo, required this.completado});
  @override
  Widget build(BuildContext context) => Column(children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activo ? const Color(0xFFFF6B00) : const Color(0xFF1E293B),
        border: Border.all(
          color: activo ? const Color(0xFFFF6B00) : Colors.white12,
          width: 2),
      ),
      child: Center(child: completado
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text('$num', style: TextStyle(
              color: activo ? Colors.white : Colors.white38,
              fontWeight: FontWeight.bold, fontSize: 13))),
    ),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(
        color: activo ? const Color(0xFFFF6B00) : Colors.white38,
        fontSize: 11, fontWeight: FontWeight.w600)),
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
  final String label; final IconData icon;
  final TextInputType tipo; final bool ocultar;
  final Widget? sufijo; final String? Function(String?)? validar;
  const _Campo({required this.ctrl, required this.label, required this.icon,
      this.tipo = TextInputType.text, this.ocultar = false,
      this.sufijo, this.validar});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, keyboardType: tipo, obscureText: ocultar,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    validator: validar,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      suffixIcon: sufijo, filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

// ── Campo con feedback de disponibilidad ─────────────────────
class _CampoConFeedback extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  final bool verificando;
  final bool? disponible;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validar;

  const _CampoConFeedback({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.tipo = TextInputType.text,
    this.verificando = false,
    this.disponible,
    this.onChanged,
    this.validar,
  });

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (verificando) {
      trailing = const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: Color(0xFFFF6B00)));
    } else if (disponible == true) {
      trailing = const Icon(Icons.check_circle,
          color: Colors.green, size: 20);
    } else if (disponible == false) {
      trailing = const Icon(Icons.cancel, color: Colors.red, size: 20);
    }

    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      onChanged: onChanged,
      validator: validar,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        suffixIcon: trailing != null
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: trailing)
            : null,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: disponible == false
                  ? Colors.red.withOpacity(0.5)
                  : disponible == true
                      ? Colors.green.withOpacity(0.4)
                      : Colors.white.withOpacity(0.06),
            )),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFFFF6B00), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Colors.red.shade400, width: 1.5)),
        errorStyle:
            TextStyle(color: Colors.red.shade400, fontSize: 12),
      ),
    );
  }
}
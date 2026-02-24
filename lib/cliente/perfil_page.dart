import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_services.dart';
import '../services/theme_provider.dart';
import '../auth/login_page.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _db   = FirebaseFirestore.instance;
  final _auth = AuthService();
  bool _editando = false;
  bool _guardando = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController();
    _telefonoCtrl  = TextEditingController();
    _direccionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
          child: Text('No hay sesión activa', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};

        // Inicializar controladores solo cuando no está editando
        if (!_editando) {
          _nombreCtrl.text    = data['nombre'] ?? '';
          _telefonoCtrl.text  = data['telefono'] ?? '';
          _direccionCtrl.text = data['direccionDefault'] ?? '';
        }

        final nombre   = data['nombre'] ?? data['email']?.split('@')[0] ?? 'Cliente';
        final email    = data['email'] ?? user.email ?? '';
        final telefono = data['telefono'] ?? '';
        final cedula   = data['cedula'] ?? '';
        final pais     = data['pais'] ?? '';
        final rol      = data['rol'] ?? 'cliente';
        final createdAt = data['createdAt'] as Timestamp?;

        // Estadísticas de pedidos
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Avatar + nombre ──
            _Header(nombre: nombre, email: email, rol: rol),

            const SizedBox(height: 8),

            // ── Stats de pedidos ──
            _StatsRow(userId: user.uid),

            const SizedBox(height: 8),

            // ── Preferencias de apariencia ──
            _SeccionApariencia(),

            const SizedBox(height: 16),

            // ── Datos personales ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Datos personales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  if (!_editando)
                    GestureDetector(
                      onTap: () => setState(() => _editando = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.edit, size: 14, color: Colors.orange),
                          SizedBox(width: 5),
                          Text('Editar', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),

                if (_editando) ...[
                  // Modo edición
                  _CampoEditable(ctrl: _nombreCtrl, label: 'Nombre', icon: Icons.person),
                  const SizedBox(height: 12),
                  _CampoEditable(ctrl: _telefonoCtrl, label: 'Teléfono', icon: Icons.phone,
                      tipo: TextInputType.phone),
                  const SizedBox(height: 12),
                  _CampoEditable(ctrl: _direccionCtrl, label: 'Dirección predeterminada', icon: Icons.home),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _editando = false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardando ? null : () => _guardar(user.uid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _guardando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ] else ...[
                  // Modo visualización
                  _InfoTile(Icons.person, 'Nombre', nombre.isEmpty ? 'Sin nombre' : nombre),
                  _InfoTile(Icons.email, 'Email', email),
                  if (telefono.isNotEmpty)
                    _InfoTile(Icons.phone, 'Teléfono', telefono),
                  if (cedula.isNotEmpty)
                    _InfoTile(Icons.badge, 'Cédula', cedula),
                  if (pais.isNotEmpty)
                    _InfoTile(Icons.flag, 'País', pais),
                  if (data['direccionDefault'] != null && (data['direccionDefault'] as String).isNotEmpty)
                    _InfoTile(Icons.home, 'Dirección predeterminada', data['direccionDefault']),
                  if (createdAt != null)
                    _InfoTile(Icons.calendar_today, 'Miembro desde',
                        _formatFecha(createdAt.toDate())),
                ],

                const SizedBox(height: 28),

                // ── Cambiar contraseña ──
                _SeccionBtn(
                  icon: Icons.lock_outline,
                  label: 'Cambiar contraseña',
                  color: Colors.blue,
                  onTap: () => _cambiarPassword(context, email),
                ),
                const SizedBox(height: 10),

                // ── Cerrar sesión ──
                _SeccionBtn(
                  icon: Icons.logout,
                  label: 'Cerrar sesión',
                  color: Colors.red,
                  onTap: () => _cerrarSesion(context),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _guardar(String uid) async {
    setState(() => _guardando = true);
    try {
      await _db.collection('users').doc(uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccionDefault': _direccionCtrl.text.trim(),
      });
      if (mounted) {
        setState(() { _editando = false; _guardando = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Perfil actualizado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cambiarPassword(BuildContext context, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🔐 Cambiar contraseña',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Te enviaremos un enlace de restablecimiento a:\n$email',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Enviar enlace')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📧 Enlace enviado a tu correo'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Tendrás que volver a iniciar sesión.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    await _auth.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  String _formatFecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

// ── Header con avatar ────────────────────────────────────────
class _Header extends StatelessWidget {
  final String nombre, email, rol;
  const _Header({required this.nombre, required this.email, required this.rol});

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        // Avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orange, Color(0xFFFF6B35)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Center(child: Text(inicial,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white))),
        ),
        const SizedBox(height: 14),
        Text(nombre.isNotEmpty ? nombre : 'Mi Perfil',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(email, style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Text(rol.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: Colors.orange,
                  fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ]),
    );
  }
}

// ── Stats de pedidos ─────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String userId;
  const _StatsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snap) {
        final pedidos = snap.data?.docs ?? [];
        final total = pedidos.length;
        final entregados = pedidos.where((p) {
          final d = p.data() as Map<String, dynamic>;
          return d['estado'] == 'Entregado';
        }).length;
        final gastado = pedidos.fold(0.0, (sum, p) {
          final d = p.data() as Map<String, dynamic>;
          if (d['estado'] == 'Entregado') {
            return sum + ((d['total'] ?? 0) as num).toDouble();
          }
          return sum;
        });

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _StatItem('$total', 'Pedidos', Icons.receipt_long, Colors.blue),
            _Divider(),
            _StatItem('$entregados', 'Entregados', Icons.check_circle, Colors.green),
            _Divider(),
            _StatItem('\$${gastado.toStringAsFixed(0)}', 'Gastado', Icons.attach_money, Colors.orange),
          ]),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem(this.value, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 22),
    const SizedBox(height: 6),
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08));
}

// ── Tile de info ─────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.orange),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

// ── Campo editable ───────────────────────────────────────────
class _CampoEditable extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  const _CampoEditable({required this.ctrl, required this.label,
      required this.icon, this.tipo = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.orange),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange)),
    ),
  );
}

// ── Botón de sección ─────────────────────────────────────────
class _SeccionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SeccionBtn({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
      ]),
    ),
  );
}

// ── SECCIÓN APARIENCIA ────────────────────────────────────────
class _SeccionApariencia extends StatelessWidget {
  const _SeccionApariencia();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final oscuro = theme.oscuro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: oscuro ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: oscuro ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Column(children: [
          // Título sección
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Icon(Icons.palette_outlined,
                  size: 16,
                  color: oscuro ? Colors.white38 : Colors.black45),
              const SizedBox(width: 8),
              Text('Apariencia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: oscuro ? Colors.white38 : Colors.black45,
                  )),
            ]),
          ),
          const SizedBox(height: 12),

          // Toggle modo oscuro/claro
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  oscuro ? '🌙' : '☀️',
                  key: ValueKey(oscuro),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    oscuro ? 'Modo oscuro' : 'Modo claro',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: oscuro ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    oscuro ? 'Ideal para uso nocturno' : 'Ideal para uso diurno',
                    style: TextStyle(
                        fontSize: 11,
                        color: oscuro ? Colors.white38 : Colors.black45),
                  ),
                ]),
              ),
              Switch(
                value: oscuro,
                onChanged: (_) => theme.toggleTema(),
                activeColor: const Color(0xFFFF6B00),
                activeTrackColor: const Color(0xFFFF6B00).withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.2),
              ),
            ]),
          ),

          // Preview de tema
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: oscuro ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
                  ),
                  child: const Center(child: Text('🍕', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vista previa',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: oscuro ? Colors.white70 : const Color(0xFF334155),
                      )),
                  Text('La Pizzería · ${oscuro ? 'Oscuro' : 'Claro'}',
                      style: TextStyle(
                          fontSize: 10,
                          color: oscuro ? Colors.white24 : Colors.black45)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Activo',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
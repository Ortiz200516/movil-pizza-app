import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = AuthService();
  bool _editando = false;
  bool _guardando = false;
  bool _subiendoFoto = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _apellidoCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _direccionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // ── Subir foto de perfil ──────────────────────────────────────
  Future<void> _seleccionarFoto(String uid) async {
    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Foto de perfil',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.orange),
            ),
            title:
                const Text('Tomar foto', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.photo_library, color: Colors.blue),
            ),
            title: const Text('Elegir de galería',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );

    if (opcion == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: opcion,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final file = File(picked.path);
      final ref = _storage.ref().child('perfiles/$uid/foto.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(uid).update({'fotoUrl': url});
      if (mounted) {
        _snack('✅ Foto actualizada', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error al subir foto: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
          child: Text('No hay sesión activa',
              style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }

        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};

        if (!_editando) {
          _nombreCtrl.text = data['nombre'] ?? '';
          _apellidoCtrl.text = data['apellido'] ?? '';
          _telefonoCtrl.text = data['telefono'] ?? '';
          _direccionCtrl.text = data['direccionDefault'] ?? '';
        }

        final nombre =
            data['nombre'] ?? data['email']?.split('@')[0] ?? 'Cliente';
        final apellido = data['apellido'] ?? '';
        final email = data['email'] ?? user.email ?? '';
        final telefono = data['telefono'] ?? '';
        final cedula = data['cedula'] ?? '';
        final pais = data['pais'] ?? '';
        final rol = data['rol'] ?? 'cliente';
        final fotoUrl = data['fotoUrl'] as String?;
        final createdAt = data['createdAt'] as Timestamp?;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header con foto ──
            _buildHeader(
              uid: user.uid,
              nombre: nombre,
              apellido: apellido,
              email: email,
              rol: rol,
              fotoUrl: fotoUrl,
            ),

            const SizedBox(height: 8),

            // ── Stats ──
            _StatsRow(userId: user.uid),

            const SizedBox(height: 8),

            // ── Apariencia ──
            _SeccionApariencia(),

            const SizedBox(height: 16),

            // ── Datos personales ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Datos personales',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const Spacer(),
                      if (!_editando)
                        GestureDetector(
                          onTap: () => setState(() => _editando = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.edit, size: 14, color: Colors.orange),
                              SizedBox(width: 5),
                              Text('Editar',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),

                    if (_editando) ...[
                      _CampoEditable(
                          ctrl: _nombreCtrl,
                          label: 'Nombre',
                          icon: Icons.person),
                      const SizedBox(height: 12),
                      _CampoEditable(
                          ctrl: _apellidoCtrl,
                          label: 'Apellido',
                          icon: Icons.person_outline),
                      const SizedBox(height: 12),
                      _CampoEditable(
                          ctrl: _telefonoCtrl,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          tipo: TextInputType.phone),
                      const SizedBox(height: 12),
                      _CampoEditable(
                          ctrl: _direccionCtrl,
                          label: 'Dirección predeterminada',
                          icon: Icons.home),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _editando = false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white54,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _guardando ? null : () => _guardar(user.uid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Guardar',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ] else ...[
                      _InfoTile(
                          Icons.person,
                          'Nombre',
                          [nombre, apellido]
                              .where((s) => s.isNotEmpty)
                              .join(' ')),
                      _InfoTile(Icons.email, 'Email', email),
                      if (telefono.isNotEmpty)
                        _InfoTile(Icons.phone, 'Teléfono', telefono),
                      if (cedula.isNotEmpty)
                        _InfoTile(Icons.badge, 'Cédula', cedula),
                      if (pais.isNotEmpty) _InfoTile(Icons.flag, 'País', pais),
                      if (data['direccionDefault'] != null &&
                          (data['direccionDefault'] as String).isNotEmpty)
                        _InfoTile(Icons.home, 'Dirección predeterminada',
                            data['direccionDefault']),
                      if (createdAt != null)
                        _InfoTile(Icons.calendar_today, 'Miembro desde',
                            _formatFecha(createdAt.toDate())),
                    ],

                    const SizedBox(height: 28),

                    // ── Cupones ──
                    _CuponesSection(userId: user.uid),
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

  // ── Header con foto editable ──────────────────────────────────
  Widget _buildHeader({
    required String uid,
    required String nombre,
    required String apellido,
    required String email,
    required String rol,
    required String? fotoUrl,
  }) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        // Avatar con botón de cámara
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: ClipOval(
                child: _subiendoFoto
                    ? Container(
                        color: const Color(0xFF1E293B),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.orange, strokeWidth: 2)))
                    : fotoUrl != null && fotoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: fotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.orange.withOpacity(0.2),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.orange, strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => _avatarLetra(inicial),
                          )
                        : _avatarLetra(inicial),
              ),
            ),
            // Botón cámara
            GestureDetector(
              onTap: _subiendoFoto ? null : () => _seleccionarFoto(uid),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 2),
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          [nombre, apellido].where((s) => s.isNotEmpty).join(' ').isEmpty
              ? 'Mi Perfil'
              : [nombre, apellido].where((s) => s.isNotEmpty).join(' '),
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(email,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Text(rol.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ),
      ]),
    );
  }

  Widget _avatarLetra(String inicial) => Container(
        color: Colors.orange.withOpacity(0.2),
        child: Center(
            child: Text(inicial,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange))),
      );

  Future<void> _guardar(String uid) async {
    setState(() => _guardando = true);
    try {
      await _db.collection('users').doc(uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccionDefault': _direccionCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _editando = false;
          _guardando = false;
        });
        _snack('✅ Perfil actualizado', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        _snack('Error: $e', Colors.red);
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
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              child: const Text('Enviar enlace')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        _snack('📧 Enlace enviado a tu correo', Colors.green);
      }
    } catch (e) {
      if (context.mounted) _snack('Error: $e', Colors.red);
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
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
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

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _formatFecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

// ── Stats de pedidos ──────────────────────────────────────────
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem('📦', '$total', 'Pedidos'),
              _Divider(),
              _StatItem('✅', '$entregados', 'Entregados'),
              _Divider(),
              _StatItem('💰', '\$${gastado.toStringAsFixed(2)}', 'Gastado'),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji, valor, label;
  const _StatItem(this.emoji, this.valor, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(valor,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.white10);
}

// ── Sección apariencia ────────────────────────────────────────
class _SeccionApariencia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        const Icon(Icons.palette_outlined, color: Colors.orange, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tema de la app',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text('Cambia entre claro y oscuro',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
        Switch(
          value: theme.oscuro,
          onChanged: (_) => theme.toggleTema(),
          activeColor: Colors.orange,
        ),
      ]),
    );
  }
}

// ── Cupones activos ───────────────────────────────────────────
class _CuponesSection extends StatelessWidget {
  final String userId;
  const _CuponesSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cupones')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final cupones = snap.data?.docs ?? [];
        if (cupones.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🎟️ Cupones disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 10),
          ...cupones.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final codigo = d['codigo'] ?? '';
            final tipo = d['tipo'] ?? 'porcentaje';
            final valor = (d['descuento'] as num?)?.toDouble() ?? 0.0;
            final desc = tipo == 'porcentaje'
                ? '$valor% de descuento'
                : '\$$valor de descuento';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Text('🎟️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(codigo,
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.5)),
                      Text(desc,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ])),
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ]),
            );
          }),
        ]);
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────
class _CampoEditable extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  const _CampoEditable({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.tipo = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: tipo,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.orange, size: 20),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange)),
        ),
      );
}

Widget _InfoTile(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.orange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ])),
      ]),
    );

class _SeccionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SeccionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 14),
          ]),
        ),
      );
}

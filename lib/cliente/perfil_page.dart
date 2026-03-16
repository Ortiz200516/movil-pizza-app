import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_services.dart';
import '../services/theme_provider.dart';
import '../auth/login_page.dart';

// ── Colores ──────────────────────────────────────────────────────────────────
const _kOrange  = Color(0xFFFF6B00);
const _kOrange2 = Color(0xFFFF9A3C);
const _kBg      = Color(0xFF0F172A);
const _kCard    = Color(0xFF1E293B);

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _db   = FirebaseFirestore.instance;
  final _auth = AuthService();

  bool _editando  = false;
  bool _guardando = false;
  bool _subiendo  = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController();
    _telefonoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
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
              child: CircularProgressIndicator(color: _kOrange));
        }
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};

        if (!_editando) {
          _nombreCtrl.text   = data['nombre'] ?? '';
          _telefonoCtrl.text = data['telefono'] ?? '';
        }

        final nombre    = data['nombre'] ?? data['email']?.split('@')[0] ?? 'Cliente';
        final email     = data['email'] ?? user.email ?? '';
        final telefono  = data['telefono'] ?? '';
        final fotoUrl   = data['fotoUrl'] as String?;
        final createdAt = data['createdAt'] as Timestamp?;

        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('pedidos')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, pedSnap) {
            final pedidos = pedSnap.data?.docs ?? [];
            final entregados = pedidos.where((p) =>
                (p.data() as Map)['estado'] == 'Entregado').length;
            final gastado = pedidos.fold(0.0, (s, p) {
              final d = p.data() as Map<String, dynamic>;
              if (d['estado'] == 'Entregado') {
                return s + ((d['total'] ?? 0) as num).toDouble();
              }
              return s;
            });
            final nivel = _calcularNivel(entregados);

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Header ──────────────────────────────
                _HeaderPerfil(
                  nombre: nombre, email: email,
                  fotoUrl: fotoUrl, nivel: nivel,
                  subiendo: _subiendo,
                  onCambiarFoto: () => _cambiarFoto(user.uid),
                ),

                // ── Nivel / progreso ─────────────────────
                _NivelCard(entregados: entregados,
                    nivel: nivel, gastado: gastado),
                const SizedBox(height: 12),

                // ── Stats ────────────────────────────────
                _StatsRow(total: pedidos.length,
                    entregados: entregados, gastado: gastado),
                const SizedBox(height: 12),

                // ── Apariencia ───────────────────────────
                const _SeccionApariencia(),
                const SizedBox(height: 12),

                // ── Datos personales ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment:
                      CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Datos personales', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                      const Spacer(),
                      if (!_editando)
                        GestureDetector(
                          onTap: () => setState(() => _editando = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _kOrange.withValues(alpha: 0.4)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.edit, size: 13, color: _kOrange),
                              SizedBox(width: 5),
                              Text('Editar', style: TextStyle(
                                  fontSize: 12, color: _kOrange,
                                  fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),

                    if (_editando) ...[
                      _CampoEditable(ctrl: _nombreCtrl,
                          label: 'Nombre', icon: Icons.person),
                      const SizedBox(height: 12),
                      _CampoEditable(ctrl: _telefonoCtrl,
                          label: 'Teléfono', icon: Icons.phone,
                          tipo: TextInputType.phone),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => setState(() => _editando = false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancelar'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(
                          onPressed: _guardando
                              ? null : () => _guardar(user.uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _guardando
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Guardar', style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        )),
                      ]),
                    ] else ...[
                      _InfoTile(Icons.person, 'Nombre',
                          nombre.isEmpty ? 'Sin nombre' : nombre),
                      _InfoTile(Icons.email, 'Email', email),
                      if (telefono.isNotEmpty)
                        _InfoTile(Icons.phone, 'Teléfono', telefono),
                      if (createdAt != null)
                        _InfoTile(Icons.calendar_today, 'Miembro desde',
                            _formatFecha(createdAt.toDate())),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Direcciones guardadas ─────────────────
                _DireccionesSection(userId: user.uid),
                const SizedBox(height: 20),

                // ── Pedidos recientes ─────────────────────
                _PedidosRecientes(userId: user.uid),
                const SizedBox(height: 20),

                // ── Cupones ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CuponesSection(userId: user.uid),
                ),
                const SizedBox(height: 20),

                // ── Acciones ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    _SeccionBtn(
                      icon: Icons.lock_outline,
                      label: 'Cambiar contraseña',
                      color: Colors.blue,
                      onTap: () => _cambiarPassword(context, email),
                    ),
                    const SizedBox(height: 10),
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
      },
    );
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  _NivelInfo _calcularNivel(int entregados) {
    if (entregados >= 20) {
      return _NivelInfo('⭐ VIP', Colors.amber,
          '¡Eres nuestro cliente más especial!', 1.0);
    } else if (entregados >= 8) {
      return _NivelInfo('🔥 Regular', _kOrange,
          '${20 - entregados} pedidos para llegar a VIP',
          entregados / 20.0);
    } else {
      return _NivelInfo('🌱 Nuevo', Colors.green,
          '${8 - entregados} pedidos para ser Regular',
          entregados / 8.0);
    }
  }

  Future<void> _cambiarFoto(String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 400);
    if (picked == null) return;

    setState(() => _subiendo = true);
    try {
      final file = File(picked.path);
      final ref  = FirebaseStorage.instance.ref('perfiles/$uid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(uid).update({'fotoUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Foto actualizada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error subiendo foto: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _guardar(String uid) async {
    setState(() => _guardando = true);
    try {
      await _db.collection('users').doc(uid).update({
        'nombre':   _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      });
      if (mounted) {
        setState(() { _editando = false; _guardando = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Perfil actualizado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🔐 Cambiar contraseña', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Te enviaremos un enlace a:\n$email',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange, foregroundColor: Colors.white),
              child: const Text('Enviar enlace')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📧 Enlace enviado a tu correo'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
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
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
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

  String _formatFecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/'
      '${f.month.toString().padLeft(2, '0')}/${f.year}';
}

// ── Modelo de nivel ───────────────────────────────────────────────────────────
class _NivelInfo {
  final String label, descripcion;
  final Color color;
  final double progreso;
  const _NivelInfo(this.label, this.color, this.descripcion, this.progreso);
}

// ── Header con foto ───────────────────────────────────────────────────────────
class _HeaderPerfil extends StatelessWidget {
  final String nombre, email;
  final String? fotoUrl;
  final _NivelInfo nivel;
  final bool subiendo;
  final VoidCallback onCambiarFoto;
  const _HeaderPerfil({
    required this.nombre, required this.email, this.fotoUrl,
    required this.nivel, required this.subiendo,
    required this.onCambiarFoto,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A00), Color(0xFF1E293B)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        // Avatar con botón de cámara
        Stack(alignment: Alignment.bottomRight, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: fotoUrl == null ? const LinearGradient(
                colors: [_kOrange, _kOrange2],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ) : null,
              boxShadow: [BoxShadow(
                  color: _kOrange.withValues(alpha: 0.35),
                  blurRadius: 24, spreadRadius: 2)],
            ),
            child: fotoUrl != null
                ? ClipOval(child: Image.network(fotoUrl!,
                    fit: BoxFit.cover, width: 90, height: 90,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(inicial, style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold,
                            color: Colors.white)))))
                : Center(child: Text(inicial, style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold,
                    color: Colors.white))),
          ),
          GestureDetector(
            onTap: onCambiarFoto,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: subiendo ? Colors.white24 : _kOrange,
                shape: BoxShape.circle,
                border: Border.all(color: _kBg, width: 2),
              ),
              child: Center(child: subiendo
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(nombre.isNotEmpty ? nombre : 'Mi Perfil',
            style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(email, style: TextStyle(
            fontSize: 13, color: Colors.white38)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: nivel.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: nivel.color.withValues(alpha: 0.4)),
          ),
          child: Text(nivel.label, style: TextStyle(
              fontSize: 12, color: nivel.color,
              fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}

// ── Tarjeta nivel + progreso ──────────────────────────────────────────────────
class _NivelCard extends StatelessWidget {
  final int entregados;
  final _NivelInfo nivel;
  final double gastado;
  const _NivelCard({required this.entregados,
      required this.nivel, required this.gastado});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nivel.color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(nivel.label, style: TextStyle(
              color: nivel.color,
              fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Text('$entregados pedidos completados',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: nivel.progreso, minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(nivel.color),
          ),
        ),
        const SizedBox(height: 6),
        Text(nivel.descripcion, style: TextStyle(
            color: nivel.color.withValues(alpha: 0.7), fontSize: 11)),
      ]),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, entregados;
  final double gastado;
  const _StatsRow({required this.total,
      required this.entregados, required this.gastado});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _StatItem('$total', 'Pedidos', Icons.receipt_long, Colors.blue),
        Container(width: 1, height: 40,
            color: Colors.white.withValues(alpha: 0.08)),
        _StatItem('$entregados', 'Entregados',
            Icons.check_circle, Colors.green),
        Container(width: 1, height: 40,
            color: Colors.white.withValues(alpha: 0.08)),
        _StatItem('\$${gastado.toStringAsFixed(0)}', 'Gastado',
            Icons.attach_money, _kOrange),
      ]),
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
    Text(value, style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(
        fontSize: 11, color: Colors.white38)),
  ]);
}

// ── Direcciones guardadas ─────────────────────────────────────────────────────
class _DireccionesSection extends StatelessWidget {
  final String userId;
  const _DireccionesSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final rawDirs = data['direcciones'];
        final List<String> dirs = rawDirs is List
            ? rawDirs.map((e) => e.toString()).toList() : [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment:
              CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Mis direcciones', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: () => _agregarDireccion(context, userId, dirs),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.add, size: 13, color: _kOrange),
                    SizedBox(width: 4),
                    Text('Agregar', style: TextStyle(
                        fontSize: 12, color: _kOrange,
                        fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (dirs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: const Column(children: [
                  Text('📍', style: TextStyle(fontSize: 28)),
                  SizedBox(height: 6),
                  Text('Sin direcciones guardadas',
                      style: TextStyle(color: Colors.white38,
                          fontSize: 13)),
                ]),
              )
            else
              ...dirs.asMap().entries.map((e) => _DireccionTile(
                direccion: e.value,
                esPredeterminada: e.key == 0,
                onEliminar: () {
                  final nuevas = List<String>.from(dirs)
                    ..removeAt(e.key);
                  FirebaseFirestore.instance
                      .collection('users').doc(userId)
                      .update({'direcciones': nuevas});
                },
              )),
          ]),
        );
      },
    );
  }

  void _agregarDireccion(
      BuildContext context, String userId, List<String> dirs) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📍 Nueva dirección', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: 16)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Calle, número, sector...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.location_on, color: _kOrange),
              filled: true, fillColor: _kBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _kOrange.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: _kOrange, width: 2)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                final nuevas = [...dirs, ctrl.text.trim()];
                FirebaseFirestore.instance
                    .collection('users').doc(userId)
                    .update({'direcciones': nuevas});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar dirección',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _DireccionTile extends StatelessWidget {
  final String direccion;
  final bool esPredeterminada;
  final VoidCallback onEliminar;
  const _DireccionTile({required this.direccion,
      required this.esPredeterminada, required this.onEliminar});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: esPredeterminada
            ? _kOrange.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
    ),
    child: Row(children: [
      Icon(esPredeterminada ? Icons.home : Icons.location_on,
          color: esPredeterminada ? _kOrange : Colors.white38,
          size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(direccion, style: const TextStyle(
            color: Colors.white, fontSize: 13)),
        if (esPredeterminada)
          const Text('Predeterminada', style: TextStyle(
              color: _kOrange, fontSize: 10,
              fontWeight: FontWeight.bold)),
      ])),
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
        onPressed: onEliminar,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]),
  );
}

// ── Pedidos recientes ─────────────────────────────────────────────────────────
class _PedidosRecientes extends StatelessWidget {
  final String userId;
  const _PedidosRecientes({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment:
              CrossAxisAlignment.start, children: [
            const Text('Pedidos recientes', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: Colors.white)),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final data   = d.data() as Map<String, dynamic>;
              final estado = data['estado'] as String? ?? '';
              final total  = (data['total'] as num?)?.toDouble() ?? 0.0;
              final items  = (data['items'] as List?)?.length ?? 0;
              final fecha  = (data['fecha'] as Timestamp?)?.toDate();
              final color  = estado == 'Entregado' ? Colors.green
                  : estado == 'En camino' ? Colors.blue
                  : estado == 'Listo' ? Colors.teal : _kOrange;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(
                      estado == 'Entregado' ? '✅'
                          : estado == 'En camino' ? '🛵'
                          : estado == 'Listo' ? '🍕' : '⏳',
                      style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$items producto${items == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    if (fecha != null)
                      Text(_fmtFecha(fecha), style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment:
                      CrossAxisAlignment.end, children: [
                    Text('\$${total.toStringAsFixed(2)}',
                        style: TextStyle(color: color,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(estado, style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }

  String _fmtFecha(DateTime f) {
    final diff = DateTime.now().difference(f);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return '${f.day}/${f.month}/${f.year}';
  }
}

// ── Cupones ───────────────────────────────────────────────────────────────────
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
        if (!snap.hasData) return const SizedBox.shrink();
        final now = DateTime.now();
        final cupones = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final exp  = data['expira'] as Timestamp?;
          return exp == null || exp.toDate().isAfter(now);
        }).toList();
        if (cupones.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('🎟️ Cupones disponibles', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold,
              color: Colors.white)),
          const SizedBox(height: 10),
          ...cupones.map((d) {
            final c           = d.data() as Map<String, dynamic>;
            final codigo      = c['codigo'] ?? d.id;
            final descripcion = c['descripcion'] ?? '';
            final descuento   = (c['descuento'] ?? 0).toDouble();
            final tipo        = c['tipo'] ?? 'porcentaje';
            final label       = tipo == 'porcentaje'
                ? '${descuento.toStringAsFixed(0)}% OFF'
                : '\$${descuento.toStringAsFixed(2)} OFF';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _kOrange.withValues(alpha: 0.12), _kCard,
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _kOrange.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(label, style: const TextStyle(
                      color: _kOrange, fontWeight: FontWeight.w900,
                      fontSize: 15)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(codigo, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 14, letterSpacing: 1.5)),
                  if (descripcion.isNotEmpty)
                    Text(descripcion, style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                ])),
                IconButton(
                  icon: const Icon(Icons.copy,
                      color: Colors.white38, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('📋 "$codigo" copiado'),
                      backgroundColor: _kOrange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                  },
                ),
              ]),
            );
          }),
        ]);
      },
    );
  }
}

// ── Widgets comunes ───────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: _kOrange),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 11, color: Colors.white38)),
        Text(value, style: const TextStyle(
            fontSize: 14, color: Colors.white,
            fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

class _CampoEditable extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  const _CampoEditable({required this.ctrl, required this.label,
      required this.icon, this.tipo = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tipo,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: _kOrange),
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kOrange)),
    ),
  );
}

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
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(
            fontSize: 15, color: color, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
      ]),
    ),
  );
}

class _SeccionApariencia extends StatelessWidget {
  const _SeccionApariencia();
  @override
  Widget build(BuildContext context) {
    final theme  = context.watch<ThemeProvider>();
    final oscuro = theme.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: oscuro ? _kCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: oscuro ? Colors.white10 : Colors.black12),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Icon(Icons.palette_outlined, size: 16,
                  color: oscuro ? Colors.white38 : Colors.black45),
              const SizedBox(width: 8),
              Text('Apariencia', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: oscuro ? Colors.white38 : Colors.black45)),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(oscuro ? '🌙' : '☀️',
                    key: ValueKey(oscuro),
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(oscuro ? 'Modo oscuro' : 'Modo claro',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: oscuro ? Colors.white
                            : const Color(0xFF0F172A))),
                Text(oscuro ? 'Ideal para uso nocturno'
                    : 'Ideal para uso diurno',
                    style: TextStyle(fontSize: 11,
                        color: oscuro
                            ? Colors.white38 : Colors.black45)),
              ])),
              Switch(
                value: oscuro,
                onChanged: (_) => theme.toggleTheme(),
                activeThumbColor: _kOrange,
                activeTrackColor: _kOrange.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white24,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
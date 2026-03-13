import 'package:flutter/material.dart';
import '../services/usuarios_service.dart';
import '../models/usuario.dart';
import '../utils/paises.dart';

// ── Paleta de roles ───────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);

// Color, icono y etiqueta por rol
const _kRoles = {
  'admin':      {'color': Color(0xFFAB47BC), 'label': 'Admin',       'emoji': '👑'},
  'cocinero':   {'color': Color(0xFFFF7043), 'label': 'Cocinero',    'emoji': '👨‍🍳'},
  'repartidor': {'color': Color(0xFF26C6DA), 'label': 'Repartidor',  'emoji': '🛵'},
  'mesero':     {'color': Color(0xFF42A5F5), 'label': 'Mesero',      'emoji': '🍽️'},
  'cliente':    {'color': Color(0xFF66BB6A), 'label': 'Cliente',     'emoji': '👤'},
};

IconData _iconoRol(String rol) {
  switch (rol) {
    case 'admin':      return Icons.admin_panel_settings;
    case 'cocinero':   return Icons.restaurant;
    case 'repartidor': return Icons.delivery_dining;
    case 'mesero':     return Icons.room_service;
    default:           return Icons.person;
  }
}

Color _colorRol(String rol) =>
    (_kRoles[rol]?['color'] as Color?) ?? const Color(0xFF78909C);

String _emojiRol(String rol) =>
    (_kRoles[rol]?['emoji'] as String?) ?? '👤';

String _labelRol(String rol) =>
    (_kRoles[rol]?['label'] as String?) ?? rol;

// ─────────────────────────────────────────────────────────────────────────────
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final UsuariosService _svc = UsuariosService();
  final _buscarCtrl = TextEditingController();
  String _filtroRol = 'todos';
  String _query     = '';

  @override
  void dispose() { _buscarCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('👥 Gestión de Usuarios',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // ── Buscador ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          color: const Color(0xFF12082A),
          child: TextField(
            controller: _buscarCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, email o cédula…',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              prefixIcon: Icon(Icons.search,
                  color: Colors.white.withValues(alpha: 0.4), size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 18),
                      onPressed: () => setState(() {
                        _buscarCtrl.clear(); _query = '';
                      }),
                    )
                  : null,
              filled: true,
              fillColor: _kCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
            ),
          ),
        ),

        // ── Chips de rol ──────────────────────────────────────────────────
        Container(
          color: const Color(0xFF12082A),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FiltroChip(
                label: 'Todos',
                emoji: '👥',
                color: const Color(0xFFAB47BC),
                selected: _filtroRol == 'todos',
                onTap: () => setState(() => _filtroRol = 'todos'),
              ),
              const SizedBox(width: 8),
              ..._kRoles.entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FiltroChip(
                  label: e.value['label'] as String,
                  emoji: e.value['emoji'] as String,
                  color: e.value['color'] as Color,
                  selected: _filtroRol == e.key,
                  onTap: () => setState(() => _filtroRol = e.key),
                ),
              )),
            ]),
          ),
        ),

        // ── Contador ──────────────────────────────────────────────────────
        const Divider(height: 1, color: Colors.white10),

        // ── Lista ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Usuario>>(
            stream: _svc.obtenerTodosUsuarios(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFAB47BC)));
              }
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red)));
              }

              var usuarios = snap.data ?? [];

              // Filtro rol
              if (_filtroRol != 'todos') {
                usuarios = usuarios
                    .where((u) => u.rol == _filtroRol)
                    .toList();
              }

              // Filtro búsqueda
              if (_query.isNotEmpty) {
                usuarios = usuarios.where((u) {
                  final n = (u.nombre ?? '').toLowerCase();
                  final e = u.email.toLowerCase();
                  final c = (u.cedula ?? '').toLowerCase();
                  return n.contains(_query) ||
                      e.contains(_query) ||
                      c.contains(_query);
                }).toList();
              }

              if (usuarios.isEmpty) {
                return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(_query.isNotEmpty ? '🔍' : '👥',
                      style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(
                    _query.isNotEmpty
                        ? 'Sin resultados para "$_query"'
                        : 'No hay usuarios en este rol',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ]));
              }

              // Header con conteo
              return Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: _kBg,
                  child: Text(
                    '${usuarios.length} usuario${usuarios.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: usuarios.length,
                    itemBuilder: (_, i) =>
                        _UsuarioCard(usuario: usuarios[i], svc: _svc),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FiltroChip({required this.label, required this.emoji,
      required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.22)
            : _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1),
        boxShadow: selected
            ? [BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white60,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
                fontSize: 12)),
      ]),
    ),
  );
}

// ── Card de usuario ───────────────────────────────────────────────────────────
class _UsuarioCard extends StatelessWidget {
  final Usuario usuario;
  final UsuariosService svc;
  const _UsuarioCard({required this.usuario, required this.svc});

  @override
  Widget build(BuildContext context) {
    final color  = _colorRol(usuario.rol);
    final emoji  = _emojiRol(usuario.rol);
    final label  = _labelRol(usuario.rol);
    final icono  = _iconoRol(usuario.rol);
    final nombre = usuario.nombre ?? 'Sin nombre';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          collapsedIconColor: Colors.white38,
          iconColor: color,
          leading: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 20))),
          ),
          title: Text(nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const SizedBox(height: 3),
            Text(usuario.email,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),

            // Badge rol con color vibrante
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.5)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(icono, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ]),
              ),
              if (usuario.pais != null &&
                  usuario.cedula != null) ...[
                const SizedBox(width: 8),
                Text(usuario.paisConBandera,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(usuario.cedula!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ]),
            const SizedBox(height: 4),
          ]),
          children: [
            Container(
              decoration: BoxDecoration(
                color: _kCard2,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                border: Border(
                    top: BorderSide(
                        color: color.withValues(alpha: 0.15))),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Info detallada
                _InfoFila(Icons.person, 'Nombre', nombre, color),
                _InfoFila(Icons.email, 'Email', usuario.email, color),
                if (usuario.telefono != null)
                  _InfoFila(Icons.phone, 'Teléfono',
                      usuario.telefono!, color),
                if (usuario.cedula != null && usuario.pais != null)
                  _InfoFila(Icons.badge, 'Cédula',
                      '${usuario.paisConBandera} - ${usuario.cedula}',
                      color),

                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                // Cambiar rol
                Text('Cambiar rol',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 10),

                Wrap(spacing: 8, runSpacing: 8,
                    children: _kRoles.entries.map((e) =>
                      _RolBtn(
                        usuario: usuario,
                        rol: e.key,
                        label: e.value['label'] as String,
                        emoji: e.value['emoji'] as String,
                        icono: _iconoRol(e.key),
                        color: e.value['color'] as Color,
                        svc: svc,
                      )
                    ).toList()),

                // Toggle disponibilidad
                if (usuario.rol == 'repartidor' ||
                    usuario.rol == 'mesero') ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  _ToggleDisponible(usuario: usuario, svc: svc),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de información ───────────────────────────────────────────────────────
class _InfoFila extends StatelessWidget {
  final IconData icono;
  final String label, valor;
  final Color color;
  const _InfoFila(this.icono, this.label, this.valor, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Icon(icono, size: 15,
          color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      Expanded(child: Text(valor,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12))),
    ]),
  );
}

// ── Botón de rol ──────────────────────────────────────────────────────────────
class _RolBtn extends StatelessWidget {
  final Usuario usuario;
  final String rol, label, emoji;
  final IconData icono;
  final Color color;
  final UsuariosService svc;
  const _RolBtn({required this.usuario, required this.rol,
      required this.label, required this.emoji, required this.icono,
      required this.color, required this.svc});

  @override
  Widget build(BuildContext context) {
    final esCurrent = usuario.rol == rol;
    return GestureDetector(
      onTap: esCurrent ? null : () => _confirmar(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: esCurrent
              ? color.withValues(alpha: 0.25)
              : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: esCurrent
                  ? color.withValues(alpha: 0.8)
                  : color.withValues(alpha: 0.3),
              width: esCurrent ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: esCurrent ? color : color.withValues(alpha: 0.7),
                  fontWeight: esCurrent
                      ? FontWeight.w900
                      : FontWeight.w600,
                  fontSize: 12)),
          if (esCurrent) ...[
            const SizedBox(width: 5),
            Icon(Icons.check_circle, size: 13, color: color),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          const Text('Cambiar rol',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          '¿Cambiar a ${usuario.nombre ?? usuario.email} al rol de $label?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(icono, size: 15),
            label: Text(label),
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );

    if (ok == true) {
      await svc.cambiarRol(usuario.uid, rol);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$emoji Rol cambiado a $label'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }
}

// ── Toggle disponibilidad ─────────────────────────────────────────────────────
class _ToggleDisponible extends StatelessWidget {
  final Usuario usuario;
  final UsuariosService svc;
  const _ToggleDisponible(
      {required this.usuario, required this.svc});

  @override
  Widget build(BuildContext context) {
    final disponible = usuario.disponible ?? false;
    final color = disponible
        ? const Color(0xFF66BB6A)
        : Colors.white38;

    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Disponible',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        Text(disponible ? '✅ En servicio' : '⛔ No disponible',
            style: TextStyle(color: color, fontSize: 11)),
      ]),
      Switch(
        value: disponible,
        onChanged: (v) async {
          await svc.cambiarDisponibilidad(usuario.uid, v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  v ? '✅ Marcado como disponible'
                    : '⛔ Marcado como no disponible'),
              backgroundColor:
                  v ? const Color(0xFF66BB6A) : Colors.blueGrey,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        activeColor: const Color(0xFF66BB6A),
        activeTrackColor:
            const Color(0xFF66BB6A).withValues(alpha: 0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: Colors.white12,
      ),
    ]);
  }
}
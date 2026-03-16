import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromocionesAdminPage extends StatefulWidget {
  const PromocionesAdminPage({super.key});
  @override
  State<PromocionesAdminPage> createState() => _PromocionesAdminPageState();
}

class _PromocionesAdminPageState extends State<PromocionesAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('🔥 Promociones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'BANNERS'),
            Tab(text: 'COMBOS'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tab.index == 0 ? _mostrarFormBanner() : _mostrarFormCombo(),
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0 ? 'Nuevo banner' : 'Nuevo combo',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabBanners(db: _db, onEditar: _mostrarFormBanner),
          _TabCombos(db: _db, onEditar: _mostrarFormCombo),
        ],
      ),
    );
  }

  // ── Formulario Banner ─────────────────────────────────────
  void _mostrarFormBanner({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final tituloCtrl = TextEditingController(text: data?['titulo'] ?? '');
    final subCtrl    = TextEditingController(text: data?['subtitulo'] ?? '');
    final ordenCtrl  = TextEditingController(text: data?['orden']?.toString() ?? '1');
    String color     = data?['color'] ?? 'naranja';
    String emoji     = data?['emoji'] ?? '🔥';
    bool   activo    = data?['activo'] ?? true;
    DateTime? inicio = (data?['inicio'] as Timestamp?)?.toDate();
    DateTime? fin    = (data?['fin'] as Timestamp?)?.toDate();

    final emojis = ['🔥','🍕','⭐','🎉','💥','🤑','🎁','🌟','🏆','🆕'];
    final colores = {
      'naranja': const Color(0xFFFF6B00),
      'rojo':    Colors.red.shade600,
      'verde':   Colors.green.shade600,
      'azul':    Colors.blue.shade600,
      'morado':  Colors.purple.shade600,
      'dorado':  const Color(0xFFFFB800),
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _handle(),
              Text(doc == null ? '➕ Nuevo banner' : '✏️ Editar banner',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              // Preview del banner
              _PreviewBanner(titulo: tituloCtrl.text, subtitulo: subCtrl.text,
                  emoji: emoji, color: colores[color]!),
              const SizedBox(height: 14),

              _campo(tituloCtrl, 'Título del banner *', Icons.title,
                  onChanged: (_) => setM(() {})),
              const SizedBox(height: 10),
              _campo(subCtrl, 'Subtítulo (ej: Solo este fin de semana)',
                  Icons.subtitles, onChanged: (_) => setM(() {})),
              const SizedBox(height: 10),

              // Selector emoji
              const Text('Emoji:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: emojis.map((e) => GestureDetector(
                onTap: () => setM(() => emoji = e),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: emoji == e
                        ? const Color(0xFFFF6B00).withValues(alpha: 0.2)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: emoji == e
                        ? const Color(0xFFFF6B00) : Colors.white12),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList()),
              const SizedBox(height: 12),

              // Selector color
              const Text('Color:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: colores.entries.map((e) => GestureDetector(
                onTap: () => setM(() => color = e.key),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color == e.key ? Colors.white : Colors.transparent,
                        width: 3),
                  ),
                ),
              )).toList()),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _campo(ordenCtrl, 'Orden', Icons.sort,
                    tipo: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: SwitchListTile(
                  value: activo,
                  onChanged: (v) => setM(() => activo = v),
                  title: const Text('Activo',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  activeColor: const Color(0xFFFF6B00),
                  contentPadding: EdgeInsets.zero,
                )),
              ]),
              const SizedBox(height: 10),

              // Fechas
              Row(children: [
                Expanded(child: _selectorFecha(ctx, 'Inicio', inicio,
                    (d) => setM(() => inicio = d))),
                const SizedBox(width: 10),
                Expanded(child: _selectorFecha(ctx, 'Fin', fin,
                    (d) => setM(() => fin = d))),
              ]),
              const SizedBox(height: 16),

              _botonesGuardar(ctx, doc, () async {
                if (tituloCtrl.text.trim().isEmpty) return;
                final payload = {
                  'titulo':    tituloCtrl.text.trim(),
                  'subtitulo': subCtrl.text.trim(),
                  'emoji':     emoji,
                  'color':     color,
                  'orden':     int.tryParse(ordenCtrl.text) ?? 1,
                  'activo':    activo,
                  'inicio':    inicio != null ? Timestamp.fromDate(inicio!) : null,
                  'fin':       fin != null ? Timestamp.fromDate(fin!) : null,
                  'tipo':      'banner',
                };
                doc == null
                    ? await _db.collection('promociones').add(payload)
                    : await doc.reference.update(payload);
                if (ctx.mounted) Navigator.pop(ctx);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Formulario Combo ──────────────────────────────────────
  void _mostrarFormCombo({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final descCtrl   = TextEditingController(text: data?['descripcion'] ?? '');
    final precioCtrl = TextEditingController(text: data?['precio']?.toString() ?? '');
    final anteriorCtrl = TextEditingController(text: data?['precioAnterior']?.toString() ?? '');
    final emojiCtrl  = TextEditingController(text: data?['emoji'] ?? '🍕');
    bool  activo     = data?['activo'] ?? true;
    bool  destacado  = data?['destacado'] ?? false;
    DateTime? inicio = (data?['inicio'] as Timestamp?)?.toDate();
    DateTime? fin    = (data?['fin'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _handle(),
              Text(doc == null ? '➕ Nuevo combo' : '✏️ Editar combo',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: _campo(emojiCtrl, 'Emoji', Icons.emoji_emotions)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _campo(nombreCtrl, 'Nombre del combo *', Icons.fastfood)),
              ]),
              const SizedBox(height: 10),
              _campo(descCtrl, 'Descripción (qué incluye)', Icons.list_alt),
              const SizedBox(height: 10),

              Row(children: [
                Expanded(child: _campo(precioCtrl, 'Precio oferta *',
                    Icons.attach_money, tipo: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _campo(anteriorCtrl, 'Precio anterior',
                    Icons.money_off, tipo: TextInputType.number)),
              ]),
              const SizedBox(height: 10),

              Row(children: [
                Expanded(child: SwitchListTile(
                  value: activo,
                  onChanged: (v) => setM(() => activo = v),
                  title: const Text('Activo',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  activeColor: const Color(0xFFFF6B00),
                  contentPadding: EdgeInsets.zero,
                )),
                Expanded(child: SwitchListTile(
                  value: destacado,
                  onChanged: (v) => setM(() => destacado = v),
                  title: const Text('⭐ Destacado',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  activeColor: Colors.amber,
                  contentPadding: EdgeInsets.zero,
                )),
              ]),
              const SizedBox(height: 10),

              Row(children: [
                Expanded(child: _selectorFecha(ctx, 'Inicio', inicio,
                    (d) => setM(() => inicio = d))),
                const SizedBox(width: 10),
                Expanded(child: _selectorFecha(ctx, 'Fin', fin,
                    (d) => setM(() => fin = d))),
              ]),
              const SizedBox(height: 16),

              _botonesGuardar(ctx, doc, () async {
                if (nombreCtrl.text.trim().isEmpty || precioCtrl.text.isEmpty) return;
                final payload = {
                  'nombre':         nombreCtrl.text.trim(),
                  'descripcion':    descCtrl.text.trim(),
                  'emoji':          emojiCtrl.text.trim().isEmpty ? '🍕' : emojiCtrl.text.trim(),
                  'precio':         double.tryParse(precioCtrl.text) ?? 0.0,
                  'precioAnterior': double.tryParse(anteriorCtrl.text),
                  'activo':         activo,
                  'destacado':      destacado,
                  'inicio':         inicio != null ? Timestamp.fromDate(inicio!) : null,
                  'fin':            fin != null ? Timestamp.fromDate(fin!) : null,
                  'tipo':           'combo',
                };
                doc == null
                    ? await _db.collection('promociones').add(payload)
                    : await doc.reference.update(payload);
                if (ctx.mounted) Navigator.pop(ctx);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  Widget _handle() => Center(child: Container(
    width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: Colors.white12,
        borderRadius: BorderRadius.circular(2)),
  ));

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {TextInputType tipo = TextInputType.text, void Function(String)? onChanged}) =>
    TextField(
      controller: ctrl, keyboardType: tipo,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true, fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5)),
      ),
    );

  Widget _selectorFecha(BuildContext ctx, String label, DateTime? fecha,
      void Function(DateTime) onSelect) =>
    GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx,
          initialDate: fecha ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Color(0xFFFF6B00))),
            child: child!),
        );
        if (d != null) onSelect(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12)),
        child: Row(children: [
          const Icon(Icons.calendar_today, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            fecha != null
                ? '$label: ${fecha.day}/${fecha.month}/${fecha.year}'
                : label,
            style: TextStyle(color: fecha != null ? Colors.white70 : Colors.white38,
                fontSize: 12),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );

  Widget _botonesGuardar(BuildContext ctx, DocumentSnapshot? doc,
      Future<void> Function() onGuardar) =>
    Row(children: [
      Expanded(child: OutlinedButton(
        onPressed: () => Navigator.pop(ctx),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white38,
            side: const BorderSide(color: Colors.white12),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text('Cancelar'),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: ElevatedButton(
        onPressed: onGuardar,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: Text(doc == null ? 'CREAR' : 'GUARDAR',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]);
}

// ── Tab Banners ───────────────────────────────────────────────
class _TabBanners extends StatelessWidget {
  final FirebaseFirestore db;
  final void Function({DocumentSnapshot? doc}) onEditar;
  const _TabBanners({required this.db, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('promociones')
          .where('tipo', isEqualTo: 'banner')
          .orderBy('orden')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B00)));

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _vacio('No hay banners activos',
            'Crea banners que aparecen en el menú del cliente');

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d       = docs[i].data() as Map<String, dynamic>;
            final activo  = d['activo'] as bool? ?? true;
            final titulo  = d['titulo'] as String? ?? '';
            final sub     = d['subtitulo'] as String? ?? '';
            final emoji   = d['emoji'] as String? ?? '🔥';
            final color   = d['color'] as String? ?? 'naranja';
            final fin     = (d['fin'] as Timestamp?)?.toDate();
            final expirado = fin != null && fin.isBefore(DateTime.now());

            final colorMap = {
              'naranja': const Color(0xFFFF6B00),
              'rojo':    Colors.red.shade600,
              'verde':   Colors.green.shade600,
              'azul':    Colors.blue.shade600,
              'morado':  Colors.purple.shade600,
              'dorado':  const Color(0xFFFFB800),
            };
            final c = colorMap[color] ?? const Color(0xFFFF6B00);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (activo && !expirado)
                    ? c.withValues(alpha: 0.4) : Colors.white12),
              ),
              child: Column(children: [
                // Preview miniatura
                if (activo && !expirado)
                  _PreviewBanner(titulo: titulo, subtitulo: sub, emoji: emoji, color: c),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(emoji,
                        style: const TextStyle(fontSize: 22))),
                  ),
                  title: Row(children: [
                    Text(titulo, style: TextStyle(
                        color: (activo && !expirado) ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (expirado) _chip('EXPIRADO', Colors.red)
                    else if (!activo) _chip('INACTIVO', Colors.grey),
                  ]),
                  subtitle: sub.isNotEmpty
                      ? Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 12))
                      : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 20),
                      onPressed: () => onEditar(doc: docs[i]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmarEliminar(context, docs[i]),
                    ),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminar(BuildContext context, DocumentSnapshot doc) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('¿Eliminar banner?',
          style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
        TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(context); },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// ── Tab Combos ────────────────────────────────────────────────
class _TabCombos extends StatelessWidget {
  final FirebaseFirestore db;
  final void Function({DocumentSnapshot? doc}) onEditar;
  const _TabCombos({required this.db, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('promociones')
          .where('tipo', isEqualTo: 'combo')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B00)));

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _vacio('No hay combos',
            'Crea combos y ofertas especiales para tus clientes');

        // Destacados primero
        final sorted = [...docs]..sort((a, b) {
          final ad = (a.data() as Map)['destacado'] as bool? ?? false;
          final bd = (b.data() as Map)['destacado'] as bool? ?? false;
          return bd ? 1 : (ad ? -1 : 0);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final d          = sorted[i].data() as Map<String, dynamic>;
            final activo     = d['activo'] as bool? ?? true;
            final destacado  = d['destacado'] as bool? ?? false;
            final nombre     = d['nombre'] as String? ?? '';
            final desc       = d['descripcion'] as String? ?? '';
            final emoji      = d['emoji'] as String? ?? '🍕';
            final precio     = (d['precio'] as num?)?.toDouble() ?? 0;
            final anterior   = (d['precioAnterior'] as num?)?.toDouble();
            final fin        = (d['fin'] as Timestamp?)?.toDate();
            final expirado   = fin != null && fin.isBefore(DateTime.now());
            final descuento  = anterior != null && anterior > 0
                ? ((1 - precio / anterior) * 100).round()
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: destacado
                      ? Colors.amber.withValues(alpha: 0.5)
                      : (activo && !expirado)
                          ? const Color(0xFFFF6B00).withValues(alpha: 0.3)
                          : Colors.white12,
                ),
              ),
              child: Row(children: [
                // Emoji grande
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: destacado
                        ? Colors.amber.withValues(alpha: 0.15)
                        : const Color(0xFFFF6B00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(emoji,
                      style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (destacado) const Text('⭐ ', style: TextStyle(fontSize: 12)),
                    Expanded(child: Text(nombre, style: TextStyle(
                        color: (activo && !expirado) ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold, fontSize: 15))),
                  ]),
                  if (desc.isNotEmpty)
                    Text(desc, style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('\$${precio.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFFFF6B00),
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    if (anterior != null) ...[
                      const SizedBox(width: 8),
                      Text('\$${anterior.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 13,
                              decoration: TextDecoration.lineThrough)),
                    ],
                    if (descuento != null) ...[
                      const SizedBox(width: 6),
                      _chip('-$descuento%', Colors.green),
                    ],
                    const Spacer(),
                    if (expirado) _chip('EXPIRADO', Colors.red)
                    else if (!activo) _chip('INACTIVO', Colors.grey),
                  ]),
                ])),

                // Acciones
                Column(children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white38, size: 20),
                    onPressed: () => onEditar(doc: sorted[i]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _confirmarEliminar(context, sorted[i]),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminar(BuildContext context, DocumentSnapshot doc) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('¿Eliminar combo?',
          style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
        TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(context); },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// ── Preview Banner ────────────────────────────────────────────
class _PreviewBanner extends StatelessWidget {
  final String titulo, subtitulo, emoji;
  final Color color;
  const _PreviewBanner({required this.titulo, required this.subtitulo,
      required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo.isEmpty ? 'Título del banner' : titulo,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 16)),
          if (subtitulo.isNotEmpty)
            Text(subtitulo, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ── Helpers globales ──────────────────────────────────────────
Widget _vacio(String titulo, String sub) => Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🔥', style: TextStyle(fontSize: 60)),
    const SizedBox(height: 14),
    Text(titulo, style: const TextStyle(color: Colors.white38,
        fontSize: 17, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Text(sub, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white24, fontSize: 13)),
  ]),
);

Widget _chip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4)),
  child: Text(label, style: TextStyle(color: color,
      fontSize: 9, fontWeight: FontWeight.bold)),
);
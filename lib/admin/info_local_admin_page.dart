import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
// InfoLocalAdminPage — El admin configura:
//   • Información del local (nombre, dirección, teléfono, horarios)
//   • Bancos para transferencias (varios, cada uno con nombre, titular,
//     número de cuenta, tipo de cuenta, identificación)
// Firestore: colección 'config_local' doc 'info'
//            colección 'config_bancos' (múltiples docs, uno por banco)
// ══════════════════════════════════════════════════════════════════════════════

const _kPurple  = Color(0xFF7C3AED);
const _kPurple2 = Color(0xFF581C87);
const _kBg      = Color(0xFF0F172A);
const _kCard    = Color(0xFF1E293B);
const _kCard2   = Color(0xFF263348);

class InfoLocalAdminPage extends StatefulWidget {
  const InfoLocalAdminPage({super.key});
  @override
  State<InfoLocalAdminPage> createState() => _InfoLocalAdminPageState();
}

class _InfoLocalAdminPageState extends State<InfoLocalAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Row(children: [
          Text('🏪', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Información del Local',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kPurple,
          indicatorWeight: 3,
          labelColor: _kPurple,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '🏪 Local'),
            Tab(text: '🏦 Bancos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabInfoLocal(db: _db),
          _TabBancos(db: _db),
        ],
      ),
    );
  }
}

// ── Tab Info Local ────────────────────────────────────────────────────────────
class _TabInfoLocal extends StatefulWidget {
  final FirebaseFirestore db;
  const _TabInfoLocal({required this.db});
  @override
  State<_TabInfoLocal> createState() => _TabInfoLocalState();
}

class _TabInfoLocalState extends State<_TabInfoLocal> {
  final _nombreCtrl    = TextEditingController();
  final _dirCtrl       = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _horarioCtrl   = TextEditingController();
  final _slogan        = TextEditingController();
  bool  _guardando     = false;
  bool  _cargado       = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _dirCtrl, _telefonoCtrl,
                     _emailCtrl, _horarioCtrl, _slogan]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final doc = await widget.db.collection('config_local').doc('info').get();
      if (doc.exists) {
        final d = doc.data()!;
        _nombreCtrl.text   = d['nombre']   ?? '';
        _dirCtrl.text      = d['direccion'] ?? '';
        _telefonoCtrl.text = d['telefono']  ?? '';
        _emailCtrl.text    = d['email']     ?? '';
        _horarioCtrl.text  = d['horario']   ?? '';
        _slogan.text       = d['slogan']    ?? '';
      }
      setState(() => _cargado = true);
    } catch (_) {
      setState(() => _cargado = true);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.db.collection('config_local').doc('info').set({
        'nombre':    _nombreCtrl.text.trim(),
        'direccion': _dirCtrl.text.trim(),
        'telefono':  _telefonoCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'horario':   _horarioCtrl.text.trim(),
        'slogan':    _slogan.text.trim(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Información guardada'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) return const Center(
        child: CircularProgressIndicator(color: _kPurple));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _Sec('Datos del negocio', Column(children: [
          _Campo(_nombreCtrl,   'Nombre del local *', Icons.store_outlined),
          const SizedBox(height: 12),
          _Campo(_slogan,       'Eslogan / tagline', Icons.format_quote_outlined),
          const SizedBox(height: 12),
          _Campo(_dirCtrl,      'Dirección', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _Campo(_telefonoCtrl, 'Teléfono / WhatsApp', Icons.phone_outlined,
              tipo: TextInputType.phone),
          const SizedBox(height: 12),
          _Campo(_emailCtrl,    'Correo electrónico', Icons.email_outlined,
              tipo: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _Campo(_horarioCtrl,  'Horario de atención',
              Icons.schedule_outlined, maxLines: 3),
        ])),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_guardando ? 'Guardando...' : 'Guardar cambios',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Tab Bancos ────────────────────────────────────────────────────────────────
class _TabBancos extends StatelessWidget {
  final FirebaseFirestore db;
  const _TabBancos({required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogo(context, null, null),
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar banco'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('config_bancos')
            .orderBy('orden', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kPurple));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🏦', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              const Text('No hay bancos registrados',
                  style: TextStyle(color: Colors.white38, fontSize: 15)),
              const SizedBox(height: 8),
              Text('Toca ➕ para agregar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc  = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _TarjetaBanco(
                data: data, docId: doc.id,
                onEditar: () => _dialogo(context, doc.id, data),
                onEliminar: () => _confirmarEliminar(context, doc.id,
                    data['nombre'] ?? 'este banco'),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _dialogo(BuildContext ctx, String? docId,
      Map<String, dynamic>? data) async {
    final nombreCtrl    = TextEditingController(text: data?['nombre'] ?? '');
    final titularCtrl   = TextEditingController(text: data?['titular'] ?? '');
    final cuentaCtrl    = TextEditingController(text: data?['numeroCuenta'] ?? '');
    final tipoCuentaCtrl = TextEditingController(text: data?['tipoCuenta'] ?? 'Corriente');
    final idCtrl        = TextEditingController(text: data?['identificacion'] ?? '');
    final emailCtrl     = TextEditingController(text: data?['email'] ?? '');
    final ordenCtrl     = TextEditingController(
        text: (data?['orden'] ?? 1).toString());
    bool activo = data?['activo'] ?? true;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setSt) => Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx2).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2)),
              )),
              Text(docId == null ? '🏦 Agregar banco' : '✏️ Editar banco',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 20),
              _Campo(nombreCtrl, 'Nombre del banco *', Icons.account_balance),
              const SizedBox(height: 10),
              _Campo(titularCtrl, 'Titular de la cuenta *', Icons.person_outline),
              const SizedBox(height: 10),
              _Campo(cuentaCtrl, 'Número de cuenta *', Icons.credit_card_outlined,
                  tipo: TextInputType.number),
              const SizedBox(height: 10),
              _CampoDropdown(
                label: 'Tipo de cuenta',
                valor: tipoCuentaCtrl.text,
                opciones: const ['Corriente', 'Ahorros', 'Nómina'],
                onChanged: (v) => tipoCuentaCtrl.text = v ?? 'Corriente',
              ),
              const SizedBox(height: 10),
              _Campo(idCtrl, 'Cédula/RUC del titular', Icons.badge_outlined,
                  tipo: TextInputType.number),
              const SizedBox(height: 10),
              _Campo(emailCtrl, 'Email (opcional)', Icons.email_outlined,
                  tipo: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _Campo(ordenCtrl, 'Orden de aparición', Icons.sort,
                  tipo: TextInputType.number),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Banco activo',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: activo,
                  onChanged: (v) => setSt(() => activo = v),
                  activeColor: _kPurple,
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx2),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white38,
                      side: const BorderSide(color: Colors.white12),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancelar'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    final nombre  = nombreCtrl.text.trim();
                    final titular = titularCtrl.text.trim();
                    final cuenta  = cuentaCtrl.text.trim();
                    if (nombre.isEmpty || titular.isEmpty || cuenta.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Nombre, titular y cuenta son obligatorios'),
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    final payload = {
                      'nombre':         nombre,
                      'titular':        titular,
                      'numeroCuenta':   cuenta,
                      'tipoCuenta':     tipoCuentaCtrl.text,
                      'identificacion': idCtrl.text.trim(),
                      'email':          emailCtrl.text.trim(),
                      'orden':          int.tryParse(ordenCtrl.text) ?? 1,
                      'activo':         activo,
                      'actualizadoEn':  FieldValue.serverTimestamp(),
                    };
                    if (docId == null) {
                      await db.collection('config_bancos').add(payload);
                    } else {
                      await db.collection('config_bancos')
                          .doc(docId).update(payload);
                    }
                    if (ctx2.mounted) Navigator.pop(ctx2);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white, elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(docId == null ? 'Agregar' : 'Guardar',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ],
          )),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext ctx, String docId,
      String nombre) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar banco?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Se eliminará "$nombre" de las opciones de transferencia.',
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                  foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await db.collection('config_bancos').doc(docId).delete();
  }
}

// ── Tarjeta de banco ──────────────────────────────────────────────────────────
class _TarjetaBanco extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onEditar, onEliminar;
  const _TarjetaBanco({required this.data, required this.docId,
      required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final activo  = data['activo'] ?? true;
    final nombre  = data['nombre']  ?? 'Banco';
    final titular = data['titular'] ?? '';
    final cuenta  = data['numeroCuenta'] ?? '';
    final tipo    = data['tipoCuenta'] ?? 'Corriente';
    final id      = data['identificacion'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: activo
                ? _kPurple.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: activo
                ? _kPurple.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: activo
                    ? _kPurple.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(
                _emojisBanco(nombre),
                style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
              Text(tipo, style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activo
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                      color: activo ? Colors.green : Colors.red,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Datos
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(children: [
            _Fila('👤 Titular', titular),
            _Fila('💳 Cuenta', cuenta),
            if (id.isNotEmpty) _Fila('🪪 ID/RUC', id),
          ]),
        ),

        // Acciones
        Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(children: [
            Expanded(child: TextButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 15,
                  color: _kPurple),
              label: const Text('Editar',
                  style: TextStyle(color: _kPurple, fontSize: 12)),
            )),
            Container(width: 1, height: 30,
                color: Colors.white.withValues(alpha: 0.06)),
            Expanded(child: TextButton.icon(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline, size: 15,
                  color: Colors.red),
              label: const Text('Eliminar',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            )),
          ]),
        ),
      ]),
    );
  }

  String _emojisBanco(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('pichincha'))  return '🏦';
    if (n.contains('guayaquil'))  return '🏙️';
    if (n.contains('pacific'))    return '🌊';
    if (n.contains('produbanco')) return '💼';
    if (n.contains('internacional')) return '🌐';
    if (n.contains('austro'))     return '🏔️';
    if (n.contains('bolivariano')) return '💛';
    if (n.contains('cooperativa') || n.contains('coac')) return '🤝';
    return '🏦';
  }

  Widget _Fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(child: Text(valor,
          style: const TextStyle(color: Colors.white70, fontSize: 12,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.right)),
    ]),
  );
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Sec(this.titulo, this.child);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType tipo;
  final int maxLines;

  const _Campo(this.ctrl, this.label, this.icon, {
    this.tipo = TextInputType.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: _kPurple, size: 18),
      filled: true, fillColor: _kCard2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPurple, width: 1.5)),
    ),
  );
}

class _CampoDropdown extends StatefulWidget {
  final String label, valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;
  const _CampoDropdown({required this.label, required this.valor,
      required this.opciones, required this.onChanged});

  @override
  State<_CampoDropdown> createState() => _CampoDropdownState();
}

class _CampoDropdownState extends State<_CampoDropdown> {
  late String _val;
  @override
  void initState() {
    super.initState();
    _val = widget.opciones.contains(widget.valor)
        ? widget.valor : widget.opciones.first;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        color: _kCard2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _val,
        dropdownColor: _kCard,
        isExpanded: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: widget.opciones.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o))).toList(),
        onChanged: (v) {
          setState(() => _val = v ?? widget.opciones.first);
          widget.onChanged(v);
        },
      ),
    ),
  );
}
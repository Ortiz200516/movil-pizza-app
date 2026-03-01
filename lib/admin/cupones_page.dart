import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CuponesPage extends StatefulWidget {
  const CuponesPage({super.key});
  @override
  State<CuponesPage> createState() => _CuponesPageState();
}

class _CuponesPageState extends State<CuponesPage> {
  final _db = FirebaseFirestore.instance;

  void _mostrarFormulario({DocumentSnapshot? doc}) {
    final data   = doc?.data() as Map<String, dynamic>?;
    final codigoCtrl = TextEditingController(text: data?['codigo'] ?? '');
    final descCtrl   = TextEditingController(text: data?['descripcion'] ?? '');
    final valorCtrl  = TextEditingController(
        text: data?['descuento']?.toString() ?? '10');
    String tipo    = data?['tipo'] ?? 'porcentaje';
    bool   activo  = data?['activo'] ?? true;
    DateTime? expira = (data?['expira'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white12,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(doc == null ? '➕ Nuevo cupón' : '✏️ Editar cupón',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: codigoCtrl,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (codigoCtrl.text != upper) {
                  codigoCtrl.value = codigoCtrl.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
              decoration: InputDecoration(
                labelText: 'Código (ej: PIZZA10)',
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.local_offer, color: Colors.white38, size: 18),
                filled: true, fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5)),
              ),
            ),
            const SizedBox(height: 10),
            _campo(descCtrl, 'Descripción', Icons.description),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _campo(valorCtrl, 'Descuento',
                  Icons.percent, TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: tipo,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'porcentaje',
                          child: Text('%  Porcentaje')),
                      DropdownMenuItem(value: 'fijo',
                          child: Text('\$  Fijo')),
                    ],
                    onChanged: (v) => setM(() => tipo = v!),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 10),

            // Fecha expiración
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: expira ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (_, child) => Theme(
                    data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFFF6B00))),
                    child: child!),
                );
                if (d != null) setM(() => expira = d);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12)),
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    expira != null
                        ? 'Expira: ${expira!.day}/${expira!.month}/${expira!.year}'
                        : 'Sin fecha de expiración',
                    style: TextStyle(color: expira != null
                        ? Colors.white70 : Colors.white38)),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              value: activo,
              onChanged: (v) => setM(() => activo = v),
              title: const Text('Cupón activo',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              activeColor: const Color(0xFFFF6B00),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white38,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancelar'),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: () async {
                  final codigo = codigoCtrl.text.trim().toUpperCase();
                  if (codigo.isEmpty) return;
                  final payload = {
                    'codigo':      codigo,
                    'descripcion': descCtrl.text.trim(),
                    'descuento':   double.tryParse(valorCtrl.text) ?? 10.0,
                    'tipo':        tipo,
                    'activo':      activo,
                    'expira':      expira != null
                        ? Timestamp.fromDate(expira!) : null,
                  };
                  if (doc == null) {
                    await _db.collection('cupones').add(payload);
                  } else {
                    await doc.reference.update(payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(doc == null ? 'CREAR' : 'GUARDAR',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      [TextInputType tipo = TextInputType.text]) =>
    TextField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true, fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFFFF6B00), width: 1.5)),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('🎟️ Cupones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _mostrarFormulario(),
            tooltip: 'Nuevo cupón',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cupón',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('cupones')
            .orderBy('activo', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B00)));

          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🎟️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 14),
            const Text('No hay cupones',
                style: TextStyle(color: Colors.white38,
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _mostrarFormulario(),
              child: const Text('Crear primer cupón →',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ]));

          final now = DateTime.now();
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d      = docs[i].data() as Map<String, dynamic>;
              final activo = d['activo'] as bool? ?? true;
              final tipo   = d['tipo'] as String? ?? 'porcentaje';
              final valor  = (d['descuento'] as num?)?.toDouble() ?? 0.0;
              final exp    = (d['expira'] as Timestamp?)?.toDate();
              final expirado = exp != null && exp.isBefore(now);
              final label  = tipo == 'porcentaje'
                  ? '${valor.toStringAsFixed(0)}% OFF'
                  : '\$${valor.toStringAsFixed(2)} OFF';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (activo && !expirado)
                        ? const Color(0xFFFF6B00).withOpacity(0.4)
                        : Colors.white12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  leading: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: (activo && !expirado)
                          ? const Color(0xFFFF6B00).withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: (activo && !expirado)
                              ? const Color(0xFFFF6B00) : Colors.white24,
                          fontWeight: FontWeight.w900,
                          fontSize: 11))),
                  ),
                  title: Row(children: [
                    Text(d['codigo'] ?? '',
                        style: TextStyle(
                            color: (activo && !expirado)
                                ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 15, letterSpacing: 1.5)),
                    const SizedBox(width: 8),
                    if (expirado)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('EXPIRADO',
                            style: TextStyle(color: Colors.red,
                                fontSize: 9, fontWeight: FontWeight.bold)),
                      )
                    else if (!activo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('INACTIVO',
                            style: TextStyle(color: Colors.grey,
                                fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if ((d['descripcion'] ?? '').isNotEmpty)
                      Text(d['descripcion'],
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    if (exp != null)
                      Text('Expira: ${exp.day}/${exp.month}/${exp.year}',
                          style: TextStyle(
                              color: expirado ? Colors.red : Colors.white24,
                              fontSize: 11)),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white38, size: 20),
                      onPressed: () => _mostrarFormulario(doc: docs[i]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text('¿Eliminar cupón?',
                                style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await docs[i].reference.delete();
                      },
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
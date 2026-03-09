import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResenasPage extends StatefulWidget {
  const ResenasPage({super.key});
  @override
  State<ResenasPage> createState() => _ResenasPageState();
}

class _ResenasPageState extends State<ResenasPage> {
  final _db = FirebaseFirestore.instance;
  int _filtroEstrellas = 0; // 0 = todas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('⭐ Reseñas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // ── Resumen general ──────────────────────────────
        _ResumenGeneral(db: _db),

        // ── Filtros por estrellas ────────────────────────
        Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FiltroChip(
                label: 'Todas',
                selected: _filtroEstrellas == 0,
                onTap: () => setState(() => _filtroEstrellas = 0),
              ),
              ...List.generate(5, (i) => _FiltroChip(
                label: '${'⭐' * (5 - i)}',
                selected: _filtroEstrellas == 5 - i,
                onTap: () => setState(() => _filtroEstrellas = 5 - i),
              )),
            ]),
          ),
        ),

        // ── Lista de reseñas ─────────────────────────────
        Expanded(child: _ListaResenas(db: _db, filtro: _filtroEstrellas)),
      ]),
    );
  }
}

// ── Resumen con promedio y barras ─────────────────────────────────────────────
class _ResumenGeneral extends StatelessWidget {
  final FirebaseFirestore db;
  const _ResumenGeneral({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('calificaciones').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Aún no hay reseñas',
                  style: TextStyle(color: Colors.white38, fontSize: 15)),
            ),
          );
        }

        final docs = snap.data!.docs;
        final total = docs.length;
        final estrellasList = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['estrellas'] as num?)?.toInt() ?? 0;
        }).toList();

        final promedio = estrellasList.reduce((a, b) => a + b) / total;

        // Conteo por estrellas
        final conteo = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        for (final e in estrellasList) {
          conteo[e] = (conteo[e] ?? 0) + 1;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.2)),
          ),
          child: Row(children: [
            // Promedio grande
            Column(children: [
              Text(promedio.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const SizedBox(height: 4),
              _Estrellas(estrellas: promedio.round(), size: 16),
              const SizedBox(height: 4),
              Text('$total reseñas',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(width: 20),
            // Barras por estrella
            Expanded(
              child: Column(
                children: List.generate(5, (i) {
                  final n = 5 - i;
                  final c = conteo[n] ?? 0;
                  final pct = total > 0 ? c / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text('$n', style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Text('⭐', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: AlwaysStoppedAnimation(
                              n >= 4 ? const Color(0xFFFF6B00)
                                  : n == 3 ? Colors.amber
                                  : Colors.red.shade400,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text('$c',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            textAlign: TextAlign.right),
                      ),
                    ]),
                  );
                }),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Lista de reseñas ──────────────────────────────────────────────────────────
class _ListaResenas extends StatelessWidget {
  final FirebaseFirestore db;
  final int filtro;
  const _ListaResenas({required this.db, required this.filtro});

  @override
  Widget build(BuildContext context) {
    Query query = db.collection('calificaciones')
        .orderBy('fecha', descending: true);

    if (filtro > 0) {
      query = query.where('estrellas', isEqualTo: filtro);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(filtro > 0 ? '🔍' : '⭐',
                  style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 12),
              Text(
                filtro > 0
                    ? 'No hay reseñas de ${'⭐' * filtro}'
                    : 'Aún no hay reseñas',
                style: const TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ]),
          );
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _TarjetaResena(data: data);
          },
        );
      },
    );
  }
}

// ── Tarjeta individual de reseña ──────────────────────────────────────────────
class _TarjetaResena extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TarjetaResena({required this.data});

  @override
  Widget build(BuildContext context) {
    final estrellas  = (data['estrellas'] as num?)?.toInt() ?? 0;
    final comentario = data['comentario'] as String? ?? '';
    final aspectos   = data['aspectos'] as Map<String, dynamic>? ?? {};
    final fecha      = (data['fecha'] as Timestamp?)?.toDate();
    final clienteId  = data['clienteId'] as String? ?? '';

    final tiempoTexto = fecha != null ? _tiempoRelativo(fecha) : '';

    // Color según estrellas
    final color = estrellas >= 4
        ? const Color(0xFFFF6B00)
        : estrellas == 3 ? Colors.amber : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: usuario + estrellas + fecha ──────────
        Row(children: [
          // Avatar con inicial
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users').doc(clienteId).get(),
            builder: (_, snap) {
              final data = snap.hasData
                  ? (snap.data!.data() as Map<String, dynamic>?) ?? {}
                  : <String, dynamic>{};
              final nombre = (data['nombre'] as String?)
                  ?? (data['email'] as String?)
                  ?? 'Cliente';
              final inicial = nombre.isNotEmpty
                  ? nombre[0].toUpperCase() : 'C';
              final fotoUrl = data['fotoUrl'] as String?;

              return Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.2),
                  backgroundImage: fotoUrl != null
                      ? NetworkImage(fotoUrl) : null,
                  child: fotoUrl == null
                      ? Text(inicial, style: TextStyle(
                          color: color, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(nombre.split('@')[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(tiempoTexto,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ])),
              ]);
            },
          ),
          const Spacer(),
          _Estrellas(estrellas: estrellas, size: 14),
        ]),

        // ── Comentario ───────────────────────────────────
        if (comentario.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text('"$comentario"',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4)),
          ),
        ],

        // ── Aspectos ─────────────────────────────────────
        if (aspectos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6,
            children: aspectos.entries.map((e) {
              final emoji = _emojiAspecto(e.key);
              final val   = (e.value as num?)?.toInt() ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(_nombreAspecto(e.key),
                      style: TextStyle(color: color,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text('${'★' * val}',
                      style: TextStyle(color: color, fontSize: 9)),
                ]),
              );
            }).toList(),
          ),
        ],
      ]),
    );
  }

  String _tiempoRelativo(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24)   return 'hace ${diff.inHours}h';
    if (diff.inDays < 7)     return 'hace ${diff.inDays}d';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _emojiAspecto(String key) {
    switch (key) {
      case 'comida':       return '🍕';
      case 'rapidez':      return '⚡';
      case 'presentacion': return '✨';
      case 'atencion':     return '😊';
      default:             return '⭐';
    }
  }

  String _nombreAspecto(String key) {
    switch (key) {
      case 'comida':       return 'Comida';
      case 'rapidez':      return 'Rapidez';
      case 'presentacion': return 'Presentación';
      case 'atencion':     return 'Atención';
      default:             return key;
    }
  }
}

// ── Widget de estrellas ───────────────────────────────────────────────────────
class _Estrellas extends StatelessWidget {
  final int estrellas;
  final double size;
  const _Estrellas({required this.estrellas, this.size = 16});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Text(
      i < estrellas ? '⭐' : '☆',
      style: TextStyle(fontSize: size),
    )),
  );
}

// ── Chip de filtro ────────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FiltroChip({required this.label, required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFF6B00).withOpacity(0.15)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF6B00)
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color: selected ? const Color(0xFFFF6B00) : Colors.white38,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
    ),
  );
}
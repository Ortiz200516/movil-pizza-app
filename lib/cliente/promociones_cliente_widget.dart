import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Widget que se inserta al inicio de menu_page.dart ─────────
class PromocionesWidget extends StatelessWidget {
  const PromocionesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promociones')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final fin = (data['fin'] as Timestamp?)?.toDate();
          final inicio = (data['inicio'] as Timestamp?)?.toDate();
          if (fin != null && fin.isBefore(now)) return false;
          if (inicio != null && inicio.isAfter(now)) return false;
          return true;
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        final banners = docs.where((d) =>
            (d.data() as Map)['tipo'] == 'banner').toList()
          ..sort((a, b) {
            final ao = ((a.data() as Map)['orden'] as int?) ?? 99;
            final bo = ((b.data() as Map)['orden'] as int?) ?? 99;
            return ao.compareTo(bo);
          });

        final combos = docs.where((d) =>
            (d.data() as Map)['tipo'] == 'combo').toList()
          ..sort((a, b) {
            final ad = ((a.data() as Map)['destacado'] as bool?) ?? false;
            final bd = ((b.data() as Map)['destacado'] as bool?) ?? false;
            return bd ? 1 : (ad ? -1 : 0);
          });

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Banners ────────────────────────────────────────
          if (banners.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: PageView.builder(
                itemCount: banners.length,
                controller: PageController(viewportFraction: 0.92),
                itemBuilder: (_, i) {
                  final d     = banners[i].data() as Map<String, dynamic>;
                  final titulo = d['titulo'] as String? ?? '';
                  final sub    = d['subtitulo'] as String? ?? '';
                  final emoji  = d['emoji'] as String? ?? '🔥';
                  final color  = _colorDesdeNombre(d['color'] as String? ?? 'naranja');
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Text(emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(titulo, style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900, fontSize: 15),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (sub.isNotEmpty)
                          Text(sub, style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Combos ─────────────────────────────────────────
          if (combos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Text('🔥', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('Ofertas especiales',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: combos.length,
                itemBuilder: (_, i) {
                  final d         = combos[i].data() as Map<String, dynamic>;
                  final nombre    = d['nombre'] as String? ?? '';
                  final desc      = d['descripcion'] as String? ?? '';
                  final emoji     = d['emoji'] as String? ?? '🍕';
                  final precio    = (d['precio'] as num?)?.toDouble() ?? 0;
                  final anterior  = (d['precioAnterior'] as num?)?.toDouble();
                  final destacado = d['destacado'] as bool? ?? false;
                  final descuento = anterior != null && anterior > 0
                      ? ((1 - precio / anterior) * 100).round()
                      : null;

                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: destacado
                            ? Colors.amber.withOpacity(0.5)
                            : const Color(0xFFFF6B00).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const Spacer(),
                        if (descuento != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('-$descuento%',
                                style: const TextStyle(color: Colors.green,
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      Text(nombre,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (desc.isNotEmpty)
                        Text(desc,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Text('\$${precio.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFFF6B00),
                                fontWeight: FontWeight.w900, fontSize: 15)),
                        if (anterior != null) ...[
                          const SizedBox(width: 6),
                          Text('\$${anterior.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white24,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ]),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
        ]);
      },
    );
  }

  Color _colorDesdeNombre(String nombre) {
    switch (nombre) {
      case 'rojo':   return Colors.red.shade600;
      case 'verde':  return Colors.green.shade600;
      case 'azul':   return Colors.blue.shade600;
      case 'morado': return Colors.purple.shade600;
      case 'dorado': return const Color(0xFFFFB800);
      default:       return const Color(0xFFFF6B00);
    }
  }
}
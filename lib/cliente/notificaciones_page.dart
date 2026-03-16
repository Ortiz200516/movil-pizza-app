import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificacionesPage extends StatelessWidget {
  const NotificacionesPage({super.key});

  String _formatFecha(Timestamp? ts) {
    if (ts == null) return '';
    final f = ts.toDate();
    final ahora = DateTime.now();
    final diff = ahora.difference(f);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'pedido':     return Colors.orange;
      case 'preparando': return Colors.blue;
      case 'listo':      return Colors.teal;
      case 'camino':     return Colors.indigo;
      case 'entregado':  return Colors.green;
      case 'cancelado':  return Colors.red;
      default:           return Colors.blueGrey;
    }
  }

  String _emojiTipo(String tipo) {
    switch (tipo) {
      case 'pedido':     return '🍕';
      case 'preparando': return '👨‍🍳';
      case 'listo':      return '✅';
      case 'camino':     return '🛵';
      case 'entregado':  return '📦';
      case 'cancelado':  return '❌';
      default:           return '🔔';
    }
  }

  Future<void> _marcarLeida(String docId) async {
    await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc(docId)
        .update({'leida': true});
  }

  Future<void> _marcarTodasLeidas(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('notificaciones')
        .where('uid', isEqualTo: uid)
        .where('leida', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      doc.reference.update({'leida': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: Text('No hay sesión activa',
            style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('🔔 Notificaciones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => _marcarTodasLeidas(user.uid),
            child: const Text('Leer todo',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notificaciones')
            .where('uid', isEqualTo: user.uid)
            .orderBy('creadoEn', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const Text('🔔', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                const Text('Sin notificaciones',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Aquí verás el estado de tus pedidos',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 13)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc  = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final tipo   = data['tipo'] as String? ?? 'info';
              final titulo = data['titulo'] as String? ?? '';
              final cuerpo = data['cuerpo'] as String? ?? '';
              final leida  = data['leida'] as bool? ?? false;
              final fecha  = data['creadoEn'] as Timestamp?;
              final color  = _colorTipo(tipo);

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red.withValues(alpha: 0.2),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red),
                ),
                onDismissed: (_) => doc.reference.delete(),
                child: GestureDetector(
                  onTap: () {
                    if (!leida) _marcarLeida(doc.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: leida
                          ? const Color(0xFF1E293B)
                          : color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: leida
                              ? Colors.white.withValues(alpha: 0.06)
                              : color.withValues(alpha: 0.3),
                          width: leida ? 1 : 1.5),
                    ),
                    child: Row(children: [
                      // Ícono
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                            child: Text(_emojiTipo(tipo),
                                style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),

                      // Contenido
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        Row(children: [
                          Expanded(
                              child: Text(titulo,
                                  style: TextStyle(
                                      color: leida
                                          ? Colors.white70
                                          : Colors.white,
                                      fontWeight: leida
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 13))),
                          Text(_formatFecha(fecha),
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11)),
                        ]),
                        if (cuerpo.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(cuerpo,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12)),
                        ],
                      ])),

                      // Indicador no leída
                      if (!leida) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                      ],
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
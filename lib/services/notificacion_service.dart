import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificacionService {
  static final NotificacionService _i = NotificacionService._();
  factory NotificacionService() => _i;
  NotificacionService._();

  final _fcm = FirebaseMessaging.instance;
  final _db  = FirebaseFirestore.instance;

  static void Function(String titulo, String cuerpo, {String? tipo})? onMensaje;

  Future<void> inicializar() async {
    try {
      final settings = await _fcm.requestPermission(
          alert: true, badge: true, sound: true);
      if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
      FirebaseMessaging.onMessage.listen(_manejarMensaje);
    } catch (_) {}
  }

  Future<void> guardarToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenActualizadoEn': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> notificarRol({
    required String rol,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    Map<String, dynamic>? datos,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'rol': rol, 'titulo': titulo, 'cuerpo': cuerpo,
        'tipo': tipo, 'datos': datos ?? {},
        'creadoEn': FieldValue.serverTimestamp(), 'leida': false,
      });
    } catch (_) {}
  }

  static Future<void> notificarUsuario({
    required String uid,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    Map<String, dynamic>? datos,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'uid': uid, 'titulo': titulo, 'cuerpo': cuerpo,
        'tipo': tipo, 'datos': datos ?? {},
        'creadoEn': FieldValue.serverTimestamp(), 'leida': false,
      });
    } catch (_) {}
  }

  void _manejarMensaje(RemoteMessage msg) {
    final titulo = msg.notification?.title ?? msg.data['titulo'] ?? '';
    final cuerpo = msg.notification?.body  ?? msg.data['cuerpo'] ?? '';
    onMensaje?.call(titulo, cuerpo, tipo: msg.data['tipo']);
  }
}

// ── Stream badge sin índice compuesto ─────────────────────────
Stream<int> streamNotificacionesSinLeer(String uid, String rol) {
  // Sin .where('leida') para evitar requerir índice compuesto.
  // Filtramos en memoria.
  return FirebaseFirestore.instance
      .collection('notificaciones')
      .orderBy('creadoEn', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.where((d) {
            final data = d.data();
            final leida = data['leida'] as bool? ?? false;
            if (leida) return false;
            return data['uid'] == uid || data['rol'] == rol;
          }).length);
}

// ── Banner de notificación ────────────────────────────────────
class NotificacionBanner extends StatefulWidget {
  final Widget child;
  const NotificacionBanner({super.key, required this.child});
  @override
  State<NotificacionBanner> createState() => _NotificacionBannerState();
}

class _NotificacionBannerState extends State<NotificacionBanner>
    with SingleTickerProviderStateMixin {
  String? _titulo;
  String? _cuerpo;
  String  _tipo = 'info';
  late AnimationController _ctrl;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    NotificacionService.onMensaje = (titulo, cuerpo, {tipo}) {
      if (!mounted) return;
      setState(() { _titulo = titulo; _cuerpo = cuerpo; _tipo = tipo ?? 'info'; });
      _ctrl.forward();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _ctrl.reverse().then((_) {
          if (mounted) setState(() { _titulo = null; _cuerpo = null; });
        });
        }
      });
    };
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _color {
    switch (_tipo) {
      case 'pedido':    return const Color(0xFFFF6B00);
      case 'listo':     return Colors.green.shade600;
      case 'camino':    return Colors.indigo.shade600;
      case 'preparando': return Colors.blue.shade600;
      case 'cancelado': return Colors.red.shade600;
      default:          return const Color(0xFF334155);
    }
  }

  String get _emoji {
    switch (_tipo) {
      case 'pedido':    return '🍕';
      case 'listo':     return '✅';
      case 'camino':    return '🛵';
      case 'preparando': return '👨‍🍳';
      case 'cancelado': return '❌';
      default:          return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_titulo != null)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SlideTransition(
            position: _slide,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: _color.withOpacity(0.4),
                  child: GestureDetector(
                    onTap: () => _ctrl.reverse().then((_) {
                      if (mounted) setState(() { _titulo = null; _cuerpo = null; });
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _color, _color.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text(_emoji,
                              style: const TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: [
                          Text(_titulo!, style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                          if (_cuerpo?.isNotEmpty == true)
                            Text(_cuerpo!, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12)),
                        ])),
                        Icon(Icons.close, color: Colors.white.withOpacity(0.6),
                            size: 16),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ── Badge de notificaciones con animación ─────────────────────
class NotifBadgeBtn extends StatefulWidget {
  final String uid, rol;
  const NotifBadgeBtn({super.key, required this.uid, required this.rol});
  @override
  State<NotifBadgeBtn> createState() => _NotifBadgeBtnState();
}

class _NotifBadgeBtnState extends State<NotifBadgeBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  final int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: streamNotificacionesSinLeer(widget.uid, widget.rol),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        // Detener pulso si no hay notifs
        if (count == 0) {
          _pulse.stop();
        } else if (!_pulse.isAnimating) {
          _pulse.repeat(reverse: true);
        }

        return Stack(children: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: count > 0 ? 1.0 + (_pulse.value * 0.08) : 1.0,
                child: child,
              ),
              child: Icon(
                count > 0 ? Icons.notifications : Icons.notifications_outlined,
                color: count > 0
                    ? const Color(0xFFFF6B00)
                    : Colors.white38,
                size: 24,
              ),
            ),
            onPressed: () => _mostrarNotificaciones(context),
          ),
          if (count > 0)
            Positioned(
              top: 6, right: 6,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: Colors.red.withOpacity(0.4 + _pulse.value * 0.3),
                        blurRadius: 6, spreadRadius: 1)],
                  ),
                  child: Center(child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 8, fontWeight: FontWeight.w900),
                  )),
                ),
              ),
            ),
        ]);
      },
    );
  }

  void _mostrarNotificaciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifSheet(uid: widget.uid, rol: widget.rol),
    );
  }
}

// ── Sheet de notificaciones ───────────────────────────────────
class _NotifSheet extends StatelessWidget {
  final String uid, rol;
  const _NotifSheet({required this.uid, required this.rol});

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'pedido':     return const Color(0xFFFF6B00);
      case 'listo':      return Colors.green;
      case 'camino':     return Colors.indigo;
      case 'preparando': return Colors.blue;
      case 'cancelado':  return Colors.red;
      default:           return Colors.blueGrey;
    }
  }

  String _emojiTipo(String tipo) {
    switch (tipo) {
      case 'pedido':     return '🍕';
      case 'listo':      return '✅';
      case 'camino':     return '🛵';
      case 'preparando': return '👨‍🍳';
      case 'cancelado':  return '❌';
      default:           return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white12,
                borderRadius: BorderRadius.circular(2)),
          )),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(children: [
              const Text('🔔', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text('Notificaciones', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _marcarTodasLeidas(uid, rol),
                icon: const Icon(Icons.done_all, size: 16, color: Colors.white38),
                label: const Text('Limpiar',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ]),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notificaciones')
                  .orderBy('creadoEn', descending: true)
                  .limit(40)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                }

                final docs = snap.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['uid'] == uid || data['rol'] == rol;
                }).toList();

                if (docs.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🔕', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 14),
                    const Text('Sin notificaciones',
                        style: TextStyle(color: Colors.white38,
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Aquí verás actualizaciones de tus pedidos',
                        style: TextStyle(color: Colors.white24, fontSize: 13)),
                  ]));
                }

                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d     = docs[i].data() as Map<String, dynamic>;
                    final leida = d['leida'] as bool? ?? false;
                    final tipo  = d['tipo'] as String? ?? 'info';
                    final color = _colorTipo(tipo);
                    final emoji = _emojiTipo(tipo);

                    // Formatear hora
                    String hora = '';
                    final ts = d['creadoEn'];
                    if (ts != null) {
                      try {
                        final dt = (ts as Timestamp).toDate();
                        final ahora = DateTime.now();
                        final diff  = ahora.difference(dt);
                        if (diff.inMinutes < 1) {
                          hora = 'Ahora';
                        } else if (diff.inHours < 1) {
                          hora = 'Hace ${diff.inMinutes}m';
                        } else if (diff.inHours < 24) {
                          hora = 'Hace ${diff.inHours}h';
                        } else {
                          hora = '${dt.day}/${dt.month}';
                        }
                      } catch (_) {}
                    }

                    return Dismissible(
                      key: Key(docs[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.withOpacity(0.2),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red),
                      ),
                      onDismissed: (_) => docs[i].reference.delete(),
                      child: InkWell(
                        onTap: () {
                          if (!leida) {
                            docs[i].reference.update({'leida': true});
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: leida
                                ? Colors.white.withOpacity(0.02)
                                : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: leida
                                  ? Colors.white.withOpacity(0.04)
                                  : color.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(emoji,
                                  style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['titulo'] ?? '', style: TextStyle(
                                  color: leida ? Colors.white38 : Colors.white,
                                  fontWeight: leida
                                      ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 13,
                                )),
                                if ((d['cuerpo'] ?? '').toString().isNotEmpty)
                                  Text(d['cuerpo'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: leida
                                              ? Colors.white24 : Colors.white54,
                                          fontSize: 12)),
                              ],
                            )),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(hora, style: const TextStyle(
                                    color: Colors.white24, fontSize: 10)),
                                if (!leida) ...[
                                  const SizedBox(height: 6),
                                  Container(width: 8, height: 8,
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle)),
                                ],
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _marcarTodasLeidas(String uid, String rol) async {
    final snap = await FirebaseFirestore.instance
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true)
        .limit(50)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      final d = doc.data();
      if ((d['uid'] == uid || d['rol'] == rol) &&
          !(d['leida'] as bool? ?? false)) {
        batch.update(doc.reference, {'leida': true});
      }
    }
    await batch.commit();
  }
}
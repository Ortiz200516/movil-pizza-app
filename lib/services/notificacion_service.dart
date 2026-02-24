import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Gestiona permisos, token FCM y notificaciones en primer plano (web).
class NotificacionService {
  static final NotificacionService _i = NotificacionService._();
  factory NotificacionService() => _i;
  NotificacionService._();

  final _fcm = FirebaseMessaging.instance;
  final _db  = FirebaseFirestore.instance;

  // Callback global para mostrar banners en la UI
  static void Function(String titulo, String cuerpo, {String? tipo})? onMensaje;

  /// Llama esto en main() o justo después del login.
  Future<void> inicializar() async {
    // 1. Pedir permiso al navegador
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true);
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    // 2. Escuchar mensajes con app en primer plano
    FirebaseMessaging.onMessage.listen(_manejarMensaje);
  }

  /// Guarda el token FCM del usuario en Firestore para poder enviarle notificaciones.
  Future<void> guardarToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).update({
        'fcmToken':         token,
        'fcmTokenActualizadoEn': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Envía una notificación a todos los usuarios con un rol determinado.
  /// En producción esto se haría desde Cloud Functions; aquí lo hacemos
  /// escribiendo en una colección 'notificaciones' que puede disparar un trigger.
  static Future<void> notificarRol({
    required String rol,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    Map<String, dynamic>? datos,
  }) async {
    await FirebaseFirestore.instance.collection('notificaciones').add({
      'rol':    rol,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'tipo':   tipo,
      'datos':  datos ?? {},
      'creadoEn': FieldValue.serverTimestamp(),
      'leida': false,
    });
  }

  /// Envía notificación a un usuario específico por uid.
  static Future<void> notificarUsuario({
    required String uid,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    Map<String, dynamic>? datos,
  }) async {
    await FirebaseFirestore.instance.collection('notificaciones').add({
      'uid':    uid,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'tipo':   tipo,
      'datos':  datos ?? {},
      'creadoEn': FieldValue.serverTimestamp(),
      'leida': false,
    });
  }

  void _manejarMensaje(RemoteMessage msg) {
    final titulo = msg.notification?.title ?? msg.data['titulo'] ?? '';
    final cuerpo = msg.notification?.body  ?? msg.data['cuerpo'] ?? '';
    onMensaje?.call(titulo, cuerpo, tipo: msg.data['tipo']);
  }
}

/// Widget que muestra un banner flotante cuando llega una notificación en primer plano.
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
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    NotificacionService.onMensaje = (titulo, cuerpo, {tipo}) {
      if (!mounted) return;
      setState(() { _titulo = titulo; _cuerpo = cuerpo; _tipo = tipo ?? 'info'; });
      _ctrl.forward();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _ctrl.reverse().then((_) {
          if (mounted) setState(() { _titulo = null; _cuerpo = null; });
        });
      });
    };
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _color {
    switch (_tipo) {
      case 'pedido':   return const Color(0xFFFF6B00);
      case 'listo':    return Colors.green;
      case 'camino':   return Colors.indigo;
      default:         return Colors.blueGrey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_titulo != null)
        Positioned(
          top: 12, left: 16, right: 16,
          child: SlideTransition(
            position: _slide,
            child: SafeArea(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Text('🍕', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_titulo!, style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        if (_cuerpo?.isNotEmpty == true)
                          Text(_cuerpo!, style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      onPressed: () => _ctrl.reverse().then((_) {
                        if (mounted) setState(() { _titulo = null; _cuerpo = null; });
                      }),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Stream de notificaciones no leídas para un uid o rol.
Stream<int> streamNotificacionesSinLeer(String uid, String rol) {
  return FirebaseFirestore.instance
      .collection('notificaciones')
      .where('leida', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.where((d) {
            final data = d.data();
            return data['uid'] == uid || data['rol'] == rol;
          }).length);
}

// ── Widget badge reutilizable ─────────────────────────────────
/// Muestra un icono de campana con badge de notificaciones no leídas.
/// Úsalo en el AppBar de cualquier panel de rol.
class NotifBadgeBtn extends StatelessWidget {
  final String uid;
  final String rol;
  const NotifBadgeBtn({super.key, required this.uid, required this.rol});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: streamNotificacionesSinLeer(uid, rol),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                count > 0 ? Icons.notifications : Icons.notifications_none,
                color: count > 0 ? const Color(0xFFFF6B00) : Colors.white38,
                size: 22,
              ),
              onPressed: () => _mostrarNotificaciones(context, uid, rol),
            ),
            if (count > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _mostrarNotificaciones(BuildContext context, String uid, String rol) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifSheet(uid: uid, rol: rol),
    );
  }
}

class _NotifSheet extends StatelessWidget {
  final String uid, rol;
  const _NotifSheet({required this.uid, required this.rol});

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'pedido':    return const Color(0xFFFF6B00);
      case 'listo':     return Colors.green;
      case 'camino':    return Colors.indigo;
      case 'preparando': return Colors.blue;
      default:          return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text('🔔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Notificaciones', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(
              onPressed: () => _marcarTodasLeidas(uid, rol),
              child: Text('Limpiar', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('notificaciones')
                .orderBy('creadoEn', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00)));

              final docs = snap.data!.docs.where((d) {
                final data = d.data();
                return data['uid'] == uid || data['rol'] == rol;
              }).toList();

              if (docs.isEmpty) return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔕', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  Text('Sin notificaciones', style: TextStyle(
                      color: Colors.white38, fontSize: 15)),
                ],
              ));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d    = docs[i].data();
                  final leida = d['leida'] as bool? ?? false;
                  final tipo  = d['tipo'] as String? ?? 'info';
                  final color = _colorTipo(tipo);
                  final ts    = d['creadoEn'];
                  String hora = '';
                  if (ts != null) {
                    final dt = (ts as dynamic).toDate() as DateTime;
                    hora = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                  }

                  return InkWell(
                    onTap: () => FirebaseFirestore.instance
                        .collection('notificaciones').doc(docs[i].id)
                        .update({'leida': true}),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: leida ? Colors.white.withOpacity(0.03) : color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: leida ? Colors.white.withOpacity(0.05) : color.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(
                            tipo == 'pedido' ? '🍕' :
                            tipo == 'listo'  ? '✅' :
                            tipo == 'camino' ? '🛵' : '🔔',
                            style: const TextStyle(fontSize: 16),
                          )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['titulo'] ?? '', style: TextStyle(
                            color: leida ? Colors.white54 : Colors.white,
                            fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                            fontSize: 13,
                          )),
                          if ((d['cuerpo'] ?? '').isNotEmpty)
                            Text(d['cuerpo'], style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        ])),
                        Column(children: [
                          Text(hora, style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                          if (!leida) ...[
                            const SizedBox(height: 4),
                            Container(width: 8, height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          ],
                        ]),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _marcarTodasLeidas(String uid, String rol) async {
    final snap = await FirebaseFirestore.instance
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['uid'] == uid || d['rol'] == rol) {
        batch.update(doc.reference, {'leida': true});
      }
    }
    await batch.commit();
  }
}
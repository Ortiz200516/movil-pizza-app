import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Handler background (DEBE estar fuera de cualquier clase, a nivel top-level)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado por el sistema en background
  // Solo necesitamos manejar el mensaje
  final titulo = message.notification?.title ?? message.data['titulo'] ?? '';
  final cuerpo = message.notification?.body  ?? message.data['cuerpo'] ?? '';
  if (titulo.isEmpty) return;

  // Mostrar notificación local cuando la app está en background/terminada
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
  await plugin.show(
    message.hashCode,
    titulo,
    cuerpo,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'la_italiana_channel', 'La Italiana',
        channelDescription: 'Notificaciones de pedidos',
        importance: Importance.max,
        priority: Priority.high,
        color: const Color(0xFFFF6B00),
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: message.data['pedidoId'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificacionService — Singleton
// ─────────────────────────────────────────────────────────────────────────────
class NotificacionService {
  static final NotificacionService _i = NotificacionService._();
  factory NotificacionService() => _i;
  NotificacionService._();

  final _fcm    = FirebaseMessaging.instance;
  final _db     = FirebaseFirestore.instance;
  final _plugin = FlutterLocalNotificationsPlugin();

  // Callback para mostrar banner en foreground
  static void Function(String titulo, String cuerpo, {String? tipo, String? pedidoId})? onMensaje;

  // Callback para navegar al abrir notificación
  static void Function(String? pedidoId)? onAbrir;

  // ── Inicializar (llamar en main.dart ANTES de runApp) ──────────────────────
  Future<void> inicializar() async {
    // 1. Handler background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Permisos
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 3. Canal Android
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        // Usuario toca notificación local (background/terminated)
        onAbrir?.call(details.payload);
      },
    );
    await _crearCanalAndroid();

    // 4. Foreground: mostrar banner custom
    FirebaseMessaging.onMessage.listen(_manejarForeground);

    // 5. App abierta desde notificación (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      onAbrir?.call(msg.data['pedidoId']);
    });

    // 6. App abierta desde terminada
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      // Pequeño delay para que la navegación funcione
      Future.delayed(const Duration(milliseconds: 500), () {
        onAbrir?.call(initial.data['pedidoId']);
      });
    }

    // 7. Notificaciones en foreground (mostrar como heads-up)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }

  // ── Guardar token FCM del usuario ──────────────────────────────────────────
  Future<void> guardarToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenActualizadoEn': FieldValue.serverTimestamp(),
      });

      // Escuchar refresh del token
      _fcm.onTokenRefresh.listen((nuevoToken) async {
        try {
          await _db.collection('users').doc(uid).update({
            'fcmToken': nuevoToken,
            'fcmTokenActualizadoEn': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      });
    } catch (_) {}
  }

  // ── Manejar mensaje en foreground ──────────────────────────────────────────
  void _manejarForeground(RemoteMessage msg) {
    final titulo   = msg.notification?.title ?? msg.data['titulo'] ?? '';
    final cuerpo   = msg.notification?.body  ?? msg.data['cuerpo'] ?? '';
    final tipo     = msg.data['tipo'] as String?;
    final pedidoId = msg.data['pedidoId'] as String?;
    if (titulo.isEmpty) return;
    onMensaje?.call(titulo, cuerpo, tipo: tipo, pedidoId: pedidoId);
  }

  // ── Canal de notificaciones Android ───────────────────────────────────────
  Future<void> _crearCanalAndroid() async {
    const canal = AndroidNotificationChannel(
      'la_italiana_channel',
      'La Italiana',
      description: 'Notificaciones de pedidos y entregas',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      ledColor: Color(0xFFFF6B00),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canal);
  }

  // ── Crear notificación en Firestore (la Cloud Function la envía) ───────────
  static Future<void> notificarUsuario({
    required String uid,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    String? pedidoId,
    Map<String, dynamic>? datos,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'uid': uid,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'tipo': tipo,
        'pedidoId': pedidoId,
        'datos': datos ?? {},
        'creadoEn': FieldValue.serverTimestamp(),
        'leida': false,
        'enviada': false, // la Cloud Function cambia esto a true
      });
    } catch (_) {}
  }

  static Future<void> notificarRol({
    required String rol,
    required String titulo,
    required String cuerpo,
    String tipo = 'info',
    String? pedidoId,
    Map<String, dynamic>? datos,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'rol': rol,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'tipo': tipo,
        'pedidoId': pedidoId,
        'datos': datos ?? {},
        'creadoEn': FieldValue.serverTimestamp(),
        'leida': false,
        'enviada': false,
      });
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream de notificaciones sin leer
// ─────────────────────────────────────────────────────────────────────────────
Stream<int> streamNotificacionesSinLeer(String uid, String rol) {
  return FirebaseFirestore.instance
      .collection('notificaciones')
      .orderBy('creadoEn', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.where((d) {
            final data  = d.data();
            final leida = data['leida'] as bool? ?? false;
            if (leida) return false;
            return data['uid'] == uid || data['rol'] == rol;
          }).length);
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner in-app (foreground)
// ─────────────────────────────────────────────────────────────────────────────
class NotificacionBanner extends StatefulWidget {
  final Widget child;
  const NotificacionBanner({super.key, required this.child});
  @override State<NotificacionBanner> createState() => _NotificacionBannerState();
}

class _NotificacionBannerState extends State<NotificacionBanner>
    with SingleTickerProviderStateMixin {
  String? _titulo;
  String? _cuerpo;
  String  _tipo     = 'info';
  String? _pedidoId;
  late AnimationController _ctrl;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(
        begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    NotificacionService.onMensaje = (titulo, cuerpo, {tipo, pedidoId}) {
      if (!mounted) return;
      setState(() {
        _titulo   = titulo;
        _cuerpo   = cuerpo;
        _tipo     = tipo ?? 'info';
        _pedidoId = pedidoId;
      });
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

  void _cerrar() => _ctrl.reverse().then((_) {
    if (mounted) setState(() { _titulo = null; _cuerpo = null; });
  });

  Color get _color {
    switch (_tipo) {
      case 'pedido':     return const Color(0xFFFF6B00);
      case 'listo':      return Colors.green.shade600;
      case 'camino':     return Colors.indigo.shade600;
      case 'preparando': return Colors.blue.shade600;
      case 'cancelado':  return Colors.red.shade600;
      default:           return const Color(0xFF334155);
    }
  }

  String get _emoji {
    switch (_tipo) {
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
                    onTap: () {
                      _cerrar();
                      if (_pedidoId != null) {
                        NotificacionService.onAbrir?.call(_pedidoId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [_color, _color.withOpacity(0.85)]),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_titulo!, style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 14)),
                            if (_cuerpo?.isNotEmpty == true)
                              Text(_cuerpo!, maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12)),
                          ],
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cerrar,
                          child: Icon(Icons.close,
                              color: Colors.white.withOpacity(0.6), size: 16),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Badge animado en AppBar
// ─────────────────────────────────────────────────────────────────────────────
class NotifBadgeBtn extends StatefulWidget {
  final String uid, rol;
  const NotifBadgeBtn({super.key, required this.uid, required this.rol});
  @override State<NotifBadgeBtn> createState() => _NotifBadgeBtnState();
}

class _NotifBadgeBtnState extends State<NotifBadgeBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

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
        if (count == 0) { _pulse.stop(); }
        else if (!_pulse.isAnimating) { _pulse.repeat(reverse: true); }

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
                color: count > 0 ? const Color(0xFFFF6B00) : Colors.white38,
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
                    border: Border.all(
                        color: const Color(0xFF0F172A), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: Colors.red.withOpacity(
                            0.4 + _pulse.value * 0.3),
                        blurRadius: 6, spreadRadius: 1)],
                  ),
                  child: Center(child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.bold),
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
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PanelNotificaciones(uid: widget.uid, rol: widget.rol),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel de notificaciones
// ─────────────────────────────────────────────────────────────────────────────
class _PanelNotificaciones extends StatelessWidget {
  final String uid, rol;
  const _PanelNotificaciones({required this.uid, required this.rol});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white12,
                  borderRadius: BorderRadius.circular(2))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(children: [
            const Text('🔔 Notificaciones', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(
              onPressed: () => _marcarTodasLeidas(),
              child: const Text('Marcar todas',
                  style: TextStyle(color: Color(0xFFFF6B00), fontSize: 12)),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notificaciones')
                .orderBy('creadoEn', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00)));

              final docs = snap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['uid'] == uid || data['rol'] == rol;
              }).toList();

              if (docs.isEmpty) return const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔕', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 10),
                  Text('Sin notificaciones', style: TextStyle(
                      color: Colors.white38, fontSize: 14)),
                ],
              ));

              return ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final leida = data['leida'] as bool? ?? false;
                  final tipo  = data['tipo'] as String? ?? 'info';
                  final ts    = (data['creadoEn'] as Timestamp?)?.toDate();

                  return GestureDetector(
                    onTap: () {
                      // Marcar como leída
                      doc.reference.update({'leida': true});
                      final pedidoId = data['pedidoId'] as String?;
                      if (pedidoId != null) {
                        Navigator.pop(context);
                        NotificacionService.onAbrir?.call(pedidoId);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: leida
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF263348),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: leida
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFFF6B00).withOpacity(0.25),
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _colorTipo(tipo).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text(
                              _emojiTipo(tipo),
                              style: const TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['titulo'] ?? '',
                                style: TextStyle(
                                    color: leida ? Colors.white54 : Colors.white,
                                    fontWeight: leida
                                        ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 13)),
                            if ((data['cuerpo'] as String? ?? '').isNotEmpty)
                              Text(data['cuerpo'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            if (ts != null)
                              Text(_formatTs(ts),
                                  style: const TextStyle(
                                      color: Colors.white24, fontSize: 10)),
                          ],
                        )),
                        if (!leida)
                          Container(width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                            ),
                          ),
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

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'pedido':     return const Color(0xFFFF6B00);
      case 'listo':      return Colors.green;
      case 'camino':     return Colors.indigo;
      case 'preparando': return Colors.blue;
      case 'cancelado':  return Colors.red;
      default:           return Colors.grey;
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

  String _formatTs(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${ts.day}/${ts.month}/${ts.year}';
  }

  Future<void> _marcarTodasLeidas() async {
    final snap = await FirebaseFirestore.instance
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['uid'] == uid || data['rol'] == rol) {
        batch.update(doc.reference, {'leida': true});
      }
    }
    await batch.commit();
  }
}
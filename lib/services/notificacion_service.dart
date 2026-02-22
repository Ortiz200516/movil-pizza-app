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
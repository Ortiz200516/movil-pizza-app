import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Solicitar permisos
    await _requestPermissions();

    // Configurar notificaciones locales
    await _initializeLocalNotifications();

    // Escuchar mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Manejar tap en notificación cuando la app está en background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Permisos de notificación: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Manejar tap en notificación
        print('Notificación tocada: ${details.payload}');
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Mensaje recibido en primer plano: ${message.notification?.title}');
    
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Pizzería App',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notificación tocada: ${message.notification?.title}');
    // Aquí puedes navegar a una pantalla específica
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pizzeria_channel',
      'Pedidos',
      channelDescription: 'Notificaciones de pedidos de la pizzería',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Obtener token del dispositivo
  Future<String?> getDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  // Guardar token en Firestore para el usuario
  Future<void> saveTokenToFirestore(String userId, String rol) async {
    try {
      String? token = await getDeviceToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error guardando token: $e');
    }
  }

  // Enviar notificación a un usuario específico
  Future<void> sendNotificationToUser(String userId, String title, String body) async {
    try {
      // Obtener el token del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final token = userDoc.data()?['fcmToken'];
      
      if (token != null) {
        // Aquí usarías Cloud Functions para enviar la notificación
        // Por ahora solo guardamos en Firestore para que se muestre
        await FirebaseFirestore.instance.collection('notificaciones').add({
          'userId': userId,
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print('Error enviando notificación: $e');
    }
  }

  // Enviar notificación a todos los usuarios de un rol
  Future<void> sendNotificationToRole(String rol, String title, String body) async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('rol', isEqualTo: rol)
          .get();

      for (var doc in usersSnapshot.docs) {
        await sendNotificationToUser(doc.id, title, body);
      }
    } catch (e) {
      print('Error enviando notificaciones por rol: $e');
    }
  }

  // Notificar nuevo pedido a la cocina
  Future<void> notifyNewOrderToKitchen(String pedidoId, int itemsCount) async {
    await sendNotificationToRole(
      'Cocinero',
      '🍕 Nuevo pedido recibido',
      'Pedido con $itemsCount productos esperando preparación',
    );
  }

  // Notificar pedido listo a repartidores
  Future<void> notifyOrderReadyToDrivers(String pedidoId, String direccion) async {
    await sendNotificationToRole(
      'Repartidor',
      '🛵 Pedido listo para entregar',
      'Dirección: $direccion',
    );
  }

  // Notificar cambio de estado al cliente
  Future<void> notifyOrderStatusToClient(String clientId, String estado, String mensaje) async {
    String emoji;
    switch (estado.toLowerCase()) {
      case 'en preparación':
        emoji = '👨‍🍳';
        break;
      case 'listo':
        emoji = '✅';
        break;
      case 'en camino':
        emoji = '🛵';
        break;
      case 'entregado':
        emoji = '🎉';
        break;
      default:
        emoji = '📦';
    }

    await sendNotificationToUser(
      clientId,
      '$emoji Tu pedido: $estado',
      mensaje,
    );
  }
}
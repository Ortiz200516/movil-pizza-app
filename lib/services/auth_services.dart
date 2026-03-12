import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notificacion_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 🔐 LOGIN Y DEVUELVE EL ROL DEL USUARIO
  Future<String> login(String email, String password) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception('Usuario sin rol asignado en Firestore');
      }

      // Guardar token FCM para notificaciones push
      await NotificacionService().guardarToken(uid);

      return doc['rol'] as String;
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// 📝 REGISTRO DE USUARIO CON CÉDULA Y PAÍS
  Future<void> register({
    required String email,
    required String password,
    required String rol,
    String? nombre,
    String? telefono,
    required String cedula,
    required String pais,
  }) async {
    try {
      final existeCedula = await verificarCedulaExistente(cedula, pais);
      if (existeCedula) {
        throw Exception('Esta cédula ya está registrada');
      }

      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'rol': rol,
        'nombre': nombre,
        'telefono': telefono,
        'cedula': cedula,
        'pais': pais,
        'createdAt': FieldValue.serverTimestamp(),
        'disponible': false,
      });
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  /// 🔍 VERIFICAR SI LA CÉDULA YA EXISTE
  Future<bool> verificarCedulaExistente(String cedula, String pais) async {
    try {
      final query = await _db
          .collection('users')
          .where('cedula', isEqualTo: cedula)
          .where('pais', isEqualTo: pais)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🎭 OBTENER ROL DE UN UID
  Future<String> obtenerRol(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('Usuario sin rol');
    return doc['rol'] as String;
  }

  /// 🚪 CERRAR SESIÓN
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// 👤 OBTENER USUARIO ACTUAL
  User? get currentUser => _auth.currentUser;

  /// 📧 OBTENER EMAIL DEL USUARIO ACTUAL
  String? get currentUserEmail => _auth.currentUser?.email;

  /// 🆔 OBTENER UID DEL USUARIO ACTUAL
  String? get currentUserId => _auth.currentUser?.uid;
}
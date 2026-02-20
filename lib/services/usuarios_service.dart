import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';

class UsuariosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 📋 OBTENER TODOS LOS USUARIOS
  Stream<List<Usuario>> obtenerTodosUsuarios() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Usuario.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  /// 🔄 CAMBIAR ROL DE UN USUARIO
  Future<void> cambiarRol(String userId, String nuevoRol) async {
    try {
      await _db.collection('users').doc(userId).update({
        'rol': nuevoRol,
        'actualizado': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al cambiar rol: $e');
    }
  }

  /// 🗑️ ELIMINAR USUARIO (opcional)
  Future<void> eliminarUsuario(String userId) async {
    try {
      await _db.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Error al eliminar usuario: $e');
    }
  }

  /// ✅ CAMBIAR DISPONIBILIDAD (para repartidores y meseros)
  Future<void> cambiarDisponibilidad(String userId, bool disponible) async {
    try {
      await _db.collection('users').doc(userId).update({
        'disponible': disponible,
      });
    } catch (e) {
      throw Exception('Error al cambiar disponibilidad: $e');
    }
  }

  /// 📊 OBTENER USUARIOS POR ROL
  Stream<List<Usuario>> obtenerUsuariosPorRol(String rol) {
    return _db
        .collection('users')
        .where('rol', isEqualTo: rol)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Usuario.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }
}
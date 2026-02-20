import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/categoria_model.dart';

class CategoriaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ➕ AGREGAR CATEGORÍA
  Future<void> agregarCategoria(CategoriaModel categoria) async {
    try {
      await _db.collection('categorias').add(categoria.toMap());
    } catch (e) {
      throw Exception('Error al agregar categoría: $e');
    }
  }

  /// ✏️ EDITAR CATEGORÍA
  Future<void> editarCategoria(String categoriaId, CategoriaModel categoria) async {
    try {
      await _db.collection('categorias').doc(categoriaId).update(categoria.toMap());
    } catch (e) {
      throw Exception('Error al editar categoría: $e');
    }
  }

  /// 🗑️ ELIMINAR CATEGORÍA
  Future<void> eliminarCategoria(String categoriaId) async {
    try {
      await _db.collection('categorias').doc(categoriaId).delete();
    } catch (e) {
      throw Exception('Error al eliminar categoría: $e');
    }
  }

  /// 📋 OBTENER TODAS LAS CATEGORÍAS
  Stream<List<CategoriaModel>> obtenerCategorias() {
    return _db
        .collection('categorias')
        .orderBy('orden')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoriaModel.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  /// 📋 OBTENER CATEGORÍAS DISPONIBLES
  Stream<List<CategoriaModel>> obtenerCategoriasDisponibles() {
    return _db
        .collection('categorias')
        .where('disponible', isEqualTo: true)
        .orderBy('orden')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoriaModel.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  /// 🔍 OBTENER CATEGORÍA POR ID
  Future<CategoriaModel?> obtenerCategoriaPorId(String categoriaId) async {
    try {
      final doc = await _db.collection('categorias').doc(categoriaId).get();
      
      if (!doc.exists) return null;
      
      return CategoriaModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Error al obtener categoría: $e');
    }
  }
}
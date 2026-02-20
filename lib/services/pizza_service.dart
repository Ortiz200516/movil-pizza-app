import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pizza_model.dart';

class PizzaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> agregarPizza(PizzaModel pizza) async {
    try {
      await _db.collection('pizzas').add(pizza.toMap());
    } catch (e) {
      throw Exception('Error al agregar pizza: $e');
    }
  }

  Future<void> editarPizza(String pizzaId, PizzaModel pizza) async {
    try {
      await _db.collection('pizzas').doc(pizzaId).update(pizza.toMap());
    } catch (e) {
      throw Exception('Error al editar pizza: $e');
    }
  }

  Future<void> eliminarPizza(String pizzaId) async {
    try {
      await _db.collection('pizzas').doc(pizzaId).delete();
    } catch (e) {
      throw Exception('Error al eliminar pizza: $e');
    }
  }

  Stream<List<PizzaModel>> obtenerPizzas() {
    return _db.collection('pizzas').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PizzaModel.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<PizzaModel>> obtenerPizzasDisponibles() {
    return _db
        .collection('pizzas')
        .where('disponible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PizzaModel.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  Future<PizzaModel?> obtenerPizzaPorId(String pizzaId) async {
    try {
      final doc = await _db.collection('pizzas').doc(pizzaId).get();
      
      if (!doc.exists) return null;
      
      return PizzaModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Error al obtener pizza: $e');
    }
  }
}
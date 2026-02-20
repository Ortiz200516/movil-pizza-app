import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto_model.dart';

class ProductoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ProductoModel>> obtenerProductos() {
    return _db.collection('productos').where('disponible', isEqualTo: true)
        .snapshots().map((s) => s.docs.map((d) => ProductoModel.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<ProductoModel>> obtenerProductosPorCategoria(String categoria) {
    return _db.collection('productos')
        .where('categoria', isEqualTo: categoria)
        .where('disponible', isEqualTo: true)
        .snapshots().map((s) => s.docs.map((d) => ProductoModel.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<ProductoModel>> obtenerProductosDisponibles() => obtenerProductos();

  Future<void> agregarProducto(ProductoModel p) async {
    await _db.collection('productos').add(p.toMap());
  }

  Future<void> editarProducto(String id, ProductoModel p) async {
    await _db.collection('productos').doc(id).update(p.toMap());
  }

  Future<void> eliminarProducto(String id) async {
    await _db.collection('productos').doc(id).update({'disponible': false});
  }

  Future<ProductoModel?> obtenerProductoPorId(String id) async {
    final doc = await _db.collection('productos').doc(id).get();
    if (!doc.exists) return null;
    return ProductoModel.fromFirestore(doc.id, doc.data()!);
  }

  Future<List<String>> obtenerCategorias() async {
    final snap = await _db.collection('productos').where('disponible', isEqualTo: true).get();
    return snap.docs.map((d) => d.data()['categoria'] as String? ?? '').toSet().where((c) => c.isNotEmpty).toList()..sort();
  }

  Future<void> inicializarProductosEjemplo() async {
    final existing = await _db.collection('productos').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final productos = [
      {'nombre': 'Pizza Margarita', 'descripcion': 'Tomate, mozzarella, albahaca fresca', 'precio': 8.50, 'categoria': 'pizza', 'tiempoPreparacion': 20, 'disponible': true},
      {'nombre': 'Pizza Pepperoni', 'descripcion': 'Pepperoni, mozzarella, salsa de tomate', 'precio': 10.00, 'categoria': 'pizza', 'tiempoPreparacion': 20, 'disponible': true},
      {'nombre': 'Pizza Hawaiana', 'descripcion': 'Jamón, piña, mozzarella', 'precio': 9.50, 'categoria': 'pizza', 'tiempoPreparacion': 20, 'disponible': true},
      {'nombre': 'Pizza BBQ Pollo', 'descripcion': 'Pollo, tocino, cebolla, salsa BBQ', 'precio': 11.00, 'categoria': 'pizza', 'tiempoPreparacion': 22, 'disponible': true},
      {'nombre': 'Hamburguesa Clásica', 'descripcion': 'Carne de res, lechuga, tomate, queso cheddar', 'precio': 6.50, 'categoria': 'hamburguesa', 'tiempoPreparacion': 15, 'disponible': true},
      {'nombre': 'Hamburguesa BBQ', 'descripcion': 'Carne, queso, tocino, cebolla caramelizada, salsa BBQ', 'precio': 7.50, 'categoria': 'hamburguesa', 'tiempoPreparacion': 15, 'disponible': true},
      {'nombre': 'Hamburguesa de Pollo', 'descripcion': 'Pechuga de pollo, lechuga, tomate, mayonesa', 'precio': 6.00, 'categoria': 'hamburguesa', 'tiempoPreparacion': 12, 'disponible': true},
      {'nombre': 'Hamburguesa Doble', 'descripcion': 'Doble carne, doble queso, vegetales frescos', 'precio': 9.00, 'categoria': 'hamburguesa', 'tiempoPreparacion': 15, 'disponible': true},
      {'nombre': 'Cerveza Pilsener', 'descripcion': 'Cerveza nacional 330ml', 'precio': 1.50, 'categoria': 'cerveza', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Cerveza Club Premium', 'descripcion': 'Cerveza premium 355ml', 'precio': 2.00, 'categoria': 'cerveza', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Cerveza Artesanal IPA', 'descripcion': 'Cerveza artesanal 500ml', 'precio': 4.50, 'categoria': 'cerveza', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Six Pack Pilsener', 'descripcion': '6 cervezas Pilsener 330ml', 'precio': 7.50, 'categoria': 'cerveza', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Coca Cola', 'descripcion': 'Refresco 500ml', 'precio': 1.00, 'categoria': 'bebida', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Agua Mineral', 'descripcion': 'Agua embotellada 500ml', 'precio': 0.75, 'categoria': 'bebida', 'tiempoPreparacion': 1, 'disponible': true},
      {'nombre': 'Jugo Natural Naranja', 'descripcion': 'Jugo de naranja natural 400ml', 'precio': 2.50, 'categoria': 'bebida', 'tiempoPreparacion': 5, 'disponible': true},
      {'nombre': 'Limonada', 'descripcion': 'Limonada natural con hielo', 'precio': 2.00, 'categoria': 'bebida', 'tiempoPreparacion': 5, 'disponible': true},
      {'nombre': 'Alitas de Pollo x8', 'descripcion': '8 alitas con salsa a elección (BBQ, Buffalo, Ají)', 'precio': 5.50, 'categoria': 'entrada', 'tiempoPreparacion': 15, 'disponible': true},
      {'nombre': 'Papas Fritas', 'descripcion': 'Papas fritas crujientes porción grande', 'precio': 3.00, 'categoria': 'entrada', 'tiempoPreparacion': 8, 'disponible': true},
      {'nombre': 'Aros de Cebolla', 'descripcion': 'Aros de cebolla empanizados', 'precio': 3.50, 'categoria': 'entrada', 'tiempoPreparacion': 10, 'disponible': true},
      {'nombre': 'Ensalada César', 'descripcion': 'Lechuga romana, pollo, crutones, parmesano', 'precio': 5.00, 'categoria': 'ensalada', 'tiempoPreparacion': 8, 'disponible': true},
      {'nombre': 'Ensalada Mixta', 'descripcion': 'Lechugas variadas, tomate, pepino, zanahoria', 'precio': 4.00, 'categoria': 'ensalada', 'tiempoPreparacion': 6, 'disponible': true},
      {'nombre': 'Helado 3 Bolas', 'descripcion': 'Helado artesanal (Vainilla, Chocolate, Fresa)', 'precio': 3.50, 'categoria': 'postre', 'tiempoPreparacion': 3, 'disponible': true},
      {'nombre': 'Brownie con Helado', 'descripcion': 'Brownie de chocolate caliente con helado de vainilla', 'precio': 4.50, 'categoria': 'postre', 'tiempoPreparacion': 10, 'disponible': true},
    ];

    for (var p in productos) {
      await _db.collection('productos').add(p);
    }
    print('✅ ${productos.length} productos inicializados');
  }
}
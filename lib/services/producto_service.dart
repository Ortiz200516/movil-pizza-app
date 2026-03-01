import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto_model.dart';

class ProductoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene todos los productos disponibles SIN normalizar la categoría.
  /// La categoría se guarda y lee exactamente como está en Firestore
  /// para que los chips del menú siempre coincidan.
  Stream<List<ProductoModel>> obtenerProductos() {
    return _db
        .collection('productos')
        .where('disponible', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ProductoModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Stream<List<ProductoModel>> obtenerProductosDisponibles() =>
      obtenerProductos();

  Stream<List<ProductoModel>> obtenerProductosPorCategoria(String categoria) {
    return _db
        .collection('productos')
        .where('categoria', isEqualTo: categoria)
        .where('disponible', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ProductoModel.fromFirestore(d.id, d.data()))
            .toList());
  }

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
    final snap = await _db
        .collection('productos')
        .where('disponible', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => d.data()['categoria'] as String? ?? '')
        .toSet()
        .where((c) => c.isNotEmpty)
        .toList()
      ..sort();
  }

  /// Solo inserta productos de ejemplo si la colección está vacía.
  /// Las categorías usan los MISMOS nombres que crea el Admin
  /// para que los chips siempre coincidan.
  Future<void> inicializarProductosEjemplo() async {
    final existing = await _db.collection('productos').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Primero verificar qué categorías existen en Firestore
    final catSnap = await _db.collection('categorias').get();
    final catNombres = catSnap.docs
        .map((d) => d.data()['nombre'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    // Función para buscar categoría que coincida (flexible)
    String resolverCat(String key) {
      // Buscar coincidencia exacta o parcial en las categorías reales
      for (final c in catNombres) {
        if (c.toLowerCase().contains(key.toLowerCase()) ||
            key.toLowerCase().contains(c.toLowerCase().replaceAll('s', ''))) {
          return c;
        }
      }
      // Si no hay categorías creadas aún, usar nombre capitalizado simple
      return key[0].toUpperCase() + key.substring(1);
    }

    final productos = [
      {
        'nombre': 'Pizza Margarita',
        'descripcion': 'Tomate, mozzarella, albahaca fresca',
        'precio': 8.50,
        'categoria': resolverCat('pizza'),
        'tiempoPreparacion': 20,
        'disponible': true
      },
      {
        'nombre': 'Pizza Pepperoni',
        'descripcion': 'Pepperoni, mozzarella, salsa de tomate',
        'precio': 10.00,
        'categoria': resolverCat('pizza'),
        'tiempoPreparacion': 20,
        'disponible': true
      },
      {
        'nombre': 'Pizza Hawaiana',
        'descripcion': 'Jamón, piña, mozzarella',
        'precio': 9.50,
        'categoria': resolverCat('pizza'),
        'tiempoPreparacion': 20,
        'disponible': true
      },
      {
        'nombre': 'Hamburguesa Clásica',
        'descripcion': 'Carne de res, lechuga, tomate, queso cheddar',
        'precio': 6.50,
        'categoria': resolverCat('hamburguesa'),
        'tiempoPreparacion': 15,
        'disponible': true
      },
      {
        'nombre': 'Hamburguesa BBQ',
        'descripcion': 'Carne, queso, tocino, cebolla caramelizada, salsa BBQ',
        'precio': 7.50,
        'categoria': resolverCat('hamburguesa'),
        'tiempoPreparacion': 15,
        'disponible': true
      },
      {
        'nombre': 'Cerveza Pilsener',
        'descripcion': 'Cerveza nacional 330ml',
        'precio': 1.50,
        'categoria': resolverCat('cerveza'),
        'tiempoPreparacion': 1,
        'disponible': true
      },
      {
        'nombre': 'Cerveza Artesanal',
        'descripcion': 'Cerveza artesanal IPA 500ml',
        'precio': 4.50,
        'categoria': resolverCat('cerveza'),
        'tiempoPreparacion': 1,
        'disponible': true
      },
      {
        'nombre': 'Coca Cola',
        'descripcion': 'Refresco 500ml',
        'precio': 1.00,
        'categoria': resolverCat('bebida'),
        'tiempoPreparacion': 1,
        'disponible': true
      },
      {
        'nombre': 'Jugo de Naranja',
        'descripcion': 'Jugo natural 400ml',
        'precio': 2.50,
        'categoria': resolverCat('bebida'),
        'tiempoPreparacion': 5,
        'disponible': true
      },
      {
        'nombre': 'Alitas x8',
        'descripcion': '8 alitas con salsa BBQ o Buffalo',
        'precio': 5.50,
        'categoria': resolverCat('entrada'),
        'tiempoPreparacion': 15,
        'disponible': true
      },
      {
        'nombre': 'Papas Fritas',
        'descripcion': 'Porción grande de papas crujientes',
        'precio': 3.00,
        'categoria': resolverCat('entrada'),
        'tiempoPreparacion': 8,
        'disponible': true
      },
      {
        'nombre': 'Ensalada César',
        'descripcion': 'Lechuga romana, pollo, crutones, parmesano',
        'precio': 5.00,
        'categoria': resolverCat('ensalada'),
        'tiempoPreparacion': 8,
        'disponible': true
      },
      {
        'nombre': 'Brownie con Helado',
        'descripcion': 'Brownie caliente con helado de vainilla',
        'precio': 4.50,
        'categoria': resolverCat('postre'),
        'tiempoPreparacion': 10,
        'disponible': true
      },
    ];

    for (final p in productos) {
      await _db.collection('productos').add(p);
    }
    print('✅ ${productos.length} productos inicializados');
  }
}

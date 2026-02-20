class ProductoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria; // 'pizza','hamburguesa','cerveza','bebida','entrada','ensalada','postre'
  final bool disponible;
  final Map<String, dynamic>? opciones;
  final int tiempoPreparacion;

  ProductoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    this.disponible = true,
    this.opciones,
    this.tiempoPreparacion = 15,
  });

  String get icono {
    switch (categoria.toLowerCase()) {
      case 'pizza': return '🍕';
      case 'hamburguesa': return '🍔';
      case 'cerveza': return '🍺';
      case 'bebida': return '🥤';
      case 'postre': return '🍰';
      case 'entrada': return '🍟';
      case 'ensalada': return '🥗';
      default: return '🍽️';
    }
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre, 'descripcion': descripcion, 'precio': precio,
    'categoria': categoria, 'disponible': disponible,
    'opciones': opciones, 'tiempoPreparacion': tiempoPreparacion,
  };

  factory ProductoModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductoModel(
      id: id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      precio: (data['precio'] ?? data['precioBase'] ?? 0.0).toDouble(),
      categoria: data['categoria'] ?? data['categoriaNombre'] ?? 'otros',
      disponible: data['disponible'] ?? true,
      opciones: data['opciones'] as Map<String, dynamic>?,
      tiempoPreparacion: data['tiempoPreparacion'] ?? 15,
    );
  }

  // ── Getters de compatibilidad con código anterior del home_admin ──
  double get precioBase => precio;
  String get categoriaNombre => categoria;
  String get categoriaId => categoria;
  bool get tieneTamanios => opciones?.containsKey('tamanios') == true || opciones?.containsKey('tamaños') == true;
  bool get esCombo => false;
  bool get esPizza => categoria.toLowerCase() == 'pizza';
  bool get esBebida => categoria.toLowerCase() == 'bebida';
}
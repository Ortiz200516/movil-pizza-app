class ProductoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String
      categoria; // 'pizza','hamburguesa','cerveza','bebida','entrada','ensalada','postre'
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
    final c = categoria.toLowerCase();
    if (c.contains('pizza')) return '🍕';
    if (c.contains('hamburgues') || c.contains('burger')) return '🍔';
    if (c.contains('cerveza') || c.contains('beer')) return '🍺';
    if (c.contains('bebida') ||
        c.contains('refresco') ||
        c.contains('jugo') ||
        c.contains('gaseosa')) return '🥤';
    if (c.contains('postre') || c.contains('helado') || c.contains('dulce'))
      return '🍰';
    if (c.contains('entrada') ||
        c.contains('snack') ||
        c.contains('papa') ||
        c.contains('alita')) return '🍟';
    if (c.contains('ensalada')) return '🥗';
    if (c.contains('sandwich') ||
        c.contains('sándwich') ||
        c.contains('tostada') ||
        c.contains('wrap')) return '🥪';
    if (c.contains('pasta') || c.contains('espagueti') || c.contains('lasaña'))
      return '🍝';
    if (c.contains('pollo') || c.contains('chicken')) return '🍗';
    if (c.contains('carne') || c.contains('parrilla') || c.contains('steak'))
      return '🥩';
    if (c.contains('mariscos') ||
        c.contains('pescado') ||
        c.contains('camarones')) return '🦐';
    if (c.contains('cafe') || c.contains('café') || c.contains('coffee'))
      return '☕';
    if (c.contains('combo') || c.contains('promo')) return '🍱';
    if (c.contains('desayuno')) return '🍳';
    if (c.contains('sopa') || c.contains('caldo')) return '🍜';
    // Fallback: usar la primera letra como indicador
    return '🍽️';
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'categoria': categoria,
        'disponible': disponible,
        'opciones': opciones,
        'tiempoPreparacion': tiempoPreparacion,
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
  bool get tieneTamanios =>
      opciones?.containsKey('tamanios') == true ||
      opciones?.containsKey('tamaños') == true;
  bool get esCombo => false;
  bool get esPizza => categoria.toLowerCase() == 'pizza';
  bool get esBebida => categoria.toLowerCase() == 'bebida';
}

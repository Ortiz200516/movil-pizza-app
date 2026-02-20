class PizzaModel {
  final String id;
  final String nombre;
  final double precio;
  final String descripcion;
  final String? imagenUrl;
  final bool disponible;

  PizzaModel({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.descripcion,
    this.imagenUrl,
    this.disponible = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'descripcion': descripcion,
      'imagenUrl': imagenUrl,
      'disponible': disponible,
    };
  }

  factory PizzaModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PizzaModel(
      id: id,
      nombre: data['nombre'] ?? 'Pizza sin nombre',
      precio: (data['precio'] ?? 0).toDouble(),
      descripcion: data['descripcion'] ?? '',
      imagenUrl: data['imagenUrl'],
      disponible: data['disponible'] ?? true,
    );
  }
}
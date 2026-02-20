class ComboModel {
  final String id;
  final String nombre;
  final String descripcion;
  final List<ComboItem> items;
  final double precioOriginal; // Suma de todos los items
  final double precioCombo; // Precio con descuento
  final bool disponible;

  ComboModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.items,
    required this.precioOriginal,
    required this.precioCombo,
    this.disponible = true,
  });

  double get descuento => precioOriginal - precioCombo;
  double get porcentajeDescuento => (descuento / precioOriginal) * 100;

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'items': items.map((i) => i.toMap()).toList(),
      'precioOriginal': precioOriginal,
      'precioCombo': precioCombo,
      'disponible': disponible,
    };
  }

  factory ComboModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ComboModel(
      id: id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      items: (data['items'] as List?)
              ?.map((i) => ComboItem.fromMap(i))
              .toList() ??
          [],
      precioOriginal: (data['precioOriginal'] ?? 0).toDouble(),
      precioCombo: (data['precioCombo'] ?? 0).toDouble(),
      disponible: data['disponible'] ?? true,
    );
  }
}

class ComboItem {
  final String productoId;
  final String productoNombre;
  final String? tamaño; // Para pizzas
  final int cantidad;

  ComboItem({
    required this.productoId,
    required this.productoNombre,
    this.tamaño,
    this.cantidad = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'productoNombre': productoNombre,
      'tamaño': tamaño,
      'cantidad': cantidad,
    };
  }

  factory ComboItem.fromMap(Map<String, dynamic> data) {
    return ComboItem(
      productoId: data['productoId'] ?? '',
      productoNombre: data['productoNombre'] ?? '',
      tamaño: data['tamaño'],
      cantidad: data['cantidad'] ?? 1,
    );
  }
}
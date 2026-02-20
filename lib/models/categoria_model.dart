class CategoriaModel {
  final String id;
  final String nombre;
  final String icono;
  final bool disponible;
  final int orden;
  final bool requiereCocina;

  CategoriaModel({
    required this.id,
    required this.nombre,
    required this.icono,
    this.disponible = true,
    this.orden = 0,
    this.requiereCocina = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'icono': icono,
      'disponible': disponible,
      'orden': orden,
      'requiereCocina': requiereCocina,
    };
  }

  factory CategoriaModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoriaModel(
      id: id,
      nombre: data['nombre'] ?? '',
      icono: data['icono'] ?? '📦',
      disponible: data['disponible'] ?? true,
      orden: data['orden'] ?? 0,
      requiereCocina: data['requiereCocina'] ?? true,
    );
  }

  // Helpers
  bool get esPizza => nombre.toLowerCase().contains('pizza');
  bool get esBebida => nombre.toLowerCase().contains('bebida');
  bool get esCombo => nombre.toLowerCase().contains('combo');
}
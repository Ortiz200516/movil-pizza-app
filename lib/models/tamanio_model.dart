class TamanioModel {
  final String nombre;
  final int rebanadas;
  final double multiplicador;

  TamanioModel({
    required this.nombre,
    required this.rebanadas,
    required this.multiplicador,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'rebanadas': rebanadas,
      'multiplicador': multiplicador,
    };
  }

  factory TamanioModel.fromMap(Map<String, dynamic> data) {
    return TamanioModel(
      nombre: data['nombre'] ?? '',
      rebanadas: data['rebanadas'] ?? 12,
      multiplicador: (data['multiplicador'] ?? 1.0).toDouble(),
    );
  }

  // Tamaños predefinidos para pizzas
  static List<TamanioModel> tamaniosPizza = [
    TamanioModel(nombre: 'Pequeña', rebanadas: 6, multiplicador: 0.6),
    TamanioModel(nombre: 'Mediana', rebanadas: 8, multiplicador: 0.8),
    TamanioModel(nombre: 'Grande', rebanadas: 12, multiplicador: 1.0),
    TamanioModel(nombre: 'Familiar', rebanadas: 16, multiplicador: 1.3),
  ];
}
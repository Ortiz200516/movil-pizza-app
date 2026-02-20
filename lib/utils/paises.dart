class Paises {
  static const List<Map<String, String>> lista = [
    {'codigo': 'EC', 'nombre': 'Ecuador', 'bandera': '🇪🇨'},
    {'codigo': 'CO', 'nombre': 'Colombia', 'bandera': '🇨🇴'},
    {'codigo': 'PE', 'nombre': 'Perú', 'bandera': '🇵🇪'},
    {'codigo': 'AR', 'nombre': 'Argentina', 'bandera': '🇦🇷'},
    {'codigo': 'MX', 'nombre': 'México', 'bandera': '🇲🇽'},
    {'codigo': 'US', 'nombre': 'Estados Unidos', 'bandera': '🇺🇸'},
    {'codigo': 'ES', 'nombre': 'España', 'bandera': '🇪🇸'},
    {'codigo': 'VE', 'nombre': 'Venezuela', 'bandera': '🇻🇪'},
    {'codigo': 'CL', 'nombre': 'Chile', 'bandera': '🇨🇱'},
    {'codigo': 'BO', 'nombre': 'Bolivia', 'bandera': '🇧🇴'},
    {'codigo': 'PY', 'nombre': 'Paraguay', 'bandera': '🇵🇾'},
    {'codigo': 'UY', 'nombre': 'Uruguay', 'bandera': '🇺🇾'},
    {'codigo': 'BR', 'nombre': 'Brasil', 'bandera': '🇧🇷'},
    {'codigo': 'CR', 'nombre': 'Costa Rica', 'bandera': '🇨🇷'},
    {'codigo': 'PA', 'nombre': 'Panamá', 'bandera': '🇵🇦'},
    {'codigo': 'GT', 'nombre': 'Guatemala', 'bandera': '🇬🇹'},
    {'codigo': 'HN', 'nombre': 'Honduras', 'bandera': '🇭🇳'},
    {'codigo': 'SV', 'nombre': 'El Salvador', 'bandera': '🇸🇻'},
    {'codigo': 'NI', 'nombre': 'Nicaragua', 'bandera': '🇳🇮'},
    {'codigo': 'DO', 'nombre': 'República Dominicana', 'bandera': '🇩🇴'},
    {'codigo': 'CU', 'nombre': 'Cuba', 'bandera': '🇨🇺'},
    {'codigo': 'PR', 'nombre': 'Puerto Rico', 'bandera': '🇵🇷'},
  ];

  static String obtenerNombrePorCodigo(String codigo) {
    final pais = lista.firstWhere(
      (p) => p['codigo'] == codigo,
      orElse: () => {'nombre': codigo},
    );
    return pais['nombre']!;
  }

  static String obtenerBanderaPorCodigo(String codigo) {
    final pais = lista.firstWhere(
      (p) => p['codigo'] == codigo,
      orElse: () => {'bandera': '🌍'},
    );
    return pais['bandera']!;
  }
}
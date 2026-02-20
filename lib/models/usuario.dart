class Usuario {
  final String uid;
  final String email;
  final String rol;
  final String? nombre;
  final String? telefono;
  final Map<String, dynamic>? ubicacionActual;
  final bool? disponible;
  final String? cedula;
  final String? pais;

  Usuario({
    required this.uid,
    required this.email,
    required this.rol,
    this.nombre,
    this.telefono,
    this.ubicacionActual,
    this.disponible,
    this.cedula,
    this.pais,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'rol': rol,
      'nombre': nombre,
      'telefono': telefono,
      'ubicacionActual': ubicacionActual,
      'disponible': disponible,
      'cedula': cedula,
      'pais': pais,
    };
  }

  factory Usuario.fromFirestore(String uid, Map<String, dynamic> data) {
    return Usuario(
      uid: uid,
      email: data['email'] ?? '',
      rol: data['rol'] ?? 'cliente',
      nombre: data['nombre'],
      telefono: data['telefono'],
      ubicacionActual: data['ubicacionActual'] != null
          ? Map<String, dynamic>.from(data['ubicacionActual'])
          : null,
      disponible: data['disponible'],
      cedula: data['cedula'],
      pais: data['pais'],
    );
  }

  // Helper para mostrar información completa
  String get informacionCompleta {
    return '$nombre${cedula != null ? " - $pais: $cedula" : ""}';
  }

  // Helper para mostrar país con bandera
  String get paisConBandera {
    if (pais == null) return '';
    
    final banderas = {
      'EC': '🇪🇨',
      'CO': '🇨🇴',
      'PE': '🇵🇪',
      'AR': '🇦🇷',
      'MX': '🇲🇽',
      'US': '🇺🇸',
      'ES': '🇪🇸',
      'VE': '🇻🇪',
      'CL': '🇨🇱',
      'BO': '🇧🇴',
      'PY': '🇵🇾',
      'UY': '🇺🇾',
      'BR': '🇧🇷',
      'CR': '🇨🇷',
      'PA': '🇵🇦',
      'GT': '🇬🇹',
      'HN': '🇭🇳',
      'SV': '🇸🇻',
      'NI': '🇳🇮',
      'DO': '🇩🇴',
      'CU': '🇨🇺',
      'PR': '🇵🇷',
    };
    
    return '${banderas[pais] ?? '🌍'} $pais';
  }

  // Helper para mostrar cédula formateada
  String get cedulaFormateada {
    if (cedula == null || pais == null) return 'Sin cédula';
    return '$pais-$cedula';
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Estados de reserva ────────────────────────────────────────────────────────
// 'pendiente' → admin la confirma → 'confirmada'
// admin la rechaza → 'rechazada'
// cliente cancela → 'cancelada'
// llega la hora → 'completada'

class ReservaModel {
  final String  id;
  final String  clienteId;
  final String  clienteNombre;
  final String  clienteTelefono;
  final int     numeroMesa;
  final int     personas;
  final DateTime fecha;      // día de la reserva
  final String  hora;        // "19:30"
  final String  estado;      // pendiente|confirmada|rechazada|cancelada|completada
  final String? notasCliente;
  final String? notasAdmin;
  final DateTime creadaEn;

  const ReservaModel({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.numeroMesa,
    required this.personas,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.notasCliente,
    this.notasAdmin,
    required this.creadaEn,
  });

  factory ReservaModel.fromFirestore(String id, Map<String, dynamic> d) =>
      ReservaModel(
        id:               id,
        clienteId:        d['clienteId']        ?? '',
        clienteNombre:    d['clienteNombre']     ?? '',
        clienteTelefono:  d['clienteTelefono']   ?? '',
        numeroMesa:       (d['numeroMesa']  as int?) ?? 0,
        personas:         (d['personas']    as int?) ?? 1,
        fecha:            (d['fecha'] as Timestamp).toDate(),
        hora:             d['hora']               ?? '',
        estado:           d['estado']             ?? 'pendiente',
        notasCliente:     d['notasCliente']        as String?,
        notasAdmin:       d['notasAdmin']          as String?,
        creadaEn: (d['creadaEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'clienteId':       clienteId,
    'clienteNombre':   clienteNombre,
    'clienteTelefono': clienteTelefono,
    'numeroMesa':      numeroMesa,
    'personas':        personas,
    'fecha':           Timestamp.fromDate(fecha),
    'hora':            hora,
    'estado':          estado,
    'notasCliente':    notasCliente,
    'notasAdmin':      notasAdmin,
    'creadaEn':        FieldValue.serverTimestamp(),
  };

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get fechaCorta {
    final hoy     = DateTime.now();
    final manana  = hoy.add(const Duration(days: 1));
    if (fecha.year == hoy.year && fecha.month == hoy.month
        && fecha.day == hoy.day) return 'Hoy';
    if (fecha.year == manana.year && fecha.month == manana.month
        && fecha.day == manana.day) return 'Mañana';
    const meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month]}';
  }

  bool get esHoy {
    final hoy = DateTime.now();
    return fecha.year == hoy.year && fecha.month == hoy.month
        && fecha.day == hoy.day;
  }
}
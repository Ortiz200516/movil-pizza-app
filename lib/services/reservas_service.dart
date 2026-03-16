import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reserva_model.dart';

class ReservasService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Crear reserva (cliente) ───────────────────────────────────────────────
  Future<String?> crearReserva({
    required int     numeroMesa,
    required int     personas,
    required DateTime fecha,
    required String  hora,
    String?  notas,
    required String  telefono,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    // Verificar que la mesa no esté ya reservada en esa fecha/hora
    final conflicto = await _db.collection('reservas')
        .where('numeroMesa', isEqualTo: numeroMesa)
        .where('fecha', isEqualTo: Timestamp.fromDate(
            DateTime(fecha.year, fecha.month, fecha.day)))
        .where('hora', isEqualTo: hora)
        .where('estado', whereIn: ['pendiente', 'confirmada'])
        .get();

    if (conflicto.docs.isNotEmpty) return 'ocupada';

    final user = _auth.currentUser;
    final nombre = user?.displayName ?? user?.email ?? 'Cliente';

    final ref = await _db.collection('reservas').add({
      'clienteId':       uid,
      'clienteNombre':   nombre,
      'clienteTelefono': telefono,
      'numeroMesa':      numeroMesa,
      'personas':        personas,
      'fecha':           Timestamp.fromDate(
          DateTime(fecha.year, fecha.month, fecha.day)),
      'hora':            hora,
      'estado':          'pendiente',
      'notasCliente':    notas ?? '',
      'notasAdmin':      '',
      'creadaEn':        FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ── Reservas del cliente actual ───────────────────────────────────────────
  Stream<List<ReservaModel>> streamMisReservas() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('reservas')
        .where('clienteId', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ReservaModel.fromFirestore(d.id,
                d.data()))
            .toList());
  }

  // ── Cancelar reserva (cliente) ────────────────────────────────────────────
  Future<void> cancelarReserva(String id) async {
    await _db.collection('reservas').doc(id).update({
      'estado': 'cancelada',
    });
  }

  // ── Admin: todas las reservas ─────────────────────────────────────────────
  Stream<List<ReservaModel>> streamTodasReservas({String? estado}) {
    var q = _db.collection('reservas')
        .orderBy('fecha', descending: false) as Query;
    if (estado != null) q = q.where('estado', isEqualTo: estado);
    return q.snapshots().map((s) => s.docs
        .map((d) => ReservaModel.fromFirestore(d.id, d.data() as Map<String,dynamic>))
        .toList());
  }

  // ── Admin: reservas de hoy ────────────────────────────────────────────────
  Stream<List<ReservaModel>> streamReservasHoy() {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    return _db.collection('reservas')
        .where('fecha', isEqualTo: Timestamp.fromDate(inicio))
        .where('estado', whereIn: ['pendiente', 'confirmada'])
        .snapshots()
        .map((s) => s.docs
            .map((d) => ReservaModel.fromFirestore(d.id,
                d.data() as Map<String,dynamic>))
            .toList()
          ..sort((a, b) => a.hora.compareTo(b.hora)));
  }

  // ── Admin: confirmar / rechazar ───────────────────────────────────────────
  Future<void> confirmarReserva(String id, {String? nota}) async {
    await _db.collection('reservas').doc(id).update({
      'estado':      'confirmada',
      if (nota != null && nota.isNotEmpty) 'notasAdmin': nota,
    });
  }

  Future<void> rechazarReserva(String id, {String? motivo}) async {
    await _db.collection('reservas').doc(id).update({
      'estado':     'rechazada',
      if (motivo != null) 'notasAdmin': motivo,
    });
  }

  Future<void> completarReserva(String id) async {
    await _db.collection('reservas').doc(id).update({'estado': 'completada'});
  }

  // ── Mesas disponibles para fecha/hora ────────────────────────────────────
  Future<List<int>> mesasDisponibles(DateTime fecha, String hora) async {
    // Traer todas las mesas activas
    final mesasSnap = await _db.collection('mesas')
        .where('activa', isEqualTo: true).get();
    final todasMesas = mesasSnap.docs
        .map((d) => (d.data()['numero'] as int?) ?? 0)
        .where((n) => n > 0)
        .toList()..sort();

    // Reservas que conflictan en esa fecha/hora
    final reservadas = await _db.collection('reservas')
        .where('fecha', isEqualTo: Timestamp.fromDate(
            DateTime(fecha.year, fecha.month, fecha.day)))
        .where('hora', isEqualTo: hora)
        .where('estado', whereIn: ['pendiente', 'confirmada']).get();

    final ocupadas = reservadas.docs
        .map((d) => (d.data()['numeroMesa'] as int?) ?? 0)
        .toSet();

    return todasMesas.where((m) => !ocupadas.contains(m)).toList();
  }
}
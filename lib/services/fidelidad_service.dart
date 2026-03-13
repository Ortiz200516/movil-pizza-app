import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Niveles de fidelidad ──────────────────────────────────────────────────────
class NivelFidelidad {
  final String nombre;
  final String emoji;
  final int puntosMin;
  final int puntosMax;       // -1 = sin límite
  final double multiplicador; // multiplicador de puntos ganados
  final String colorHex;

  const NivelFidelidad({
    required this.nombre, required this.emoji,
    required this.puntosMin, required this.puntosMax,
    required this.multiplicador, required this.colorHex,
  });
}

const kNiveles = [
  NivelFidelidad(nombre: 'Bronce',   emoji: '🥉', puntosMin: 0,    puntosMax: 499,  multiplicador: 1.0, colorHex: 'CD7F32'),
  NivelFidelidad(nombre: 'Plata',    emoji: '🥈', puntosMin: 500,  puntosMax: 1499, multiplicador: 1.25, colorHex: 'A8A9AD'),
  NivelFidelidad(nombre: 'Oro',      emoji: '🥇', puntosMin: 1500, puntosMax: 3499, multiplicador: 1.5, colorHex: 'FFD700'),
  NivelFidelidad(nombre: 'Platino',  emoji: '💎', puntosMin: 3500, puntosMax: -1,   multiplicador: 2.0, colorHex: 'E5E4E2'),
];

NivelFidelidad nivelDePuntos(int puntos) {
  for (final n in kNiveles.reversed) {
    if (puntos >= n.puntosMin) return n;
  }
  return kNiveles.first;
}

// ── Reglas de acumulación ─────────────────────────────────────────────────────
// 1 punto por cada $1.00 gastado × multiplicador del nivel
int calcularPuntosGanados(double total, int puntosActuales) {
  final nivel = nivelDePuntos(puntosActuales);
  return (total * nivel.multiplicador).floor();
}

// Canje: 100 puntos = $1.00 de descuento
double puntosToDolares(int puntos) => puntos / 100.0;
int dolaresToPuntos(double dolares) => (dolares * 100).round();

// ── Servicio ──────────────────────────────────────────────────────────────────
class FidelidadService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Obtener puntos del usuario actual ──────────────────────────────────────
  Stream<Map<String, dynamic>> streamPuntos() {
    final uid = _uid;
    if (uid == null) return Stream.value({'puntos': 0, 'puntosHistorico': 0});
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final d = doc.data() ?? {};
      return {
        'puntos':           (d['puntosFidelidad']     ?? 0) as int,
        'puntosHistorico':  (d['puntosHistoricoTotal'] ?? 0) as int,
        'puntosCanjeados':  (d['puntosCanjeados']      ?? 0) as int,
      };
    });
  }

  Future<int> getPuntos() async {
    final uid = _uid;
    if (uid == null) return 0;
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['puntosFidelidad'] ?? 0) as int;
  }

  // ── Sumar puntos al completar un pedido ───────────────────────────────────
  Future<void> sumarPuntos(String pedidoId, double totalPedido) async {
    final uid = _uid;
    if (uid == null) return;

    // Evitar doble suma
    final docPedido = await _db.collection('pedidos').doc(pedidoId).get();
    if (docPedido.data()?['puntosOtorgados'] == true) return;

    final puntosActuales = await getPuntos();
    final puntosGanados  = calcularPuntosGanados(totalPedido, puntosActuales);

    // Transacción atómica
    await _db.runTransaction((txn) async {
      final userRef   = _db.collection('users').doc(uid);
      final pedidoRef = _db.collection('pedidos').doc(pedidoId);

      final userSnap = await txn.get(userRef);
      final actual   = (userSnap.data()?['puntosFidelidad']     ?? 0) as int;
      final historico = (userSnap.data()?['puntosHistoricoTotal'] ?? 0) as int;

      txn.update(userRef, {
        'puntosFidelidad':      actual + puntosGanados,
        'puntosHistoricoTotal': historico + puntosGanados,
      });
      txn.update(pedidoRef, {
        'puntosOtorgados': true,
        'puntosGanados':   puntosGanados,
      });
    });

    // Registrar en historial
    await _db.collection('users').doc(uid)
        .collection('historial_puntos').add({
      'tipo':      'ganado',
      'puntos':    puntosGanados,
      'pedidoId':  pedidoId,
      'total':     totalPedido,
      'fecha':     FieldValue.serverTimestamp(),
      'descripcion': 'Pedido completado — \$${totalPedido.toStringAsFixed(2)}',
    });
  }

  // ── Canjear puntos al confirmar pedido ────────────────────────────────────
  /// Devuelve true si se pudo canjear (puntos suficientes).
  Future<bool> canjearPuntos(int puntos) async {
    final uid = _uid;
    if (uid == null) return false;

    final puntosActuales = await getPuntos();
    if (puntosActuales < puntos) return false;

    await _db.runTransaction((txn) async {
      final ref  = _db.collection('users').doc(uid);
      final snap = await txn.get(ref);
      final act  = (snap.data()?['puntosFidelidad']  ?? 0) as int;
      final canjeados = (snap.data()?['puntosCanjeados'] ?? 0) as int;
      txn.update(ref, {
        'puntosFidelidad':  act - puntos,
        'puntosCanjeados':  canjeados + puntos,
      });
    });

    final dolares = puntosToDolares(puntos);
    await _db.collection('users').doc(uid)
        .collection('historial_puntos').add({
      'tipo':        'canjeado',
      'puntos':      -puntos,
      'descuento':   dolares,
      'fecha':       FieldValue.serverTimestamp(),
      'descripcion': 'Canje — descuento \$${dolares.toStringAsFixed(2)}',
    });

    return true;
  }

  // ── Revertir canje (si se cancela el pedido) ──────────────────────────────
  Future<void> revertirCanje(int puntos) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'puntosFidelidad': FieldValue.increment(puntos),
      'puntosCanjeados': FieldValue.increment(-puntos),
    });
  }

  // ── Historial de puntos ───────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamHistorial() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid)
        .collection('historial_puntos')
        .orderBy('fecha', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // ── Admin: dar puntos manualmente ─────────────────────────────────────────
  Future<void> darPuntosManual(String uid, int puntos, String motivo) async {
    await _db.runTransaction((txn) async {
      final ref  = _db.collection('users').doc(uid);
      final snap = await txn.get(ref);
      final act  = (snap.data()?['puntosFidelidad']     ?? 0) as int;
      final hist = (snap.data()?['puntosHistoricoTotal'] ?? 0) as int;
      txn.update(ref, {
        'puntosFidelidad':      act  + puntos,
        'puntosHistoricoTotal': hist + puntos,
      });
    });
    await _db.collection('users').doc(uid)
        .collection('historial_puntos').add({
      'tipo':        'manual',
      'puntos':      puntos,
      'fecha':       FieldValue.serverTimestamp(),
      'descripcion': motivo,
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import '../services/notificacion_service.dart';

class PedidoService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Crear pedido ─────────────────────────────────────────────
  Future<PedidoModel?> crearPedido({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double total,
    required String tipoPedido,
    Map<String, dynamic>? direccionEntrega,
    int? numeroMesa,
    String? notasEspeciales,
    String metodoPago = 'efectivo',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión');

      final userDoc  = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final nombre   = userData['nombres'] ?? userData['nombre'] ?? user.email ?? 'Cliente';
      final telefono = userData['telefono'];

      final pedido = PedidoModel(
        id: '', clienteId: user.uid, clienteNombre: nombre,
        clienteTelefono: telefono, clienteEmail: user.email,
        items: items, subtotal: subtotal, impuesto: subtotal * 0.15, total: total,
        tipoPedido: tipoPedido, estado: 'Pendiente', fecha: DateTime.now(),
        direccionEntrega: direccionEntrega, numeroMesa: numeroMesa,
        notasEspeciales: notasEspeciales, metodoPago: metodoPago,
      );

      final ref = await _db.collection('pedidos').add(pedido.toMap());

      // 🔔 Notificar al cocinero que llegó un nuevo pedido
      final desc = tipoPedido == 'mesa'
          ? 'Mesa $numeroMesa · \$${total.toStringAsFixed(2)}'
          : 'Domicilio · \$${total.toStringAsFixed(2)}';
      await NotificacionService.notificarRol(
        rol: 'cocinero',
        titulo: '🍕 Nuevo pedido de $nombre',
        cuerpo: desc,
        tipo: 'pedido',
        datos: {'pedidoId': ref.id},
      );

      return PedidoModel.fromFirestore(ref.id,
          {...pedido.toMap(), 'id': ref.id,
           'codigoVerificacion': pedido.codigoVerificacion});
    } catch (e) {
      return null;
    }
  }

  // ── Streams ──────────────────────────────────────────────────
  Stream<List<PedidoModel>> obtenerMisPedidos() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('pedidos')
        .where('clienteId', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<PedidoModel>> obtenerTodosPedidos() =>
      _db.collection('pedidos').orderBy('fecha', descending: true).snapshots()
          .map((s) => s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList());

  Stream<List<PedidoModel>> obtenerPedidosActivos() =>
      _db.collection('pedidos')
          .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo', 'En camino'])
          .snapshots()
          .map((s) {
            final l = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
            l.sort((a, b) => a.fecha.compareTo(b.fecha));
            return l;
          });

  Stream<List<PedidoModel>> obtenerPedidosPorEstado(String estado) =>
      _db.collection('pedidos').where('estado', isEqualTo: estado).snapshots()
          .map((s) {
            final l = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
            l.sort((a, b) => a.fecha.compareTo(b.fecha));
            return l;
          });

  Stream<List<PedidoModel>> obtenerPedidosMesa() =>
      _db.collection('pedidos')
          .where('tipoPedido', isEqualTo: 'mesa')
          .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
          .snapshots()
          .map((s) {
            final l = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
            l.sort((a, b) => a.fecha.compareTo(b.fecha));
            return l;
          });

  Stream<List<PedidoModel>> obtenerPedidosDomicilio() =>
      _db.collection('pedidos')
          .where('tipoPedido', isEqualTo: 'domicilio')
          .where('estado', whereIn: ['Listo', 'En camino'])
          .snapshots()
          .map((s) {
            final l = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
            l.sort((a, b) => a.fecha.compareTo(b.fecha));
            return l;
          });

  // ── Actualizar estado + notificaciones automáticas ───────────
  Future<bool> actualizarEstado(String pedidoId, String nuevoEstado) async {
    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'estado': nuevoEstado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      // Leer pedido para saber a quién notificar
      final doc    = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return true;
      final pedido = PedidoModel.fromFirestore(doc.id, doc.data()!);

      switch (nuevoEstado) {
        case 'Preparando':
          // Notificar al cliente: su pedido está en cocina
          await NotificacionService.notificarUsuario(
            uid: pedido.clienteId,
            titulo: '👨‍🍳 ¡Tu pedido está en preparación!',
            cuerpo: 'Ya estamos cocinando tu pedido.',
            tipo: 'preparando',
            datos: {'pedidoId': pedidoId},
          );
          break;

        case 'Listo':
          if (pedido.tipoPedido == 'domicilio') {
            // Notificar a repartidores disponibles
            await NotificacionService.notificarRol(
              rol: 'repartidor',
              titulo: '✅ Pedido listo para recoger',
              cuerpo: '${pedido.clienteNombre} · \$${pedido.total.toStringAsFixed(2)}',
              tipo: 'listo',
              datos: {'pedidoId': pedidoId},
            );
          } else {
            // Mesa: notificar al mesero
            await NotificacionService.notificarRol(
              rol: 'mesero',
              titulo: '✅ Mesa ${pedido.numeroMesa} lista para servir',
              cuerpo: pedido.clienteNombre,
              tipo: 'listo',
              datos: {'pedidoId': pedidoId},
            );
            // Y al cliente
            await NotificacionService.notificarUsuario(
              uid: pedido.clienteId,
              titulo: '✅ ¡Tu pedido está listo!',
              cuerpo: 'El mesero lo llevará en un momento.',
              tipo: 'listo',
            );
          }
          break;

        case 'En camino':
          // Notificar al cliente que el repartidor ya salió
          await NotificacionService.notificarUsuario(
            uid: pedido.clienteId,
            titulo: '🛵 ¡Tu pedido está en camino!',
            cuerpo: 'Puedes ver al repartidor en el mapa en tiempo real.',
            tipo: 'camino',
            datos: {'pedidoId': pedidoId},
          );
          break;

        case 'Entregado':
          await NotificacionService.notificarUsuario(
            uid: pedido.clienteId,
            titulo: '📦 ¡Pedido entregado!',
            cuerpo: 'Gracias por tu compra. ¡Buen provecho!',
            tipo: 'entregado',
          );
          break;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> cambiarEstado(String pedidoId, String estado) async =>
      actualizarEstado(pedidoId, estado);

  // ── Asignar repartidor ────────────────────────────────────────
  Future<bool> asignarRepartidor(String pedidoId, String repartidorId) async {
    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'repartidorId': repartidorId,
        'estado': 'En camino',
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      // Notificar al cliente (se dispara desde actualizarEstado vía trigger,
      // pero lo hacemos explícito aquí también)
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (doc.exists) {
        final p = PedidoModel.fromFirestore(doc.id, doc.data()!);
        await NotificacionService.notificarUsuario(
          uid: p.clienteId,
          titulo: '🛵 ¡Tu pedido está en camino!',
          cuerpo: 'Puedes ver al repartidor en el mapa en tiempo real.',
          tipo: 'camino',
          datos: {'pedidoId': pedidoId},
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Verificar código y marcar entregado ───────────────────────
  Future<bool> verificarCodigoEntrega(String pedidoId, String codigo) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return false;
      final p = PedidoModel.fromFirestore(doc.id, doc.data()!);
      if (p.codigoVerificacion == codigo.trim()) {
        await _db.collection('pedidos').doc(pedidoId).update({'verificado': true});
        return true;
      }
      return false;
    } catch (_) { return false; }
  }

  Future<bool> marcarEntregadoDomicilio(String pedidoId, String codigo) async {
    final ok = await verificarCodigoEntrega(pedidoId, codigo);
    if (!ok) return false;
    return actualizarEstado(pedidoId, 'Entregado');
  }

  // ── Helpers ───────────────────────────────────────────────────
  Future<PedidoModel?> obtenerPedidoPorId(String pedidoId) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return null;
      return PedidoModel.fromFirestore(doc.id, doc.data()!);
    } catch (_) { return null; }
  }

  Future<bool> cancelarPedido(String pedidoId) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return false;
      final p = PedidoModel.fromFirestore(doc.id, doc.data()!);
      if (p.estado != 'Pendiente') return false;
      return actualizarEstado(pedidoId, 'Cancelado');
    } catch (_) { return false; }
  }
}
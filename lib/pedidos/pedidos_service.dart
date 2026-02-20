import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';

class PedidoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Crear pedido nuevo - retorna el PedidoModel con el código generado
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

      // Obtener datos del cliente desde Firestore
      final userDoc = await _db.collection('usuarios').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final nombreCliente = userData['nombres'] ?? userData['nombre'] ?? user.email ?? 'Cliente';
      final telefonoCliente = userData['telefono'];

      final pedido = PedidoModel(
        id: '',
        clienteId: user.uid,
        clienteNombre: nombreCliente,
        clienteTelefono: telefonoCliente,
        clienteEmail: user.email,
        items: items,
        subtotal: subtotal,
        impuesto: subtotal * 0.15,
        total: total,
        tipoPedido: tipoPedido,
        estado: 'Pendiente',
        fecha: DateTime.now(),
        direccionEntrega: direccionEntrega,
        numeroMesa: numeroMesa,
        notasEspeciales: notasEspeciales,
        metodoPago: metodoPago,
      );

      final docRef = await _db.collection('pedidos').add(pedido.toMap());
      return pedido.copyWith(); // Retorna con código generado
    } catch (e) {
      print('Error al crear pedido: $e');
      return null;
    }
  }

  // Pedidos del cliente actual en tiempo real
  Stream<List<PedidoModel>> obtenerMisPedidos() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _db.collection('pedidos')
        .where('clienteId', isEqualTo: user.uid)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList());
  }

  // Todos los pedidos (admin)
  Stream<List<PedidoModel>> obtenerTodosPedidos() {
    return _db.collection('pedidos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList());
  }

  // Pedidos activos para admin (sin orderBy doble para evitar índice compuesto)
  Stream<List<PedidoModel>> obtenerPedidosActivos() {
    return _db.collection('pedidos')
        .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo', 'En camino'])
        .snapshots()
        .map((s) {
          final lista = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
          lista.sort((a, b) => a.fecha.compareTo(b.fecha));
          return lista;
        });
  }

  // Pedidos por estado (cocina, mesero)
  Stream<List<PedidoModel>> obtenerPedidosPorEstado(String estado) {
    return _db.collection('pedidos')
        .where('estado', isEqualTo: estado)
        .snapshots()
        .map((s) {
          final lista = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
          lista.sort((a, b) => a.fecha.compareTo(b.fecha));
          return lista;
        });
  }

  // Pedidos de mesa para mesero
  Stream<List<PedidoModel>> obtenerPedidosMesa() {
    return _db.collection('pedidos')
        .where('tipoPedido', isEqualTo: 'mesa')
        .where('estado', whereIn: ['Pendiente', 'Preparando', 'Listo'])
        .snapshots()
        .map((s) {
          final lista = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
          lista.sort((a, b) => a.fecha.compareTo(b.fecha));
          return lista;
        });
  }

  // Pedidos de domicilio para repartidor
  Stream<List<PedidoModel>> obtenerPedidosDomicilio() {
    return _db.collection('pedidos')
        .where('tipoPedido', isEqualTo: 'domicilio')
        .where('estado', whereIn: ['Listo', 'En camino'])
        .snapshots()
        .map((s) {
          final lista = s.docs.map((d) => PedidoModel.fromFirestore(d.id, d.data())).toList();
          lista.sort((a, b) => a.fecha.compareTo(b.fecha));
          return lista;
        });
  }

  // Actualizar estado del pedido
  Future<bool> actualizarEstado(String pedidoId, String nuevoEstado) async {
    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'estado': nuevoEstado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error al actualizar estado: $e');
      return false;
    }
  }

  // Alias para compatibilidad con código anterior
  Future<void> cambiarEstado(String pedidoId, String estado) async {
    await actualizarEstado(pedidoId, estado);
  }

  // Asignar repartidor
  Future<bool> asignarRepartidor(String pedidoId, String repartidorId) async {
    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'repartidorId': repartidorId,
        'estado': 'En camino',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verificar código de entrega del repartidor
  Future<bool> verificarCodigoEntrega(String pedidoId, String codigoIngresado) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return false;
      final pedido = PedidoModel.fromFirestore(doc.id, doc.data()!);
      if (pedido.codigoVerificacion == codigoIngresado.trim()) {
        await _db.collection('pedidos').doc(pedidoId).update({'verificado': true});
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Marcar pedido entregado (domicilio - requiere verificación previa)
  Future<bool> marcarEntregadoDomicilio(String pedidoId, String codigoIngresado) async {
    final codigoOk = await verificarCodigoEntrega(pedidoId, codigoIngresado);
    if (!codigoOk) return false;
    return actualizarEstado(pedidoId, 'Entregado');
  }

  // Obtener pedido por ID
  Future<PedidoModel?> obtenerPedidoPorId(String pedidoId) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return null;
      return PedidoModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      return null;
    }
  }

  // Cancelar pedido (solo si está Pendiente)
  Future<bool> cancelarPedido(String pedidoId) async {
    try {
      final doc = await _db.collection('pedidos').doc(pedidoId).get();
      if (!doc.exists) return false;
      final pedido = PedidoModel.fromFirestore(doc.id, doc.data()!);
      if (pedido.estado != 'Pendiente') return false;
      return actualizarEstado(pedidoId, 'Cancelado');
    } catch (e) {
      return false;
    }
  }
}
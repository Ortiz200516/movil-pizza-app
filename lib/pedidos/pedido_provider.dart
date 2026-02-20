import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import 'pedidos_service.dart';

class PedidoProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _ultimoPedidoId;
  String? get ultimoPedidoId => _ultimoPedidoId;
  PedidoModel? _ultimoPedido;
  PedidoModel? get ultimoPedido => _ultimoPedido;

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
    _isLoading = true;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión');
      final service = PedidoService();
      final pedido = await service.crearPedido(
        items: items,
        subtotal: subtotal,
        total: total,
        tipoPedido: tipoPedido,
        direccionEntrega: direccionEntrega,
        numeroMesa: numeroMesa,
        notasEspeciales: notasEspeciales,
        metodoPago: metodoPago,
      );
      if (pedido != null) {
        _ultimoPedidoId = pedido.id;
        _ultimoPedido = pedido;
      }
      return pedido;
    } catch (e) {
      print('Error al crear pedido: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<PedidoModel>> obtenerMisPedidos() {
    return PedidoService().obtenerMisPedidos();
  }
}
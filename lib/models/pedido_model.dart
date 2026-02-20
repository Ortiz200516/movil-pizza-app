import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PedidoModel {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteEmail;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double impuesto;
  final double total;
  final String tipoPedido; // 'mesa' o 'domicilio'
  final String estado; // 'Pendiente','Preparando','Listo','En camino','Entregado','Cancelado'
  final DateTime fecha;
  final String? repartidorId;
  final String? meseroId;
  final Map<String, dynamic>? direccionEntrega;
  final int? numeroMesa;
  final String codigoVerificacion;
  final bool verificado;
  final String? notasEspeciales;
  final String metodoPago;

  PedidoModel({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteEmail,
    required this.items,
    required this.subtotal,
    this.impuesto = 0.0,
    required this.total,
    required this.tipoPedido,
    this.estado = 'Pendiente',
    required this.fecha,
    this.repartidorId,
    this.meseroId,
    this.direccionEntrega,
    this.numeroMesa,
    String? codigoVerificacion,
    this.verificado = false,
    this.notasEspeciales,
    this.metodoPago = 'efectivo',
  }) : codigoVerificacion = codigoVerificacion ?? _genCodigo();

  static String _genCodigo() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  int get cantidadItems => items.fold(0, (s, i) => s + (i['cantidad'] as int? ?? 0));

  String get iconoEstado {
    switch (estado) {
      case 'Pendiente': return '🕐';
      case 'Preparando': return '👨‍🍳';
      case 'Listo': return '✅';
      case 'En camino': return '🛵';
      case 'Entregado': return '📦';
      case 'Cancelado': return '❌';
      default: return '📋';
    }
  }

  Map<String, dynamic> toMap() => {
    'clienteId': clienteId, 'clienteNombre': clienteNombre,
    'clienteTelefono': clienteTelefono, 'clienteEmail': clienteEmail,
    'items': items, 'subtotal': subtotal, 'impuesto': impuesto, 'total': total,
    'tipoPedido': tipoPedido, 'estado': estado,
    'fecha': Timestamp.fromDate(fecha),
    'repartidorId': repartidorId, 'meseroId': meseroId,
    'direccionEntrega': direccionEntrega, 'numeroMesa': numeroMesa,
    'codigoVerificacion': codigoVerificacion, 'verificado': verificado,
    'notasEspeciales': notasEspeciales, 'metodoPago': metodoPago,
    // Compatibilidad con campos viejos
    'userId': clienteId, 'email': clienteEmail,
  };

  factory PedidoModel.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['fecha'];
    DateTime fecha;
    if (ts is Timestamp) {
      fecha = ts.toDate();
    } else {
      fecha = DateTime.now();
    }
    return PedidoModel(
      id: id,
      clienteId: data['clienteId'] ?? data['userId'] ?? '',
      clienteNombre: data['clienteNombre'] ?? 'Cliente',
      clienteTelefono: data['clienteTelefono'],
      clienteEmail: data['clienteEmail'] ?? data['email'],
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      subtotal: (data['subtotal'] ?? data['total'] ?? 0.0).toDouble(),
      impuesto: (data['impuesto'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      tipoPedido: data['tipoPedido'] ?? data['tipo'] ?? 'mesa',
      estado: data['estado'] ?? 'Pendiente',
      fecha: fecha,
      repartidorId: data['repartidorId'],
      meseroId: data['meseroId'],
      direccionEntrega: data['direccionEntrega'] != null
          ? Map<String, dynamic>.from(data['direccionEntrega']) : null,
      numeroMesa: data['numeroMesa'],
      codigoVerificacion: data['codigoVerificacion'] ?? _genCodigo(),
      verificado: data['verificado'] ?? false,
      notasEspeciales: data['notasEspeciales'],
      metodoPago: data['metodoPago'] ?? 'efectivo',
    );
  }

  PedidoModel copyWith({String? estado, String? repartidorId, String? meseroId, bool? verificado}) {
    return PedidoModel(
      id: id, clienteId: clienteId, clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono, clienteEmail: clienteEmail,
      items: items, subtotal: subtotal, impuesto: impuesto, total: total,
      tipoPedido: tipoPedido, estado: estado ?? this.estado, fecha: fecha,
      repartidorId: repartidorId ?? this.repartidorId,
      meseroId: meseroId ?? this.meseroId,
      direccionEntrega: direccionEntrega, numeroMesa: numeroMesa,
      codigoVerificacion: codigoVerificacion, verificado: verificado ?? this.verificado,
      notasEspeciales: notasEspeciales, metodoPago: metodoPago,
    );
  }

  // ── Getters de compatibilidad con código anterior ──
  bool get esDomicilio => tipoPedido == 'domicilio';
  bool get esLocal => tipoPedido == 'mesa';
  String? get mesaNumero => numeroMesa?.toString();
  String get userId => clienteId;
}
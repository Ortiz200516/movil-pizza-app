import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

class ExportarService {
  static Future<void> exportarPedidosCSV({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .orderBy('fecha', descending: true)
        .get();

    final pedidos = snap.docs
        .map((d) => PedidoModel.fromFirestore(d.id, d.data()))
        .toList();

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('ID,Fecha,Cliente,Tipo,Mesa,Estado,Método Pago,'
        'Subtotal,IVA,Total,Items');

    for (final p in pedidos) {
      final items = p.items
          .map((i) => '${i['cantidad']}x ${i['productoNombre'] ?? ''}')
          .join(' | ');
      final fecha = '${p.fecha.day.toString().padLeft(2, '0')}/'
          '${p.fecha.month.toString().padLeft(2, '0')}/'
          '${p.fecha.year} '
          '${p.fecha.hour.toString().padLeft(2, '0')}:'
          '${p.fecha.minute.toString().padLeft(2, '0')}';

      buffer.writeln([
        p.id.substring(0, 8),
        fecha,
        _escapeCsv(p.clienteNombre),
        p.tipoPedido,
        p.numeroMesa?.toString() ?? '',
        p.estado,
        p.metodoPago,
        p.subtotal.toStringAsFixed(2),
        p.impuesto.toStringAsFixed(2),
        p.total.toStringAsFixed(2),
        _escapeCsv(items),
      ].join(','));
    }

    _descargar(
      contenido: buffer.toString(),
      nombre: 'pedidos_${_fechaNombre(desde)}_${_fechaNombre(hasta)}.csv',
      tipo: 'text/csv;charset=utf-8',
    );
  }

  static Future<void> exportarResumenCSV({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .where('estado', isEqualTo: 'Entregado')
        .get();

    final pedidos = snap.docs
        .map((d) => PedidoModel.fromFirestore(d.id, d.data()))
        .toList();

    final Map<String, int> productos = {};
    for (final p in pedidos) {
      for (final item in p.items) {
        final nombre = item['productoNombre'] as String? ?? 'N/A';
        productos[nombre] =
            (productos[nombre] ?? 0) + ((item['cantidad'] ?? 1) as int);
      }
    }
    final topProds = productos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalVentas = pedidos.fold(0.0, (s, p) => s + p.total);
    final ticketProm = pedidos.isEmpty ? 0.0 : totalVentas / pedidos.length;

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('RESUMEN DE VENTAS');
    buffer.writeln('Período,${_fechaNombre(desde)} al ${_fechaNombre(hasta)}');
    buffer.writeln('Total ventas,\$${totalVentas.toStringAsFixed(2)}');
    buffer.writeln('Pedidos entregados,${pedidos.length}');
    buffer.writeln('Ticket promedio,\$${ticketProm.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('TOP PRODUCTOS');
    buffer.writeln('Producto,Cantidad vendida');
    for (final e in topProds.take(20)) {
      buffer.writeln('${_escapeCsv(e.key)},${e.value}');
    }

    _descargar(
      contenido: buffer.toString(),
      nombre: 'resumen_${_fechaNombre(desde)}_${_fechaNombre(hasta)}.csv',
      tipo: 'text/csv;charset=utf-8',
    );
  }

  static void _descargar({
    required String contenido,
    required String nombre,
    required String tipo,
  }) {
    final bytes = utf8.encode(contenido);
    final blob = html.Blob([bytes], tipo);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', nombre)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _fechaNombre(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import 'tracking_page.dart';

class MisPedidosPage extends StatelessWidget {
  const MisPedidosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Debes iniciar sesión', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: user.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📋', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text('No tienes pedidos aún',
                style: TextStyle(fontSize: 20, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('¡Haz tu primer pedido!', style: TextStyle(color: Colors.grey.shade600)),
          ]));
        }

        final pedidos = snapshot.data!.docs
            .map((doc) => PedidoModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        final enProceso = pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
        final entregados = pedidos.where((p) => p.estado == 'Entregado').length;

        return Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            color: const Color(0xFF0F172A),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Stat('Total', pedidos.length.toString(), Icons.receipt_long, Colors.blue),
              _Stat('En proceso', enProceso.toString(), Icons.pending, Colors.orange),
              _Stat('Entregados', entregados.toString(), Icons.check_circle, Colors.green),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: pedidos.length,
              itemBuilder: (_, i) => _PedidoCard(pedido: pedidos[i]),
            ),
          ),
        ]);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    ),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

class _PedidoCard extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoCard({required this.pedido});

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'Pendiente':  return Colors.orange;
      case 'Preparando': return Colors.blue;
      case 'Listo':      return Colors.purple;
      case 'En camino':  return Colors.indigo;
      case 'Entregado':  return Colors.green;
      case 'Cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  IconData get _iconoEstado {
    switch (pedido.estado) {
      case 'Pendiente':  return Icons.access_time;
      case 'Preparando': return Icons.restaurant;
      case 'Listo':      return Icons.done_all;
      case 'En camino':  return Icons.delivery_dining;
      case 'Entregado':  return Icons.check_circle;
      case 'Cancelado':  return Icons.cancel;
      default:           return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado;
    final esDomicilio = pedido.tipoPedido == 'domicilio';
    final esCancelado = pedido.estado == 'Cancelado';
    final esActivo = !esCancelado && pedido.estado != 'Entregado';

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DetalleSheet(pedido: pedido),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_iconoEstado, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(pedido.estado,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ]),
                ),
                const Spacer(),
                Text(_formatFecha(pedido.fecha),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(esDomicilio ? Icons.delivery_dining : Icons.table_restaurant,
                    size: 15, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    esDomicilio
                        ? (pedido.direccionEntrega?['direccion'] ?? 'Domicilio')
                        : 'Mesa ${pedido.numeroMesa ?? ""}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                pedido.items.map((i) {
                  final n = i['productoNombre'] ?? i['nombre'] ?? 'Producto';
                  final c = i['cantidad'] ?? 1;
                  return c > 1 ? '${c}× $n' : n;
                }).join(', '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text('\$${pedido.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                const Spacer(),
                Text('Ver detalle →', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
            ]),
          ),

          // Código de verificación
          if (esDomicilio && esActivo && pedido.codigoVerificacion.isNotEmpty)
            _CodigoVerificacion(codigo: pedido.codigoVerificacion),

          // Timeline
          if (!esCancelado)
            _Timeline(estadoActual: pedido.estado, esDomicilio: esDomicilio),

          // Banner en camino
          if (pedido.estado == 'En camino' && esDomicilio)
            _BannerEnCamino(pedido: pedido),

          // Botón ver repartidor en mapa
          if (pedido.estado == 'En camino' && esDomicilio && pedido.repartidorId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TrackingClientePage(pedido: pedido))),
                  icon: const Icon(Icons.location_on),
                  label: const Text('VER REPARTIDOR EN MAPA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  String _formatFecha(DateTime f) {
    final diff = DateTime.now().difference(f);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${f.day}/${f.month}/${f.year}';
  }
}

// ── Código de verificación ────────────────────────────────────
class _CodigoVerificacion extends StatelessWidget {
  final String codigo;
  const _CodigoVerificacion({required this.codigo});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
    ),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.lock, size: 14, color: Colors.orange),
        const SizedBox(width: 6),
        const Text('Código de verificación',
            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: codigo));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado ✅'), duration: Duration(seconds: 1)));
          },
          child: Row(children: [
            const Icon(Icons.copy, size: 13, color: Colors.orange),
            const SizedBox(width: 3),
            Text('Copiar', style: TextStyle(fontSize: 11, color: Colors.orange.shade300)),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Text(codigo,
          style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.bold,
              letterSpacing: 12, color: Colors.orange)),
      const SizedBox(height: 6),
      Text('⚠️ Dáselo al repartidor solo cuando recibas tu pedido.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400), textAlign: TextAlign.center),
    ]),
  );
}

// ── Timeline de estados ───────────────────────────────────────
class _Timeline extends StatelessWidget {
  final String estadoActual;
  final bool esDomicilio;
  const _Timeline({required this.estadoActual, required this.esDomicilio});

  @override
  Widget build(BuildContext context) {
    final pasos = esDomicilio
        ? [('Pendiente','⏳','Recibido'), ('Preparando','👨‍🍳','Cocina'),
           ('Listo','✅','Listo'), ('En camino','🛵','En camino'), ('Entregado','🏠','Entregado')]
        : [('Pendiente','⏳','Recibido'), ('Preparando','👨‍🍳','Cocina'),
           ('Listo','✅','Listo'), ('Entregado','🍽️','Servido')];

    final idxActual = pasos.indexWhere((p) => p.$1 == estadoActual);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: List.generate(pasos.length * 2 - 1, (i) {
          if (i.isOdd) {
            final completado = (i ~/ 2) < idxActual;
            return Expanded(child: Container(
              height: 2, color: completado ? Colors.orange : Colors.grey.shade800));
          }
          final idx = i ~/ 2;
          final (_, emoji, label) = pasos[idx];
          final completado = idx < idxActual;
          final actual = idx == idxActual;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: completado ? Colors.orange : actual ? Colors.orange.withOpacity(0.2) : Colors.grey.shade800,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (completado || actual) ? Colors.orange : Colors.grey.shade700,
                  width: actual ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: completado
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text(emoji, style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  color: (completado || actual) ? Colors.orange : Colors.grey.shade600,
                  fontWeight: actual ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center),
          ]);
        }),
      ),
    );
  }
}

// ── Banner en camino ─────────────────────────────────────────
class _BannerEnCamino extends StatelessWidget {
  final PedidoModel pedido;
  const _BannerEnCamino({required this.pedido});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.indigo.shade900, Colors.indigo.shade700],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Text('🛵', style: TextStyle(fontSize: 30)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('¡Tu pedido está en camino!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 3),
        Text(pedido.direccionEntrega?['direccion'] ?? '',
            style: TextStyle(color: Colors.indigo.shade200, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        const Text('El repartidor llegará pronto 🔔',
            style: TextStyle(color: Colors.white60, fontSize: 11)),
      ])),
    ]),
  );
}

// ── Sheet de detalle completo ────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final PedidoModel pedido;
  const _DetalleSheet({required this.pedido});
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Detalle del pedido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
              _DetalleRow(Icons.info_outline, 'Estado', pedido.estado, Colors.blue),
              _DetalleRow(
                pedido.tipoPedido == 'domicilio' ? Icons.delivery_dining : Icons.table_restaurant,
                'Tipo', pedido.tipoPedido == 'domicilio' ? 'Domicilio' : 'Mesa ${pedido.numeroMesa ?? ""}',
                Colors.orange),
              _DetalleRow(Icons.calendar_today, 'Fecha',
                '${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year}  '
                '${pedido.fecha.hour}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                Colors.purple),
              if (pedido.direccionEntrega != null)
                _DetalleRow(Icons.location_on, 'Dirección',
                    pedido.direccionEntrega!['direccion'] ?? '', Colors.red),
              _DetalleRow(Icons.payment, 'Pago', pedido.metodoPago, Colors.teal),

              if (pedido.tipoPedido == 'domicilio' &&
                  pedido.estado != 'Entregado' && pedido.estado != 'Cancelado' &&
                  pedido.codigoVerificacion.isNotEmpty) ...[
                const SizedBox(height: 16),
                _CodigoVerificacion(codigo: pedido.codigoVerificacion),
              ],

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              const Text('Productos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),

              ...pedido.items.map((item) {
                final nombre = item['productoNombre'] ?? item['nombre'] ?? 'Producto';
                final cantidad = (item['cantidad'] ?? 1) as int;
                final precio = ((item['precioTotal'] ?? item['precio'] ?? 0) as num).toDouble();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('🍕', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      Text('Cantidad: $cantidad',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ])),
                    Text('\$${precio.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
                );
              }),

              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTAL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('\$${pedido.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetalleRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DetalleRow(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      ])),
    ]),
  );
}
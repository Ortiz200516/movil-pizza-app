import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';
import '../tracking/tracking_page.dart';

class MisPedidosPage extends StatelessWidget {
  const MisPedidosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Debes iniciar sesión para ver tus pedidos'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('userId', isEqualTo: user.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 100, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No tienes pedidos aún',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¡Haz tu primer pedido!',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final pedidos = snapshot.data!.docs.map((doc) {
          return PedidoModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        return Column(
          children: [
            // Header con estadísticas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    'Total',
                    pedidos.length.toString(),
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                  _buildStatChip(
                    'En proceso',
                    pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                  _buildStatChip(
                    'Entregados',
                    pedidos.where((p) => p.estado == 'Entregado').length.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ],
              ),
            ),

            // Lista de pedidos
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pedidos.length,
                itemBuilder: (context, index) {
                  final pedido = pedidos[index];
                  return _buildPedidoCard(context, pedido);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPedidoCard(BuildContext context, PedidoModel pedido) {
    // Determinar color según estado
    Color estadoColor;
    IconData estadoIcon;
    
    switch (pedido.estado.toLowerCase()) {
      case 'pendiente':
        estadoColor = Colors.orange;
        estadoIcon = Icons.pending;
        break;
      case 'en preparación':
      case 'en preparacion':
        estadoColor = Colors.blue;
        estadoIcon = Icons.restaurant;
        break;
      case 'listo':
        estadoColor = Colors.purple;
        estadoIcon = Icons.done_all;
        break;
      case 'en camino':
        estadoColor = Colors.indigo;
        estadoIcon = Icons.delivery_dining;
        break;
      case 'entregado':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case 'cancelado':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help_outline;
    }

    // Verificar si se puede mostrar tracking
    final puedeVerTracking = pedido.estado.toLowerCase() == 'en camino' && 
                             pedido.esDomicilio &&
                             pedido.direccionEntrega != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mostrarDetallePedido(context, pedido),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del pedido
              Row(
                children: [
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 14, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          pedido.estado,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Fecha
                  Text(
                    _formatearFecha(pedido.fecha),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Tipo de pedido
              Row(
                children: [
                  Icon(
                    pedido.esDomicilio ? Icons.delivery_dining : Icons.store,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pedido.esDomicilio ? 'Domicilio' : 'Local',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Productos (compacto)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _obtenerResumenProductos(pedido.items),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pedido.items.length} ${pedido.items.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Total y botón de tracking
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${pedido.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  
                  // Botón de tracking (solo si está en camino)
                  if (puedeVerTracking)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrackingPage(pedido: pedido),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Ver Mapa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    if (diferencia.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  String _obtenerResumenProductos(List<dynamic> items) {
    if (items.isEmpty) return 'Sin productos';
    
    final nombres = items.map((p) {
      final nombre = p['nombre'] ?? 'Producto';
      final cantidad = p['cantidad'] ?? 1;
      return cantidad > 1 ? '$cantidad x $nombre' : nombre;
    }).toList();
    
    return nombres.join(', ');
  }

  void _mostrarDetallePedido(BuildContext context, PedidoModel pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Detalle del Pedido',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Contenido
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Estado
                    _buildDetalleRow(
                      'Estado',
                      pedido.estado,
                      Icons.info_outline,
                      Colors.blue,
                    ),
                    
                    // Tipo
                    _buildDetalleRow(
                      'Tipo de pedido',
                      pedido.esDomicilio ? 'Domicilio' : 'Local',
                      pedido.esDomicilio ? Icons.delivery_dining : Icons.store,
                      Colors.orange,
                    ),
                    
                    // Fecha
                    _buildDetalleRow(
                      'Fecha',
                      '${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year} ${pedido.fecha.hour}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                      Icons.calendar_today,
                      Colors.purple,
                    ),
                    
                    if (pedido.direccionEntrega != null) ...[
                      _buildDetalleRow(
                        'Dirección',
                        pedido.direccionEntrega!['direccion'] ?? 'Sin dirección',
                        Icons.location_on,
                        Colors.red,
                      ),
                    ],
                    
                    if (pedido.mesaNumero != null) ...[
                      _buildDetalleRow(
                        'Mesa',
                        'Mesa ${pedido.mesaNumero}',
                        Icons.table_restaurant,
                        Colors.green,
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Productos
                    const Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ...pedido.items.map((producto) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto['nombre'] ?? 'Producto',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Cantidad: ${producto['cantidad'] ?? 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${((producto['precio'] ?? 0) * (producto['cantidad'] ?? 1)).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${pedido.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    
                    // Botón de tracking (si aplica)
                    if (pedido.estado.toLowerCase() == 'en camino' && pedido.esDomicilio) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackingPage(pedido: pedido),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Ver Ubicación en Tiempo Real'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
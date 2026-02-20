import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CocinaPage extends StatelessWidget {
  const CocinaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍🍳 Vista de Cocina'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
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
                  const Icon(Icons.error, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay pedidos',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final pedidos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              final data = pedido.data() as Map<String, dynamic>;
              final List items = data['items'] ?? [];

              // Color según el estado
              Color colorEstado;
              switch (data['estado']) {
                case 'pendiente':
                  colorEstado = Colors.orange;
                  break;
                case 'preparando':
                  colorEstado = Colors.blue;
                  break;
                case 'listo':
                  colorEstado = Colors.green;
                  break;
                default:
                  colorEstado = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pedido #${pedido.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorEstado),
                            ),
                            child: Text(
                              data['estado'].toString().toUpperCase(),
                              style: TextStyle(
                                color: colorEstado,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Email del cliente
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            data['email'] ?? 'Sin email',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Items del pedido
                      const Text(
                        'Pizzas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_pizza,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item['nombre']} x${item['cantidad']}',
                                  ),
                                ],
                              ),
                              Text(
                                '\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 24),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '\$${data['total'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      // Fecha
                      const SizedBox(height: 8),
                      if (data['fecha'] != null)
                        Text(
                          'Fecha: ${(data['fecha'] as Timestamp).toDate().day}/${(data['fecha'] as Timestamp).toDate().month}/${(data['fecha'] as Timestamp).toDate().year} - ${(data['fecha'] as Timestamp).toDate().hour}:${(data['fecha'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pedidos/pedido_provider.dart';

class CocineroPage extends StatelessWidget {
  const CocineroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = Provider.of<PedidoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍🍳 Gestión de Pedidos'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: pedidoProvider.obtenerTodosPedidos(),
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

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay pedidos para cocinar',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final pedidos = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];

              // Color según el estado
              Color colorEstado;
              switch (pedido.estado) {
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
                              pedido.estado.toUpperCase(),
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

                      // Items
                      const Text(
                        'Pizzas a preparar:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...pedido.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_pizza,
                                size: 18,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text('${item['nombre']} x${item['cantidad']}'),
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
                            'Total:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${pedido.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Botones según el estado
                      if (pedido.estado == 'pendiente')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: pedidoProvider.isLoading
                                ? null
                                : () async {
                                    await pedidoProvider.cambiarEstado(
                                      pedido.id,
                                      'preparando',
                                    );
                                  },
                            icon: const Icon(Icons.restaurant),
                            label: const Text('Empezar a Preparar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                      if (pedido.estado == 'preparando')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: pedidoProvider.isLoading
                                ? null
                                : () async {
                                    await pedidoProvider.cambiarEstado(
                                      pedido.id,
                                      'listo',
                                    );
                                  },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Marcar como Listo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                      if (pedido.estado == 'listo')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.done_all, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Listo para entregar',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pizza_model.dart';

class PizzasPage extends StatelessWidget {
  const PizzasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🍕 Pizzas disponibles')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pizzas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('❌ Error al cargar pizzas'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pizzas = snapshot.data!.docs.map((doc) {
            return PizzaModel.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();

          return ListView.builder(
            itemCount: pizzas.length,
            itemBuilder: (context, index) {
              final pizza = pizzas[index];
              return ListTile(
                title: Text(pizza.nombre),
                trailing: Text('\$${pizza.precio}'),
              );
            },
          );
        },
      ),
    );
  }
}

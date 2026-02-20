import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeMesero extends StatelessWidget {
  const HomeMesero({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍽️ Panel Mesero'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await authService.logout();
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }),
        ],
      ),
      body: StreamBuilder<List<PedidoModel>>(
        stream: PedidoService().obtenerPedidosMesa(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final todos = snap.data ?? [];
          final pendientes = todos.where((p) => p.estado == 'Pendiente' || p.estado == 'Preparando').toList();
          final listos = todos.where((p) => p.estado == 'Listo').toList();

          return Column(
            children: [
              // Header stats
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.teal.shade50,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _Stat('🕐 En cocina', pendientes.length, Colors.orange),
                  _Stat('✅ Listos', listos.length, Colors.green),
                  _Stat('📋 Total activos', todos.length, Colors.teal),
                ]),
              ),
              Expanded(
                child: todos.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🍽️', style: TextStyle(fontSize: 80)),
                        const SizedBox(height: 16),
                        Text('No hay pedidos de mesa activos', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ]))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (listos.isNotEmpty) ...[
                            _SectionTitle('✅ Listos para servir', listos.length, Colors.green),
                            ...listos.map((p) => _MesaCard(pedido: p, listo: true)),
                            const SizedBox(height: 16),
                          ],
                          if (pendientes.isNotEmpty) ...[
                            _SectionTitle('⏳ En cocina', pendientes.length, Colors.orange),
                            ...pendientes.map((p) => _MesaCard(pedido: p, listo: false)),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _Stat(String label, int n, Color color) => Column(children: [
  Text('$n', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
  Text(label, style: TextStyle(fontSize: 12, color: color)),
]);

Widget _SectionTitle(String title, int count, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(children: [
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12))),
  ]),
);

class _MesaCard extends StatelessWidget {
  final PedidoModel pedido; final bool listo;
  const _MesaCard({required this.pedido, required this.listo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: listo ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: listo ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: listo ? Colors.green : Colors.orange,
                child: Text('${pedido.numeroMesa ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mesa ${pedido.numeroMesa ?? "Sin número"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('#${pedido.id.substring(0, 6)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ]),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: listo ? Colors.green.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
              child: Text(pedido.estado, style: TextStyle(fontWeight: FontWeight.bold, color: listo ? Colors.green.shade800 : Colors.orange.shade800, fontSize: 13)),
            ),
          ]),
          const Divider(height: 16),
          // Items
          ...pedido.items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              const SizedBox(width: 4),
              Text('${i['cantidad']}x', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Expanded(child: Text(i['productoNombre'] ?? '', style: const TextStyle(fontSize: 14))),
            ]),
          )),
          if (pedido.notasEspeciales?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.note, size: 16), const SizedBox(width: 6), Expanded(child: Text(pedido.notasEspeciales!, style: const TextStyle(fontSize: 13)))])),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('\$${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            if (listo)
              ElevatedButton.icon(
                onPressed: () => _marcarEntregado(context),
                icon: const Icon(Icons.check),
                label: const Text('ENTREGADO'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )
            else
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Esperando cocina...', style: TextStyle(color: Colors.orange))),
          ]),
        ]),
      ),
    );
  }

  Future<void> _marcarEntregado(BuildContext context) async {
    final ok = await PedidoService().actualizarEstado(pedido.id, 'Entregado');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Mesa ${pedido.numeroMesa} marcada como entregada' : '❌ Error'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }
}
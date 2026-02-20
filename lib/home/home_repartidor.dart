import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeRepartidor extends StatelessWidget {
  const HomeRepartidor({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛵 Panel Repartidor'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await authService.logout();
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Error: usuario no identificado'))
          : _RepartidorBody(repartidorId: user.uid),
    );
  }
}

class _RepartidorBody extends StatelessWidget {
  final String repartidorId;
  const _RepartidorBody({required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    final service = PedidoService();
    return StreamBuilder<List<PedidoModel>>(
      stream: service.obtenerPedidosDomicilio(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final todos = snap.data ?? [];
        final disponibles = todos.where((p) => p.estado == 'Listo' && p.repartidorId == null).toList();
        final misPedidos = todos.where((p) => p.repartidorId == repartidorId && p.estado == 'En camino').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats
            Row(children: [
              _StatCard('📦 Disponibles', disponibles.length, Colors.orange),
              const SizedBox(width: 12),
              _StatCard('🛵 En camino', misPedidos.length, Colors.indigo),
            ]),
            const SizedBox(height: 20),

            // Pedidos disponibles para tomar
            if (disponibles.isNotEmpty) ...[
              _SectionHeader('📦 Disponibles para recoger', disponibles.length, Colors.orange),
              ...disponibles.map((p) => _PedidoDisponibleCard(pedido: p, repartidorId: repartidorId)),
              const SizedBox(height: 16),
            ],

            // Mis pedidos en camino
            if (misPedidos.isNotEmpty) ...[
              _SectionHeader('🛵 Mis entregas en camino', misPedidos.length, Colors.indigo),
              ...misPedidos.map((p) => _PedidoEnCaminoCard(pedido: p)),
            ],

            if (disponibles.isEmpty && misPedidos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const Text('🛵', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 16),
                    Text('No hay pedidos activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    Text('Espera nuevos pedidos', style: TextStyle(color: Colors.grey.shade400)),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _StatCard(String label, int count, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 12, color: color), textAlign: TextAlign.center),
    ]),
  ),
);

Widget _SectionHeader(String title, int count, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(children: [
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12))),
  ]),
);

class _PedidoDisponibleCard extends StatelessWidget {
  final PedidoModel pedido; final String repartidorId;
  const _PedidoDisponibleCard({required this.pedido, required this.repartidorId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('#${pedido.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                child: const Text('✅ LISTO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          ]),
          const Divider(height: 16),
          Row(children: [const Icon(Icons.person, size: 18, color: Colors.grey), const SizedBox(width: 6), Text(pedido.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold))]),
          if (pedido.clienteTelefono != null) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.phone, size: 18, color: Colors.grey), const SizedBox(width: 6), Text(pedido.clienteTelefono!)])],
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on, size: 18, color: Colors.red), const SizedBox(width: 6), Expanded(child: Text(pedido.direccionEntrega?['direccion'] ?? 'Sin dirección', style: const TextStyle(fontWeight: FontWeight.w500)))]),
          if ((pedido.direccionEntrega?['referencia'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.info_outline, size: 18, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text(pedido.direccionEntrega!['referencia'].toString(), style: TextStyle(color: Colors.grey.shade600)))]),
          ],
          const SizedBox(height: 10),
          // Items resumen
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pedido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ...pedido.items.take(3).map((i) => Text('${i['cantidad']}x ${i['productoNombre'] ?? ''}', style: const TextStyle(fontSize: 13))),
              if (pedido.items.length > 3) Text('...y ${pedido.items.length - 3} más', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('\$${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            ElevatedButton.icon(
              onPressed: () => _tomarPedido(context),
              icon: const Icon(Icons.delivery_dining),
              label: const Text('TOMAR'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _tomarPedido(BuildContext context) async {
    final service = PedidoService();
    final ok = await service.asignarRepartidor(pedido.id, repartidorId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Pedido asignado' : '❌ Error al asignar'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }
}

class _PedidoEnCaminoCard extends StatefulWidget {
  final PedidoModel pedido;
  const _PedidoEnCaminoCard({required this.pedido});
  @override
  State<_PedidoEnCaminoCard> createState() => _PedidoEnCaminoCardState();
}

class _PedidoEnCaminoCardState extends State<_PedidoEnCaminoCard> {
  final _codigoCtrl = TextEditingController();
  bool _verificando = false;

  @override
  void dispose() { _codigoCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.indigo.shade300, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('#${widget.pedido.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(20)),
                child: const Text('🛵 EN CAMINO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
          ]),
          const Divider(height: 16),
          Row(children: [const Icon(Icons.person), const SizedBox(width: 6), Text(widget.pedido.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold))]),
          if (widget.pedido.clienteTelefono != null)
            Row(children: [const Icon(Icons.phone), const SizedBox(width: 6), Text(widget.pedido.clienteTelefono!)]),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on, color: Colors.red), const SizedBox(width: 6), Expanded(child: Text(widget.pedido.direccionEntrega?['direccion'] ?? 'Sin dirección', style: const TextStyle(fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 12),
          Text('\$${widget.pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 16),
          // Verificación de código
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🔐 Verificar entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Pide al cliente su código de verificación de 6 dígitos:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(
                  controller: _codigoCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '_ _ _ _ _ _',
                    counterText: '',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.orange)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.orange, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                  textAlign: TextAlign.center,
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _verificando ? null : () => _verificarYEntregar(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
                  child: _verificando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('VERIFICAR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _verificarYEntregar(BuildContext context) async {
    if (_codigoCtrl.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El código debe tener 6 dígitos'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _verificando = true);
    final service = PedidoService();
    final ok = await service.marcarEntregadoDomicilio(widget.pedido.id, _codigoCtrl.text.trim());
    if (context.mounted) {
      if (ok) {
        showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✅ Entregado', textAlign: TextAlign.center),
          content: const Text('¡Pedido entregado correctamente!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)))],
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Código incorrecto. Verifica con el cliente.'), backgroundColor: Colors.red, duration: Duration(seconds: 3)));
      }
    }
    if (mounted) setState(() => _verificando = false);
  }
}
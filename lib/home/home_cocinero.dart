import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../auth/login_page.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class HomeCocinero extends StatelessWidget {
  const HomeCocinero({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: _CocinaAppBar(authService: AuthService()),
      body: StreamBuilder<List<PedidoModel>>(
        stream: PedidoService().obtenerPedidosActivos(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
          }
          final todos      = snap.data ?? [];
          final pendientes = todos.where((p) => p.estado == 'Pendiente').toList();
          final preparando = todos.where((p) => p.estado == 'Preparando').toList();
          final listos     = todos.where((p) => p.estado == 'Listo').toList();

          if (todos.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🍳', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text('COCINA LIBRE', style: TextStyle(color: Colors.white24,
                  fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6)),
              const SizedBox(height: 8),
              Text('No hay pedidos activos', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15)),
            ]));
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // COLUMNA 1 — PENDIENTES
              Expanded(child: _Columna(
                titulo: 'NUEVOS PEDIDOS', icono: '🔴', count: pendientes.length,
                color: const Color(0xFFFF6B35), pedidos: pendientes,
                emptyMsg: 'Sin pedidos nuevos', emptyIcon: '✅',
              )),
              const SizedBox(width: 12),
              // COLUMNA 2 — PREPARANDO
              Expanded(child: _Columna(
                titulo: 'EN PREPARACION', icono: '🔵', count: preparando.length,
                color: const Color(0xFF38BDF8), pedidos: preparando,
                emptyMsg: 'Nada en cocina', emptyIcon: '🍽️',
              )),
              const SizedBox(width: 12),
              // COLUMNA 3 — LISTOS
              Expanded(child: _Columna(
                titulo: 'LISTOS', icono: '🟢', count: listos.length,
                color: const Color(0xFF4ADE80), pedidos: listos,
                emptyMsg: 'Sin pedidos listos', emptyIcon: '⏳',
              )),
            ]),
          );
        },
      ),
    );
  }
}

// ── APP BAR ──────────────────────────────────────────────────
class _CocinaAppBar extends StatefulWidget implements PreferredSizeWidget {
  final AuthService authService;
  const _CocinaAppBar({required this.authService});
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  State<_CocinaAppBar> createState() => _CocinaAppBarState();
}

class _CocinaAppBarState extends State<_CocinaAppBar> {
  late DateTime _ahora;
  @override
  void initState() { super.initState(); _ahora = DateTime.now(); _tick(); }
  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() { _ahora = DateTime.now(); _tick(); });
    });
  }
  @override
  Widget build(BuildContext context) {
    final h = _ahora.hour.toString().padLeft(2, '0');
    final m = _ahora.minute.toString().padLeft(2, '0');
    final s = _ahora.second.toString().padLeft(2, '0');
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
          ),
          child: const Row(children: [
            Text('👨‍🍳', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('PANEL DE COCINA', style: TextStyle(color: Color(0xFFFF6B00),
                fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(width: 20),
        Text('$h:$m:$s', style: const TextStyle(color: Colors.white24, fontSize: 16,
            fontFamily: 'monospace', letterSpacing: 3)),
      ]),
      actions: [
        StreamBuilder<List<PedidoModel>>(
          stream: PedidoService().obtenerPedidosActivos(),
          builder: (_, snap) {
            final n = snap.data?.length ?? 0;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: n > 3 ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: n > 3 ? Colors.red.withOpacity(0.5) : Colors.orange.withOpacity(0.4)),
              ),
              child: Text('$n activos', style: TextStyle(
                  color: n > 3 ? Colors.red.shade300 : Colors.orange,
                  fontWeight: FontWeight.bold, fontSize: 13)),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
          onPressed: () async {
            await widget.authService.logout();
            if (context.mounted) Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginPage()));
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ── COLUMNA ──────────────────────────────────────────────────
class _Columna extends StatelessWidget {
  final String titulo, icono, emptyMsg, emptyIcon;
  final int count;
  final Color color;
  final List<PedidoModel> pedidos;
  const _Columna({required this.titulo, required this.icono, required this.count,
      required this.color, required this.pedidos, required this.emptyMsg, required this.emptyIcon});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // Header
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text(icono, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    ),
    const SizedBox(height: 10),
    // Lista
    Expanded(child: pedidos.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emptyIcon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(emptyMsg, style: TextStyle(color: Colors.white.withOpacity(0.2),
                fontSize: 13, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ]))
        : ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (_, i) => _TarjetaPedido(pedido: pedidos[i], colorEstado: color),
          )),
  ]);
}

// ── TARJETA DE PEDIDO ─────────────────────────────────────────
class _TarjetaPedido extends StatefulWidget {
  final PedidoModel pedido;
  final Color colorEstado;
  const _TarjetaPedido({required this.pedido, required this.colorEstado});
  @override
  State<_TarjetaPedido> createState() => _TarjetaPedidoState();
}

class _TarjetaPedidoState extends State<_TarjetaPedido> {
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    final p      = widget.pedido;
    final esMesa = p.tipoPedido == 'mesa';
    final color  = widget.colorEstado;
    final hora   = '${p.fecha.hour.toString().padLeft(2,'0')}:${p.fecha.minute.toString().padLeft(2,'0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Franja superior
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: esMesa ? const Color(0xFF0EA5E9).withOpacity(0.2) : const Color(0xFFA855F7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Text(esMesa ? '🍽️' : '🛵', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(esMesa ? 'MESA ${p.numeroMesa ?? "?"}' : 'DOMICILIO',
                    style: TextStyle(
                      color: esMesa ? const Color(0xFF38BDF8) : const Color(0xFFC084FC),
                      fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1,
                    )),
              ]),
            ),
            Row(children: [
              Text(hora, style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Text('#${p.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')),
            ]),
          ]),
        ),

        // Items
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...p.items.map((item) {
              final nombre   = item['productoNombre'] ?? '';
              final cantidad = item['cantidad'] ?? 1;
              final notas    = (item['notasEspeciales'] ?? '').toString().trim();
              final opciones = item['opcionesSeleccionadas'] as Map?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Center(child: Text('$cantidad',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (opciones != null && opciones.isNotEmpty)
                      Text(opciones.entries.map((e) => '${e.value}').join(' · '),
                          style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
                    if (notas.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Text('📝 $notas', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                      ),
                  ])),
                ]),
              );
            }),
            if (p.notasEspeciales?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('⚠️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p.notasEspeciales!,
                      style: const TextStyle(color: Colors.amber, fontSize: 11))),
                ]),
              ),
            ],
          ]),
        ),

        // Botón acción
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: _buildBoton(p.estado, color),
        ),
      ]),
    );
  }

  Widget _buildBoton(String estado, Color color) {
    if (estado == 'Listo') {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4ADE80).withOpacity(0.07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.25)),
        ),
        child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 16),
          SizedBox(width: 7),
          Text('ESPERANDO ENTREGA', style: TextStyle(color: Color(0xFF4ADE80),
              fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
        ])),
      );
    }

    final esPendiente = estado == 'Pendiente';
    final btnColor    = esPendiente ? const Color(0xFF38BDF8) : const Color(0xFF4ADE80);
    final btnLabel    = esPendiente ? 'INICIAR PREPARACION' : 'MARCAR LISTO';
    final btnIcono    = esPendiente ? Icons.play_arrow_rounded : Icons.check_rounded;
    final siguiente   = esPendiente ? 'Preparando' : 'Listo';

    return GestureDetector(
      onTap: _cargando ? null : () => _cambiar(siguiente),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _cargando
              ? [btnColor.withOpacity(0.08), btnColor.withOpacity(0.08)]
              : [btnColor.withOpacity(0.22), btnColor.withOpacity(0.08)]),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: btnColor.withOpacity(_cargando ? 0.2 : 0.55), width: 1.5),
        ),
        child: Center(child: _cargando
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: btnColor, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(btnIcono, color: btnColor, size: 18),
                const SizedBox(width: 7),
                Text(btnLabel, style: TextStyle(color: btnColor,
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8)),
              ])),
      ),
    );
  }

  Future<void> _cambiar(String nuevoEstado) async {
    setState(() => _cargando = true);
    await PedidoService().actualizarEstado(widget.pedido.id, nuevoEstado);
    if (mounted) setState(() => _cargando = false);
  }
}
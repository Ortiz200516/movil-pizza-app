import 'package:flutter/material.dart';
import '../models/reserva_model.dart';
import '../services/reservas_service.dart';

const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);

class ReservasAdminPage extends StatefulWidget {
  const ReservasAdminPage({super.key});
  @override
  State<ReservasAdminPage> createState() => _ReservasAdminPageState();
}

class _ReservasAdminPageState extends State<ReservasAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc = ReservasService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: _kBg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('🍽️ Reservas',
          style: TextStyle(fontWeight: FontWeight.bold)),
      bottom: TabBar(
        controller: _tabs,
        labelColor: _kNar,
        unselectedLabelColor: Colors.white38,
        indicatorColor: _kNar,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Hoy'),
          Tab(text: 'Pendientes'),
          Tab(text: 'Todas'),
        ],
      ),
    ),
    body: TabBarView(controller: _tabs, children: [
      _ListaReservas(stream: _svc.streamReservasHoy(),
          emptyMsg: 'Sin reservas para hoy'),
      _ListaReservas(
          stream: _svc.streamTodasReservas(estado: 'pendiente'),
          emptyMsg: 'Sin reservas pendientes',
          destacarPendientes: true),
      _ListaReservas(stream: _svc.streamTodasReservas(),
          emptyMsg: 'Sin reservas registradas'),
    ]),
  );
}

// ── Lista de reservas con acciones ────────────────────────────────────────────
class _ListaReservas extends StatelessWidget {
  final Stream<List<ReservaModel>> stream;
  final String emptyMsg;
  final bool destacarPendientes;
  const _ListaReservas({required this.stream, required this.emptyMsg,
      this.destacarPendientes = false});

  Color _color(String e) {
    switch (e) {
      case 'confirmada':  return _kVerde;
      case 'rechazada':   return Colors.red;
      case 'cancelada':   return Colors.grey;
      case 'completada':  return _kAzul;
      default:            return Colors.orange;
    }
  }

  String _emoji(String e) {
    switch (e) {
      case 'confirmada':  return '✅';
      case 'rechazada':   return '❌';
      case 'cancelada':   return '🚫';
      case 'completada':  return '🎉';
      default:            return '⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReservaModel>>(
      stream: stream,
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: _kNar));

        if (snap.data!.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🍽️', style: TextStyle(fontSize: 50)),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
        ]));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.length,
          itemBuilder: (_, i) {
            final r = snap.data![i];
            final color = _color(r.estado);
            final esPend = r.estado == 'pendiente';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: esPend && destacarPendientes
                        ? Colors.orange.withValues(alpha: 0.5)
                        : color.withValues(alpha: 0.2),
                    width: esPend && destacarPendientes ? 1.5 : 1),
              ),
              child: Column(children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(_emoji(r.estado),
                          style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(r.clienteNombre, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700,
                          fontSize: 14)),
                      Text('📞 ${r.clienteTelefono}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(r.estado.toUpperCase(), style: TextStyle(
                            color: color, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ]),
                ),

                // ── Detalles ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kCard2,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      _Chip('🪑 Mesa ${r.numeroMesa}', _kNar),
                      const SizedBox(width: 8),
                      _Chip('📅 ${r.fechaCorta}', _kAzul),
                      const SizedBox(width: 8),
                      _Chip('🕐 ${r.hora}', Colors.purple),
                      const SizedBox(width: 8),
                      _Chip('👥 ${r.personas}', _kVerde),
                    ]),
                    if (r.notasCliente?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text('📝 ${r.notasCliente}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12)),
                    ],

                    // ── Acciones ──────────────────────────────────────────
                    if (r.estado == 'pendiente') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _BtnAccion(
                          '✅ Confirmar', _kVerde,
                          onTap: () => _confirmar(context, r),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _BtnAccion(
                          '❌ Rechazar', Colors.red,
                          onTap: () => _rechazar(context, r),
                        )),
                      ]),
                    ] else if (r.estado == 'confirmada') ...[
                      const SizedBox(height: 12),
                      _BtnAccion('🎉 Marcar completada', _kAzul,
                          onTap: () => ReservasService()
                              .completarReserva(r.id)),
                    ],
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmar(BuildContext ctx, ReservaModel r) async {
    final notaCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirmar reserva',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Mesa ${r.numeroMesa} · ${r.fechaCorta} · ${r.hora}\n'
              '${r.clienteNombre}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          TextField(
            controller: notaCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nota para el cliente (opcional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: _kCard2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kVerde, foregroundColor: Colors.black,
                  elevation: 0),
              child: const Text('Confirmar',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      await ReservasService().confirmarReserva(r.id,
          nota: notaCtrl.text.trim());
    }
  }

  Future<void> _rechazar(BuildContext ctx, ReservaModel r) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Rechazar reserva',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Mesa ${r.numeroMesa} · ${r.fechaCorta} · ${r.hora}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          TextField(
            controller: motivoCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Motivo del rechazo (opcional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: _kCard2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  elevation: 0),
              child: const Text('Rechazar',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      await ReservasService().rechazarReserva(r.id,
          motivo: motivoCtrl.text.trim());
    }
  }
}

Widget _Chip(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: c.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: c.withValues(alpha: 0.2)),
  ),
  child: Text(t, style: TextStyle(color: c, fontSize: 10,
      fontWeight: FontWeight.w600)),
);

class _BtnAccion extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _BtnAccion(this.label, this.color, {this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 12))),
    ),
  );
}
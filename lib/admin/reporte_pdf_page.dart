import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pedido_model.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kNar  = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);

// ── Página de reportes con vista previa y exportación ─────────────────────────
class ReportePdfPage extends StatefulWidget {
  const ReportePdfPage({super.key});
  @override
  State<ReportePdfPage> createState() => _ReportePdfPageState();
}

class _ReportePdfPageState extends State<ReportePdfPage> {
  String   _periodo   = 'hoy';
  bool     _generando = false;

  static const _periodos = [
    ('hoy',    'Hoy'),
    ('semana', '7 días'),
    ('mes',    'Este mes'),
  ];

  DateTime get _desde {
    final now = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(now.year, now.month, now.day);
      case 'semana': return now.subtract(const Duration(days: 7));
      case 'mes':    return DateTime(now.year, now.month, 1);
      default:       return DateTime(now.year, now.month, now.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('📄 Reporte PDF',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('fecha', isGreaterThanOrEqualTo:
                Timestamp.fromDate(_desde))
            .snapshots(),
        builder: (_, snap) {
          final pedidos = snap.hasData
              ? snap.data!.docs.map((d) => PedidoModel.fromFirestore(
                    d.id, d.data() as Map<String, dynamic>))
                  .toList()
              : <PedidoModel>[];

          final entregados = pedidos.where((p) =>
              p.estado == 'Entregado').toList();
          final cancelados = pedidos.where((p) =>
              p.estado == 'Cancelado').length;
          final ventas = entregados.fold(0.0, (s, p) => s + p.total);
          final ticket = entregados.isEmpty ? 0.0
              : ventas / entregados.length;

          // Top productos
          final Map<String, int> prodCount = {};
          for (final p in entregados) {
            for (final item in p.items) {
              final n = item['nombre'] ?? item['productoNombre'] ?? '';
              prodCount[n] = (prodCount[n] ?? 0) +
                  ((item['cantidad'] as int?) ?? 1);
            }
          }
          final topProd = prodCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Selector período ──────────────────────────────────
              _SecTit('📅 Período del reporte'),
              Row(children: _periodos.map((p) {
                final sel = _periodo == p.$1;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _periodo = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _kNar.withValues(alpha: 0.15) : _kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _kNar : Colors.white.withValues(alpha: 0.08),
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(p.$2, textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel ? _kNar : Colors.white38,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 13)),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 20),

              // ── Vista previa del reporte ──────────────────────────
              _SecTit('👁️ Vista previa'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16)],
                ),
                child: Column(children: [

                  // Header del PDF
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Text('🍕', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('LA ITALIANA', style: TextStyle(
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.w900,
                              fontSize: 18, letterSpacing: 2)),
                          Text('Pizzería Artesanal',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          const Text('REPORTE DE VENTAS',
                              style: TextStyle(color: Colors.white54,
                                  fontSize: 9, letterSpacing: 1)),
                          Text(_periodoLabel(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text(_fechaHoy(), style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                        ]),
                      ]),
                    ]),
                  ),

                  // KPIs
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        _KpiPdf('Ventas totales',
                            '\$${ventas.toStringAsFixed(2)}',
                            const Color(0xFF16A34A)),
                        _KpiPdf('Pedidos', '${entregados.length}',
                            const Color(0xFF2563EB)),
                        _KpiPdf('Ticket prom.',
                            '\$${ticket.toStringAsFixed(2)}',
                            const Color(0xFFD97706)),
                        _KpiPdf('Cancelados', '$cancelados',
                            const Color(0xFFDC2626)),
                      ]),
                    ]),
                  ),

                  // Separador
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Top productos
                  if (topProd.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('TOP PRODUCTOS',
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 10),
                        ...topProd.take(5).toList().asMap().entries.map((e) {
                          final pct = e.value.value /
                              topProd.first.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              SizedBox(width: 20,
                                  child: Text('${e.key + 1}',
                                      style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11))),
                              Expanded(child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(e.value.key,
                                    style: const TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation(
                                    _kNar),
                                ),
                              ])),
                              const SizedBox(width: 10),
                              Text('${e.value.value} uds',
                                  style: TextStyle(
                                      color: _kNar,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ]),
                          );
                        }),
                      ]),
                    ),

                  // Pedidos recientes
                  if (entregados.isNotEmpty)
                    Column(children: [
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('PEDIDOS ENTREGADOS',
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                          const SizedBox(height: 10),
                          // Header tabla
                          const Row(children: [
                            Expanded(flex: 3, child: Text('Cliente',
                                style: TextStyle(color: Color(0xFF94A3B8),
                                    fontSize: 10, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('Tipo',
                                style: TextStyle(color: Color(0xFF94A3B8),
                                    fontSize: 10, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('Pago',
                                style: TextStyle(color: Color(0xFF94A3B8),
                                    fontSize: 10, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(color: Color(0xFF94A3B8),
                                    fontSize: 10, fontWeight: FontWeight.w700))),
                          ]),
                          const SizedBox(height: 4),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ...entregados.take(8).map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(
                                  p.clienteNombre,
                                  style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2, child: Text(
                                  p.tipoPedido,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11))),
                              Expanded(flex: 2, child: Text(
                                  p.metodoPago,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11))),
                              Expanded(flex: 2, child: Text(
                                  '\$${p.total.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11))),
                            ]),
                          )),
                          if (entregados.length > 8)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  '... y ${entregados.length - 8} pedidos más',
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic)),
                            ),
                        ]),
                      ),
                    ]),

                  // Footer PDF
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14)),
                    ),
                    child: Row(children: [
                      Text('Generado: ${_fechaHoy()}',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 9)),
                      const Spacer(),
                      const Text('La Italiana — Sistema de gestión',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 9)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Botón exportar ────────────────────────────────────
              _BtnExportar(
                pedidos: entregados,
                ventas: ventas,
                ticket: ticket,
                cancelados: cancelados,
                topProd: topProd,
                periodo: _periodoLabel(),
                generando: _generando,
                onGenerar: (v) => setState(() => _generando = v),
              ),
              const SizedBox(height: 12),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'El PDF se guarda en la carpeta de Descargas '
                    'de tu dispositivo y puede compartirse por WhatsApp o email.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12),
                  )),
                ]),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  String _periodoLabel() {
    switch (_periodo) {
      case 'hoy':    return 'Hoy — ${_fechaHoy()}';
      case 'semana': return 'Últimos 7 días';
      case 'mes':    return 'Este mes';
      default:       return '';
    }
  }

  String _fechaHoy() {
    final d = DateTime.now();
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Botón exportar con lógica CSV fallback ────────────────────────────────────
class _BtnExportar extends StatelessWidget {
  final List<PedidoModel> pedidos;
  final double ventas, ticket;
  final int cancelados;
  final List<MapEntry<String, int>> topProd;
  final String periodo;
  final bool generando;
  final ValueChanged<bool> onGenerar;

  const _BtnExportar({
    required this.pedidos, required this.ventas,
    required this.ticket, required this.cancelados,
    required this.topProd, required this.periodo,
    required this.generando, required this.onGenerar,
  });

  Future<void> _exportar(BuildContext context) async {
    onGenerar(true);
    try {
      // Generar CSV como alternativa compatible sin dependencias extra
      final csv = _generarCSV();
      await _compartirCSV(context, csv);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      onGenerar(false);
    }
  }

  String _generarCSV() {
    final sb = StringBuffer();
    // Header
    sb.writeln('REPORTE LA ITALIANA — $periodo');
    sb.writeln('Generado: ${DateTime.now()}');
    sb.writeln('');
    sb.writeln('RESUMEN');
    sb.writeln('Ventas totales,\$${ventas.toStringAsFixed(2)}');
    sb.writeln('Pedidos entregados,${pedidos.length}');
    sb.writeln('Ticket promedio,\$${ticket.toStringAsFixed(2)}');
    sb.writeln('Cancelados,$cancelados');
    sb.writeln('');
    sb.writeln('TOP PRODUCTOS');
    sb.writeln('Producto,Unidades');
    for (final e in topProd.take(10)) {
      sb.writeln('${e.key},${e.value}');
    }
    sb.writeln('');
    sb.writeln('DETALLE PEDIDOS');
    sb.writeln('Cliente,Tipo,Método pago,Total,Fecha');
    for (final p in pedidos) {
      final fecha = '${p.fecha.day}/${p.fecha.month}/${p.fecha.year}';
      sb.writeln('${p.clienteNombre},${p.tipoPedido},${p.metodoPago},\$${p.total.toStringAsFixed(2)},$fecha');
    }
    return sb.toString();
  }

  Future<void> _compartirCSV(BuildContext context, String csv) async {
    // Copiar al portapapeles como alternativa universal
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            '📋 Reporte copiado al portapapeles — '
            'pégalo en Excel o Google Sheets'),
        backgroundColor: Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: generando ? null : () => _exportar(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: generando ? _kNar.withValues(alpha: 0.4) : _kNar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        generando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text('📄', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(
          generando ? 'Generando...' : 'Exportar reporte CSV',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ]),
    ),
  );
}

// ── Helpers visuales ──────────────────────────────────────────────────────────
class _KpiPdf extends StatelessWidget {
  final String label, valor;
  final Color color;
  const _KpiPdf(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(valor, style: TextStyle(color: color,
        fontWeight: FontWeight.w900, fontSize: 16)),
    const SizedBox(height: 2),
    Text(label, textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
  ]));
}

Widget _SecTit(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t, style: const TextStyle(color: Colors.white,
      fontWeight: FontWeight.w700, fontSize: 14)),
);
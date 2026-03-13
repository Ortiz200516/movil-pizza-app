import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNaranja = Color(0xFFFF6B35);

// ── Servicio de caja ──────────────────────────────────────────────────────────
class CajaService {
  final _db = FirebaseFirestore.instance;

  // ── Calcular resumen del día ──────────────────────────────────────────────
  Future<Map<String, dynamic>> calcularResumenDia({
    DateTime? fecha,
    String? turno, // 'mañana' | 'tarde' | 'noche' | null (todo el día)
  }) async {
    final hoy   = fecha ?? DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin    = inicio.add(const Duration(days: 1));

    var query = _db.collection('pedidos')
        .where('estado', isEqualTo: 'Entregado')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan:            Timestamp.fromDate(fin));

    final snap = await query.get();
    final pedidos = snap.docs.map((d) => d.data()).toList();

    double totalEfectivo     = 0;
    double totalTarjeta      = 0;
    double totalTransferencia = 0;
    double totalGeneral      = 0;
    int    cantPedidos       = 0;
    int    cantMesa          = 0;
    int    cantDomicilio     = 0;
    int    cantRetirar       = 0;
    final Map<String, int> productoCount = {};

    for (final p in pedidos) {
      final total  = (p['total'] as num?)?.toDouble() ?? 0.0;
      final metodo = (p['metodoPago'] as String?)?.toLowerCase() ?? 'efectivo';
      final tipo   = (p['tipoPedido'] as String?) ?? 'mesa';

      totalGeneral += total;
      cantPedidos++;

      switch (metodo) {
        case 'tarjeta':      totalTarjeta      += total; break;
        case 'transferencia': totalTransferencia += total; break;
        default:             totalEfectivo     += total;
      }

      switch (tipo) {
        case 'domicilio': cantDomicilio++; break;
        case 'retirar':   cantRetirar++;   break;
        default:          cantMesa++;
      }

      // Productos más vendidos
      final items = (p['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        final nombre = (item['nombre'] as String?) ?? '?';
        final cant   = (item['cantidad'] as int?) ?? 1;
        productoCount[nombre] = (productoCount[nombre] ?? 0) + cant;
      }
    }

    // Top 5 productos
    final topProductos = productoCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'fecha':             hoy,
      'totalGeneral':      totalGeneral,
      'totalEfectivo':     totalEfectivo,
      'totalTarjeta':      totalTarjeta,
      'totalTransferencia': totalTransferencia,
      'cantPedidos':       cantPedidos,
      'cantMesa':          cantMesa,
      'cantDomicilio':     cantDomicilio,
      'cantRetirar':       cantRetirar,
      'topProductos':      topProductos.take(5).toList(),
      'ticketPromedio':    cantPedidos > 0 ? totalGeneral / cantPedidos : 0.0,
    };
  }

  // ── Cerrar caja ───────────────────────────────────────────────────────────
  Future<String> cerrarCaja({
    required Map<String, dynamic> resumen,
    required String responsable,
    String? observaciones,
    Map<String, double>? efectivoContado, // {'billetes': x, 'monedas': y}
  }) async {
    final ref = await _db.collection('cierres_caja').add({
      'fecha':             Timestamp.fromDate(resumen['fecha'] as DateTime),
      'fechaCierre':       FieldValue.serverTimestamp(),
      'responsableId':     FirebaseAuth.instance.currentUser?.uid,
      'responsableNombre': responsable,
      'totalGeneral':      resumen['totalGeneral'],
      'totalEfectivo':     resumen['totalEfectivo'],
      'totalTarjeta':      resumen['totalTarjeta'],
      'totalTransferencia': resumen['totalTransferencia'],
      'cantPedidos':       resumen['cantPedidos'],
      'cantMesa':          resumen['cantMesa'],
      'cantDomicilio':     resumen['cantDomicilio'],
      'cantRetirar':       resumen['cantRetirar'],
      'ticketPromedio':    resumen['ticketPromedio'],
      'efectivoContado':   efectivoContado ?? {},
      'observaciones':     observaciones ?? '',
    });
    return ref.id;
  }

  // ── Historial de cierres ──────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamCierres() =>
      _db.collection('cierres_caja')
          .orderBy('fechaCierre', descending: true)
          .limit(30)
          .snapshots()
          .map((s) => s.docs
              .map((d) => {...d.data(), 'id': d.id})
              .toList());
}

// ── Página de cierre de caja ──────────────────────────────────────────────────
class CierreCajaPage extends StatefulWidget {
  const CierreCajaPage({super.key});
  @override
  State<CierreCajaPage> createState() => _CierreCajaPageState();
}

class _CierreCajaPageState extends State<CierreCajaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc  = CajaService();
  bool _cargando = false;
  Map<String, dynamic>? _resumen;
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargarResumen();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarResumen() async {
    setState(() => _cargando = true);
    final r = await _svc.calcularResumenDia();
    setState(() { _resumen = r; _cargando = false; });
  }

  Future<void> _cerrarCaja() async {
    if (_resumen == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('🔒 Cerrar caja',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: Text(
          '¿Confirmas el cierre de caja del día?\n\n'
          'Total: \$${(_resumen!['totalGeneral'] as double).toStringAsFixed(2)}\n'
          'Pedidos: ${_resumen!['cantPedidos']}',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kNaranja,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirmar cierre'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Obtener nombre del admin
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final nombre = doc.data()?['nombre'] ?? user.email ?? 'Admin';

    final id = await _svc.cerrarCaja(
      resumen: _resumen!,
      responsable: nombre,
      observaciones: _obsCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Caja cerrada — ID: $id'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('💰 Caja',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarResumen,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kNaranja,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kNaranja,
          tabs: const [
            Tab(text: 'Resumen del día'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Resumen y cierre ──────────────────────────────────────
          _cargando
              ? const Center(child: CircularProgressIndicator(
                  color: _kNaranja))
              : _resumen == null
                  ? const Center(child: Text('Sin datos',
                      style: TextStyle(color: Colors.white38)))
                  : _buildResumen(),

          // ── Tab 2: Historial de cierres ──────────────────────────────────
          _buildHistorial(),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final r = _resumen!;
    final total  = (r['totalGeneral']      as double);
    final efect  = (r['totalEfectivo']     as double);
    final tarj   = (r['totalTarjeta']      as double);
    final trans  = (r['totalTransferencia'] as double);
    final cant   = (r['cantPedidos']       as int);
    final ticket = (r['ticketPromedio']    as double);
    final top    = (r['topProductos']      as List);
    final fecha  = (r['fecha']             as DateTime);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header fecha
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kNaranja.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kNaranja.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Text('📅', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              '${fecha.day}/${fecha.month}/${fecha.year}  —  turno completo',
              style: const TextStyle(color: _kNaranja,
                  fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: _cargarResumen,
              child: const Text('🔄',
                  style: TextStyle(fontSize: 18)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Total general (grande)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            const Text('💵 TOTAL DEL DÍA', style: TextStyle(
                color: Colors.white38, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: total.toStringAsFixed(2))),
              child: Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w900,
                      fontSize: 42)),
            ),
            const SizedBox(height: 4),
            Text('$cant pedidos  ·  ticket promedio \$${ticket.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),

        // Por método de pago
        _SecTitulo('Por método de pago'),
        Row(children: [
          _MetodoCaja('💵 Efectivo', efect, Colors.green),
          const SizedBox(width: 8),
          _MetodoCaja('💳 Tarjeta', tarj, Colors.blue),
          const SizedBox(width: 8),
          _MetodoCaja('📱 Transfer.', trans, _kNaranja),
        ]),
        const SizedBox(height: 12),

        // Por tipo de pedido
        _SecTitulo('Por tipo de pedido'),
        Row(children: [
          _TipoCaja('🍽️ Mesa',      r['cantMesa']      as int, Colors.purple),
          const SizedBox(width: 8),
          _TipoCaja('🛵 Domicilio', r['cantDomicilio'] as int, _kNaranja),
          const SizedBox(width: 8),
          _TipoCaja('🏃 Retirar',   r['cantRetirar']   as int, Colors.teal),
        ]),
        const SizedBox(height: 12),

        // Top productos
        if (top.isNotEmpty) ...[
          _SecTitulo('Top productos del día'),
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: top.asMap().entries.map((e) {
                final entry = e.value as MapEntry<String, int>;
                final isLast = e.key == top.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                        bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05))),
                  ),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _kNaranja.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('${e.key + 1}',
                          style: const TextStyle(
                              color: _kNaranja, fontSize: 11,
                              fontWeight: FontWeight.w900))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.key,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13))),
                    Text('${entry.value} uds',
                        style: const TextStyle(
                            color: _kNaranja,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Observaciones
        _SecTitulo('Observaciones (opcional)'),
        TextField(
          controller: _obsCtrl,
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Novedades del turno, incidencias…',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
            filled: true,
            fillColor: _kCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 20),

        // Botón cerrar caja
        GestureDetector(
          onTap: cant > 0 ? _cerrarCaja : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: cant > 0
                  ? _kNaranja
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Text('🔒', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                cant > 0
                    ? 'CERRAR CAJA  ·  \$${total.toStringAsFixed(2)}'
                    : 'Sin pedidos entregados hoy',
                style: TextStyle(
                    color: cant > 0
                        ? Colors.white
                        : Colors.white24,
                    fontWeight: FontWeight.w900,
                    fontSize: 15, letterSpacing: 0.5)),
            ]),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildHistorial() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.streamCierres(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: _kNaranja));
        }
        if (snap.data!.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🗂️', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 12),
            Text('Sin cierres registrados aún',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.length,
          itemBuilder: (_, i) => _CierreTile(cierre: snap.data![i]),
        );
      },
    );
  }
}

// ── Tile historial ────────────────────────────────────────────────────────────
class _CierreTile extends StatelessWidget {
  final Map<String, dynamic> cierre;
  const _CierreTile({required this.cierre});

  @override
  Widget build(BuildContext context) {
    final fecha = (cierre['fechaCierre'] as Timestamp?)?.toDate();
    final total = (cierre['totalGeneral'] as num?)?.toDouble() ?? 0.0;
    final cant  = (cierre['cantPedidos'] as int?) ?? 0;
    final resp  = cierre['responsableNombre'] as String? ?? '';
    final obs   = cierre['observaciones'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 4),
          collapsedIconColor: Colors.white24,
          iconColor: _kNaranja,
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Center(child: Text('🔒',
                style: TextStyle(fontSize: 20))),
          ),
          title: Text(
            fecha != null
                ? '${fecha.day}/${fecha.month}/${fecha.year}'
                : '—',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            '\$${total.toStringAsFixed(2)}  ·  $cant pedidos  ·  $resp',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _FilaCierre('Efectivo',
                    '\$${(cierre['totalEfectivo'] as num? ?? 0).toStringAsFixed(2)}',
                    Colors.green),
                _FilaCierre('Tarjeta',
                    '\$${(cierre['totalTarjeta'] as num? ?? 0).toStringAsFixed(2)}',
                    Colors.blue),
                _FilaCierre('Transferencia',
                    '\$${(cierre['totalTransferencia'] as num? ?? 0).toStringAsFixed(2)}',
                    _kNaranja),
                _FilaCierre('Mesa',
                    '${(cierre['cantMesa'] as int? ?? 0)} pedidos',
                    Colors.purple),
                _FilaCierre('Domicilio',
                    '${(cierre['cantDomicilio'] as int? ?? 0)} pedidos',
                    _kNaranja),
                if (obs.isNotEmpty) ...[
                  const Divider(color: Colors.white10, height: 16),
                  Text('📝 $obs', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaCierre extends StatelessWidget {
  final String label, valor;
  final Color color;
  const _FilaCierre(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(
          color: Colors.white54, fontSize: 12)),
      Text(valor, style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _MetodoCaja extends StatelessWidget {
  final String label;
  final double total;
  final Color color;
  const _MetodoCaja(this.label, this.total, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('\$${total.toStringAsFixed(2)}',
          style: TextStyle(color: color,
              fontWeight: FontWeight.w900, fontSize: 15)),
    ]),
  ));
}

class _TipoCaja extends StatelessWidget {
  final String label;
  final int cant;
  final Color color;
  const _TipoCaja(this.label, this.cant, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('$cant', style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 20)),
    ]),
  ));
}

Widget _SecTitulo(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(t.toUpperCase(), style: TextStyle(
      color: Colors.white.withValues(alpha: 0.3), fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 1)),
);
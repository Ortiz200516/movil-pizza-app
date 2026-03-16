import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);
const _kMor   = Color(0xFFA78BFA);
const _kAmb   = Color(0xFFFFD700);

// ── Helpers de estado ─────────────────────────────────────────────────────────
Color _estadoColor(String e) {
  switch (e) {
    case 'Pendiente':  return Colors.orange;
    case 'Preparando': return _kAzul;
    case 'Listo':      return _kAmb;
    case 'En camino':  return Colors.indigo;
    case 'Entregado':  return _kVerde;
    case 'Cancelado':  return Colors.red;
    default:           return Colors.grey;
  }
}

String _estadoEmoji(String e) {
  switch (e) {
    case 'Pendiente':  return '⏳';
    case 'Preparando': return '👨‍🍳';
    case 'Listo':      return '✅';
    case 'En camino':  return '🛵';
    case 'Entregado':  return '🎉';
    case 'Cancelado':  return '❌';
    default:           return '•';
  }
}

// ── Página principal ──────────────────────────────────────────────────────────
class PedidosAdminPage extends StatefulWidget {
  const PedidosAdminPage({super.key});
  @override
  State<PedidosAdminPage> createState() => _PedidosAdminPageState();
}

class _PedidosAdminPageState extends State<PedidosAdminPage>
    with SingleTickerProviderStateMixin {
  // Filtros
  String _filtroEstado  = 'todos';
  String _filtroTipo    = 'todos';
  String _filtroPeriodo = 'hoy';
  DateTimeRange? _rangoPersonalizado;
  String _busqueda      = '';
  bool   _vistaKanban   = false;

  final _searchCtrl = TextEditingController();

  static const _estados = [
    ('todos',      'Todos',      Colors.purple),
    ('Pendiente',  'Pendiente',  Colors.orange),
    ('Preparando', 'Preparando', Colors.blue),
    ('Listo',      'Listo',      Colors.amber),
    ('En camino',  'En camino',  Colors.indigo),
    ('Entregado',  'Entregado',  Colors.teal),
    ('Cancelado',  'Cancelado',  Colors.red),
  ];

  static const _tipos = [
    ('todos',     'Todos'),
    ('mesa',      '🍽️ Mesa'),
    ('domicilio', '🛵 Domicilio'),
    ('retirar',   '🏃 Retirar'),
  ];

  static const _periodos = [
    ('hoy',    'Hoy'),
    ('ayer',   'Ayer'),
    ('semana', '7 días'),
    ('mes',    'Mes'),
    ('todos',  'Todos'),
    ('rango',  'Rango'),
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  DateTimeRange _rangoActual() {
    final ahora = DateTime.now();
    switch (_filtroPeriodo) {
      case 'hoy':
        return DateTimeRange(
            start: DateTime(ahora.year, ahora.month, ahora.day),
            end: ahora);
      case 'ayer':
        final ayer = ahora.subtract(const Duration(days: 1));
        return DateTimeRange(
            start: DateTime(ayer.year, ayer.month, ayer.day),
            end: DateTime(ayer.year, ayer.month, ayer.day, 23, 59, 59));
      case 'semana':
        return DateTimeRange(
            start: ahora.subtract(const Duration(days: 7)), end: ahora);
      case 'mes':
        return DateTimeRange(
            start: DateTime(ahora.year, ahora.month, 1), end: ahora);
      case 'rango':
        return _rangoPersonalizado ??
            DateTimeRange(
                start: ahora.subtract(const Duration(days: 30)),
                end: ahora);
      default:
        return DateTimeRange(
            start: DateTime(2024, 1, 1), end: ahora);
    }
  }

  bool _aplicarFiltros(PedidoModel p) {
    final rango = _rangoActual();
    if (p.fecha.isBefore(rango.start) || p.fecha.isAfter(rango.end)) {
      return false;
    }
    if (_filtroEstado != 'todos' && p.estado != _filtroEstado) return false;
    if (_filtroTipo != 'todos' && p.tipoPedido != _filtroTipo) return false;
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      final enNombre  = p.clienteNombre.toLowerCase().contains(q);
      final enId      = p.id.toLowerCase().contains(q);
      final enMesa    = p.numeroMesa?.toString().contains(q) ?? false;
      if (!enNombre && !enId && !enMesa) return false;
    }
    return true;
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _kNar, surface: _kCard),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _rangoPersonalizado = picked; _filtroPeriodo = 'rango'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService().obtenerTodosPedidos(),
      builder: (context, snap) {
        final todos     = snap.data ?? [];
        final filtrados = todos.where(_aplicarFiltros).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
        final cargando  = snap.connectionState == ConnectionState.waiting
            && todos.isEmpty;

        return Column(children: [
          // ── Header con búsqueda y toggle vista ─────────────────────────
          _Header(
            ctrl: _searchCtrl,
            vistaKanban: _vistaKanban,
            onSearch: (v) => setState(() => _busqueda = v),
            onToggleVista: () => setState(() => _vistaKanban = !_vistaKanban),
          ),

          // ── Filtros período ─────────────────────────────────────────────
          _FiltroPeriodos(
            seleccionado: _filtroPeriodo,
            onSel: (p) async {
              if (p == 'rango') { await _seleccionarRango(); return; }
              setState(() => _filtroPeriodo = p);
            },
          ),

          // ── Filtros estado + tipo ───────────────────────────────────────
          _FiltrosRow(
            estados: _estados,
            tipos: _tipos,
            filtroEstado: _filtroEstado,
            filtroTipo: _filtroTipo,
            onEstado: (v) => setState(() { _filtroEstado = v; }),
            onTipo:   (v) => setState(() { _filtroTipo = v; }),
          ),

          // ── KPI strip ──────────────────────────────────────────────────
          if (!cargando && filtrados.isNotEmpty)
            _KpiStrip(pedidos: filtrados),

          // ── Contenido principal ─────────────────────────────────────────
          Expanded(child: cargando
              ? const Center(child: CircularProgressIndicator(color: _kNar))
              : filtrados.isEmpty
                  ? _Vacio(hayFiltros: _filtroEstado != 'todos' ||
                        _filtroTipo != 'todos' || _busqueda.isNotEmpty)
                  : _vistaKanban
                      ? _VistaKanban(pedidos: filtrados)
                      : _VistaLista(pedidos: filtrados)),
        ]);
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final TextEditingController ctrl;
  final bool vistaKanban;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleVista;
  const _Header({required this.ctrl, required this.vistaKanban,
      required this.onSearch, required this.onToggleVista});

  @override
  Widget build(BuildContext context) => Container(
    color: _kBg,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Row(children: [
      Expanded(child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: _kCard2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: ctrl,
          onChanged: onSearch,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar cliente, ID, mesa…',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 18),
            suffixIcon: ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { ctrl.clear(); onSearch(''); },
                    child: const Icon(Icons.close, color: Colors.white24, size: 16))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      )),
      const SizedBox(width: 8),
      // Toggle lista/kanban
      GestureDetector(
        onTap: onToggleVista,
        child: Container(
          height: 38, width: 38,
          decoration: BoxDecoration(
            color: vistaKanban
                ? _kNar.withValues(alpha: 0.15) : _kCard2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: vistaKanban
                  ? _kNar.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(
            vistaKanban ? Icons.view_kanban : Icons.list_rounded,
            color: vistaKanban ? _kNar : Colors.white38, size: 18),
        ),
      ),
    ]),
  );
}

// ── Filtros de período ────────────────────────────────────────────────────────
class _FiltroPeriodos extends StatelessWidget {
  final String seleccionado;
  final ValueChanged<String> onSel;
  static const _periodos = [
    ('hoy','Hoy'), ('ayer','Ayer'), ('semana','7d'),
    ('mes','Mes'), ('todos','Todo'), ('rango','📅'),
  ];
  const _FiltroPeriodos({required this.seleccionado, required this.onSel});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Row(children: _periodos.map((p) {
      final sel = seleccionado == p.$1;
      return GestureDetector(
        onTap: () => onSel(p.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? _kNar.withValues(alpha: 0.15) : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel ? _kNar : Colors.white.withValues(alpha: 0.08),
                width: sel ? 1.5 : 1)),
          child: Text(p.$2, style: TextStyle(
              color: sel ? _kNar : Colors.white38,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              fontSize: 12)),
        ),
      );
    }).toList()),
  );
}

// ── Filtros estado + tipo ─────────────────────────────────────────────────────
class _FiltrosRow extends StatelessWidget {
  final List<(String, String, Color)> estados;
  final List<(String, String)> tipos;
  final String filtroEstado, filtroTipo;
  final ValueChanged<String> onEstado, onTipo;
  const _FiltrosRow({required this.estados, required this.tipos,
      required this.filtroEstado, required this.filtroTipo,
      required this.onEstado, required this.onTipo});

  @override
  Widget build(BuildContext context) => Column(children: [
    // Estados
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(children: estados.map((e) {
        final sel   = filtroEstado == e.$1;
        final color = e.$3;
        return GestureDetector(
          onTap: () => onEstado(e.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.15) : _kCard2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? color.withValues(alpha: 0.5)
                      : Colors.transparent)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (e.$1 != 'todos') ...[
                Text(_estadoEmoji(e.$1),
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
              ],
              Text(e.$2, style: TextStyle(
                  color: sel ? color : Colors.white38,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        );
      }).toList()),
    ),
    // Tipos
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(children: tipos.map((t) {
        final sel = filtroTipo == t.$1;
        return GestureDetector(
          onTap: () => onTipo(t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? _kMor.withValues(alpha: 0.12) : _kCard2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? _kMor.withValues(alpha: 0.4)
                      : Colors.transparent)),
            child: Text(t.$2, style: TextStyle(
                color: sel ? _kMor : Colors.white38,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
          ),
        );
      }).toList()),
    ),
  ]);
}

// ── KPI strip ─────────────────────────────────────────────────────────────────
class _KpiStrip extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _KpiStrip({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final entregados = pedidos.where((p) => p.estado == 'Entregado').toList();
    final activos    = pedidos.where((p) =>
        ['Pendiente','Preparando','Listo','En camino'].contains(p.estado)).length;
    final cancelados = pedidos.where((p) => p.estado == 'Cancelado').length;
    final ventas     = entregados.fold(0.0, (s, p) => s + p.total);
    final ticket     = entregados.isEmpty ? 0.0 : ventas / entregados.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        _Kpi('💰', '\$${ventas.toStringAsFixed(0)}', 'Ventas',    _kVerde),
        _Sep(),
        _Kpi('📦', '${entregados.length}',            'Entregados', _kAzul),
        _Sep(),
        _Kpi('🔄', '$activos',                        'Activos',   _kNar),
        _Sep(),
        _Kpi('🎯', '\$${ticket.toStringAsFixed(0)}',  'Ticket',    _kMor),
        _Sep(),
        _Kpi('❌', '$cancelados',                      'Cancel.',   Colors.red),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String emoji, valor, label;
  final Color color;
  const _Kpi(this.emoji, this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      Text(valor, style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 14)),
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
    ],
  ));
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 28,
      color: Colors.white.withValues(alpha: 0.06));
}

// ── Vista lista ───────────────────────────────────────────────────────────────
class _VistaLista extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _VistaLista({required this.pedidos});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
    itemCount: pedidos.length,
    itemBuilder: (_, i) => _PedidoCard(pedido: pedidos[i]),
  );
}

// ── Tarjeta de pedido ─────────────────────────────────────────────────────────
class _PedidoCard extends StatefulWidget {
  final PedidoModel pedido;
  const _PedidoCard({required this.pedido});
  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final p     = widget.pedido;
    final color = _estadoColor(p.estado);
    final hora  = '${p.fecha.hour.toString().padLeft(2,'0')}:'
        '${p.fecha.minute.toString().padLeft(2,'0')}';
    final fecha = '${p.fecha.day}/${p.fecha.month} $hora';
    final tipoLabel = p.tipoPedido == 'mesa'
        ? '🍽️ Mesa ${p.numeroMesa}'
        : p.tipoPedido == 'retirar' ? '🏃 Retirar' : '🛵 Domicilio';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _expandido
                  ? color.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: _expandido
                  ? const BorderRadius.vertical(top: Radius.circular(13))
                  : BorderRadius.circular(13),
            ),
            child: Row(children: [
              // Emoji estado
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(_estadoEmoji(p.estado),
                    style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.clienteNombre,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(p.estado, style: TextStyle(
                        color: color, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text(tipoLabel, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
                  const SizedBox(width: 8),
                  Text('·', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2))),
                  const SizedBox(width: 8),
                  Text(fecha, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11)),
                  const Spacer(),
                  Text('\$${p.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: _kVerde, fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ]),
              ])),
              const SizedBox(width: 6),
              Icon(
                _expandido
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white24, size: 20),
            ]),
          ),
        ),

        // ── Detalle expandido ────────────────────────────────────────────
        if (_expandido)
          _DetalleCard(pedido: p, color: color),
      ]),
    );
  }
}

// ── Detalle del pedido ────────────────────────────────────────────────────────
class _DetalleCard extends StatelessWidget {
  final PedidoModel pedido;
  final Color color;
  const _DetalleCard({required this.pedido, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
        border: Border(top: BorderSide(
            color: color.withValues(alpha: 0.1))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),

        // ID copiable
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: p.id));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('📋 ID copiado'),
              backgroundColor: _kCard,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ));
          },
          child: Row(children: [
            Icon(Icons.tag, size: 13,
                color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 4),
            Text('${p.id.substring(0, 12)}…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Icon(Icons.copy_outlined, size: 11,
                color: Colors.white.withValues(alpha: 0.2)),
          ]),
        ),
        const SizedBox(height: 12),

        // Productos
        Text('PRODUCTOS', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3), fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        ...p.items.map((item) {
          final nombre = item['productoNombre'] ?? item['nombre'] ?? '';
          final cant   = (item['cantidad'] ?? 1) as int;
          final precio = ((item['precioTotal'] ?? item['precio'] ?? 0) as num)
              .toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kCard2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('$cant', style: TextStyle(
                    color: color, fontWeight: FontWeight.w900,
                    fontSize: 12))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(nombre, style: const TextStyle(
                  color: Colors.white, fontSize: 13))),
              Text('\$${precio.toStringAsFixed(2)}', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12)),
            ]),
          );
        }),

        // Notas
        if (p.notasEspeciales?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('📝 ', style: TextStyle(fontSize: 12)),
              Expanded(child: Text(p.notasEspeciales!,
                  style: const TextStyle(color: Colors.amber,
                      fontSize: 12))),
            ]),
          ),
        ],

        const SizedBox(height: 10),
        Divider(color: Colors.white.withValues(alpha: 0.06)),

        // Info adicional
        if (p.tipoPedido != 'mesa' && p.direccionEntrega != null) ...[
          _InfoFila(Icons.location_on_outlined,
              p.direccionEntrega!['direccion']?.toString() ?? '',
              Colors.redAccent),
          if ((p.direccionEntrega?['referencia'] ?? '').toString().isNotEmpty)
            _InfoFila(Icons.info_outline,
                p.direccionEntrega!['referencia'].toString(),
                Colors.white38),
        ],
        if (p.tipoPedido == 'mesa')
          _InfoFila(Icons.table_restaurant_outlined,
              'Mesa ${p.numeroMesa}', Colors.purple),
        if (p.clienteTelefono != null)
          _InfoFila(Icons.phone_outlined, p.clienteTelefono!, _kAzul),
        _InfoFila(Icons.payment_outlined,
            p.metodoPago.toUpperCase(), _kAmb),

        // Totales
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Subtotal', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
          Text('\$${p.subtotal.toStringAsFixed(2)}', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          Text('\$${p.total.toStringAsFixed(2)}',
              style: const TextStyle(color: _kVerde,
                  fontWeight: FontWeight.w900, fontSize: 16)),
        ]),

        const SizedBox(height: 14),

        // ── Cambiar estado con botones ──────────────────────────────────
        _CambiarEstadoBtns(pedido: p),
      ]),
    );
  }
}

// ── Info fila ────────────────────────────────────────────────────────────────
class _InfoFila extends StatelessWidget {
  final IconData icono;
  final String valor;
  final Color color;
  const _InfoFila(this.icono, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, size: 14, color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 8),
      Expanded(child: Text(valor, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5), fontSize: 12))),
    ]),
  );
}

// ── Cambiar estado con botones visuales ───────────────────────────────────────
class _CambiarEstadoBtns extends StatefulWidget {
  final PedidoModel pedido;
  const _CambiarEstadoBtns({required this.pedido});
  @override
  State<_CambiarEstadoBtns> createState() => _CambiarEstadoBtnsState();
}

class _CambiarEstadoBtnsState extends State<_CambiarEstadoBtns> {
  bool _cargando = false;
  String? _cambiando;

  static const _flujo = [
    'Pendiente', 'Preparando', 'Listo', 'En camino', 'Entregado'
  ];

  Future<void> _cambiar(String nuevo) async {
    setState(() { _cargando = true; _cambiando = nuevo; });
    await PedidoService().actualizarEstado(widget.pedido.id, nuevo);
    if (mounted) {
      setState(() { _cargando = false; _cambiando = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_estadoEmoji(nuevo)} Estado → $nuevo'),
        backgroundColor: _estadoColor(nuevo),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.pedido.estado;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CAMBIAR ESTADO', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 8),

      // Barra de flujo
      Row(children: _flujo.asMap().entries.map((e) {
        final i     = e.key;
        final est   = e.value;
        final color = _estadoColor(est);
        final esActual   = est == actual;
        final anterior   = _flujo.indexOf(actual) > i;
        final esCambiando = _cambiando == est;

        return Expanded(child: GestureDetector(
          onTap: (_cargando || esActual) ? null : () => _cambiar(est),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 32, width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: esActual
                    ? color.withValues(alpha: 0.2)
                    : anterior
                        ? color.withValues(alpha: 0.08)
                        : _kCard2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: esActual
                        ? color.withValues(alpha: 0.7)
                        : anterior
                            ? color.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                    width: esActual ? 2 : 1),
              ),
              child: Center(child: esCambiando
                  ? SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Text(_estadoEmoji(est),
                      style: const TextStyle(fontSize: 14))),
            ),
            const SizedBox(height: 3),
            Text(est, textAlign: TextAlign.center,
                style: TextStyle(
                    color: esActual
                        ? color : Colors.white.withValues(alpha: 0.25),
                    fontSize: 8,
                    fontWeight: esActual ? FontWeight.w700 : FontWeight.w400),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ));
      }).toList()),

      const SizedBox(height: 8),
      // Botón cancelar siempre disponible
      if (actual != 'Cancelado' && actual != 'Entregado')
        GestureDetector(
          onTap: _cargando ? null : () => _cambiar('Cancelado'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text('❌', style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Text('Cancelar pedido', style: TextStyle(
                  color: Colors.redAccent, fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
    ]);
  }
}

// ── Vista Kanban ──────────────────────────────────────────────────────────────
class _VistaKanban extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _VistaKanban({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final columnas = [
      ('Pendiente',  Colors.orange),
      ('Preparando', _kAzul),
      ('Listo',      _kAmb),
      ('En camino',  Colors.indigo),
      ('Entregado',  _kVerde),
    ];

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: columnas.map((col) {
        final peds = pedidos.where((p) => p.estado == col.$1).toList();
        return Container(
          width: 220,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Header columna
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: col.$2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: col.$2.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Text(_estadoEmoji(col.$1),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(child: Text(col.$1, style: TextStyle(
                    color: col.$2, fontWeight: FontWeight.w700,
                    fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: col.$2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${peds.length}', style: TextStyle(
                      color: col.$2, fontWeight: FontWeight.w900,
                      fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            // Cards
            Expanded(child: peds.isEmpty
                ? Center(child: Text('Sin pedidos',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 12)))
                : ListView.builder(
                    itemCount: peds.length,
                    itemBuilder: (_, i) {
                      final p = peds[i];
                      final hora = '${p.fecha.hour.toString().padLeft(2,'0')}:'
                          '${p.fecha.minute.toString().padLeft(2,'0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: col.$2.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Expanded(child: Text(p.clienteNombre,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                            Text('\$${p.total.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: col.$2,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text(p.tipoPedido == 'mesa'
                                ? '🍽️ Mesa ${p.numeroMesa}'
                                : p.tipoPedido == 'retirar'
                                    ? '🏃 Retirar' : '🛵',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 10)),
                            const Spacer(),
                            Text(hora, style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 10)),
                          ]),
                          if (p.items.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              p.items.take(2).map((i) =>
                                  '${i['cantidad']}× ${i['productoNombre'] ?? i['nombre'] ?? ''}'
                              ).join(', ') + (p.items.length > 2 ? '…' : ''),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 9),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ]),
                      );
                    },
                  )),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Vacío ─────────────────────────────────────────────────────────────────────
class _Vacio extends StatelessWidget {
  final bool hayFiltros;
  const _Vacio({required this.hayFiltros});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(hayFiltros ? '🔍' : '📦',
        style: const TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    Text(hayFiltros
        ? 'Sin resultados para este filtro'
        : 'Sin pedidos en este período',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
  ]));
}
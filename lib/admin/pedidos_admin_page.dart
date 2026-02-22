import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';
import '../pedidos/pedidos_service.dart';

class PedidosAdminPage extends StatefulWidget {
  const PedidosAdminPage({super.key});
  @override
  State<PedidosAdminPage> createState() => _PedidosAdminPageState();
}

class _PedidosAdminPageState extends State<PedidosAdminPage> {
  // Filtros
  String _filtroEstado  = 'todos';
  String _filtroTipo    = 'todos';
  String _filtroPeriodo = 'hoy';
  DateTimeRange? _rangoPersonalizado;
  String _busqueda      = '';

  final _searchCtrl = TextEditingController();

  static const _estados = [
    ('todos',      'Todos',      Icons.all_inbox,        Colors.purple),
    ('Pendiente',  'Pendiente',  Icons.schedule,         Colors.orange),
    ('Preparando', 'Preparando', Icons.restaurant,       Colors.blue),
    ('Listo',      'Listo',      Icons.check_circle,     Colors.green),
    ('En camino',  'En camino',  Icons.delivery_dining,  Colors.indigo),
    ('Entregado',  'Entregado',  Icons.done_all,         Colors.teal),
    ('Cancelado',  'Cancelado',  Icons.cancel,           Colors.red),
  ];

  static const _periodos = [
    ('hoy',       'Hoy'),
    ('ayer',      'Ayer'),
    ('semana',    '7 días'),
    ('mes',       'Este mes'),
    ('todos',     'Todos'),
    ('rango',     'Rango...'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTimeRange _rangoActual() {
    final ahora = DateTime.now();
    switch (_filtroPeriodo) {
      case 'hoy':
        final inicio = DateTime(ahora.year, ahora.month, ahora.day);
        return DateTimeRange(start: inicio, end: ahora);
      case 'ayer':
        final ayer = ahora.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(ayer.year, ayer.month, ayer.day),
          end: DateTime(ayer.year, ayer.month, ayer.day, 23, 59, 59),
        );
      case 'semana':
        return DateTimeRange(start: ahora.subtract(const Duration(days: 7)), end: ahora);
      case 'mes':
        return DateTimeRange(start: DateTime(ahora.year, ahora.month, 1), end: ahora);
      case 'rango':
        if (_rangoPersonalizado != null) return _rangoPersonalizado!;
        return DateTimeRange(start: ahora.subtract(const Duration(days: 30)), end: ahora);
      default: // 'todos'
        return DateTimeRange(start: DateTime(2024, 1, 1), end: ahora);
    }
  }

  List<PedidoModel> _aplicarFiltros(List<PedidoModel> todos) {
    final rango = _rangoActual();
    return todos.where((p) {
      if (_filtroEstado != 'todos' && p.estado != _filtroEstado) return false;
      if (_filtroTipo != 'todos' && p.tipoPedido != _filtroTipo) return false;
      if (p.fecha.isBefore(rango.start) || p.fecha.isAfter(rango.end)) return false;
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        final enNombre  = p.clienteNombre.toLowerCase().contains(q);
        final enEmail   = (p.clienteEmail ?? '').toLowerCase().contains(q);
        final enId      = p.id.toLowerCase().contains(q);
        final enMesa    = p.numeroMesa?.toString().contains(q) ?? false;
        if (!enNombre && !enEmail && !enId && !enMesa) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _rangoPersonalizado,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.purple),
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
        final todos    = snap.data ?? [];
        final filtrados = _aplicarFiltros(todos);
        final cargando = snap.connectionState == ConnectionState.waiting;

        return Column(children: [
          // ── Barra de búsqueda ──
          _BarraBusqueda(
            ctrl: _searchCtrl,
            onChanged: (v) => setState(() => _busqueda = v),
          ),

          // ── Filtro período ──
          _FiltroPeriodo(
            seleccionado: _filtroPeriodo,
            rangoPersonalizado: _rangoPersonalizado,
            onSeleccionar: (p) async {
              if (p == 'rango') { await _seleccionarRango(); return; }
              setState(() => _filtroPeriodo = p);
            },
          ),

          // ── Filtros estado + tipo ──
          _FiltrosEstadoTipo(
            filtroEstado: _filtroEstado,
            filtroTipo: _filtroTipo,
            onEstado: (v) => setState(() => _filtroEstado = v),
            onTipo:   (v) => setState(() => _filtroTipo = v),
          ),

          // ── KPIs del período filtrado ──
          if (!cargando && filtrados.isNotEmpty)
            _KpiStrip(pedidos: filtrados),

          // ── Lista ──
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                : filtrados.isEmpty
                    ? _Vacio(
                        tienesFiltros: _filtroEstado != 'todos' ||
                            _filtroTipo != 'todos' || _busqueda.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) => _PedidoAdminCard(pedido: filtrados[i]),
                      ),
          ),
        ]);
      },
    );
  }
}

// ── Barra de búsqueda ────────────────────────────────────────
class _BarraBusqueda extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  const _BarraBusqueda({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.purple.shade50,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    child: TextField(
      controller: ctrl,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar por cliente, email, ID o mesa...',
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: const Icon(Icons.search, color: Colors.purple, size: 20),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () { ctrl.clear(); onChanged(''); })
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple.shade100)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.purple, width: 1.5)),
      ),
    ),
  );
}

// ── Filtro de período ────────────────────────────────────────
class _FiltroPeriodo extends StatelessWidget {
  final String seleccionado;
  final DateTimeRange? rangoPersonalizado;
  final Future<void> Function(String) onSeleccionar;

  const _FiltroPeriodo({
    required this.seleccionado,
    required this.rangoPersonalizado,
    required this.onSeleccionar,
  });

  static const _periodos = [
    ('hoy', 'Hoy'), ('ayer', 'Ayer'), ('semana', '7 días'),
    ('mes', 'Este mes'), ('todos', 'Todos'), ('rango', '📅 Rango'),
  ];

  @override
  Widget build(BuildContext context) {
    String labelRango = '📅 Rango';
    if (seleccionado == 'rango' && rangoPersonalizado != null) {
      final r = rangoPersonalizado!;
      labelRango = '${r.start.day}/${r.start.month} – ${r.end.day}/${r.end.month}';
    }

    return Container(
      color: Colors.purple.shade50,
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _periodos.map((p) {
            final (val, label) = p;
            final displayLabel = val == 'rango' ? labelRango : label;
            final sel = seleccionado == val;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSeleccionar(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? Colors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.purple : Colors.grey.shade300),
                  ),
                  child: Text(displayLabel, style: TextStyle(
                    fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : Colors.grey.shade700,
                  )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Filtros estado + tipo en una fila ────────────────────────
class _FiltrosEstadoTipo extends StatelessWidget {
  final String filtroEstado, filtroTipo;
  final ValueChanged<String> onEstado, onTipo;
  const _FiltrosEstadoTipo({
    required this.filtroEstado, required this.filtroTipo,
    required this.onEstado, required this.onTipo,
  });

  static const _estados = [
    ('todos', '🔘 Todos'), ('Pendiente', '⏳ Pendiente'), ('Preparando', '👨‍🍳 Cocina'),
    ('Listo', '✅ Listo'), ('En camino', '🛵 En camino'),
    ('Entregado', '🏠 Entregado'), ('Cancelado', '❌ Cancelado'),
  ];
  static const _tipos = [
    ('todos', 'Mesa + Dom.'), ('mesa', '🍽️ Mesa'), ('domicilio', '🛵 Domicilio'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.purple.shade50,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Estados
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _estados.map((e) {
          final (val, label) = e;
          final sel = filtroEstado == val;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onEstado(val),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? Colors.purple.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? Colors.purple : Colors.grey.shade300),
                ),
                child: Text(label, style: TextStyle(
                  fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  color: sel ? Colors.white : Colors.grey.shade600,
                )),
              ),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 6),
      // Tipos
      Row(children: _tipos.map((t) {
        final (val, label) = t;
        final sel = filtroTipo == val;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onTipo(val),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sel ? Colors.indigo : Colors.grey.shade300),
              ),
              child: Text(label, style: TextStyle(
                fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? Colors.white : Colors.grey.shade600,
              )),
            ),
          ),
        );
      }).toList()),
    ]),
  );
}

// ── KPIs strip ───────────────────────────────────────────────
class _KpiStrip extends StatelessWidget {
  final List<PedidoModel> pedidos;
  const _KpiStrip({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final entregados  = pedidos.where((p) => p.estado == 'Entregado').toList();
    final cancelados  = pedidos.where((p) => p.estado == 'Cancelado').length;
    final activos     = pedidos.where((p) => !['Entregado','Cancelado'].contains(p.estado)).length;
    final totalVentas = entregados.fold(0.0, (s, p) => s + p.total);
    final domicilios  = pedidos.where((p) => p.tipoPedido == 'domicilio').length;
    final mesas       = pedidos.where((p) => p.tipoPedido == 'mesa').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${pedidos.length} pedidos encontrados',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text('\$${totalVentas.toStringAsFixed(2)} en ventas',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _KpiChip('✅ Entregados', entregados.length, Colors.green),
            _KpiChip('🔄 Activos', activos, Colors.orange),
            _KpiChip('❌ Cancelados', cancelados, Colors.red),
            _KpiChip('🍽️ Mesa', mesas, Colors.teal),
            _KpiChip('🛵 Domicilio', domicilios, Colors.indigo),
          ]),
        ),
      ]),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label; final int value; final Color color;
  const _KpiChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text('$label: $value',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );
}

// ── Estado vacío ─────────────────────────────────────────────
class _Vacio extends StatelessWidget {
  final bool tienesFiltros;
  const _Vacio({required this.tienesFiltros});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(tienesFiltros ? Icons.filter_list_off : Icons.inbox,
          size: 80, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(tienesFiltros ? 'Sin resultados para ese filtro' : 'No hay pedidos',
          style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
      if (tienesFiltros) ...[
        const SizedBox(height: 8),
        Text('Prueba ajustando los filtros',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ],
    ]),
  );
}

// ── Tarjeta de pedido ────────────────────────────────────────
class _PedidoAdminCard extends StatelessWidget {
  final PedidoModel pedido;
  const _PedidoAdminCard({required this.pedido});

  Color get _color {
    switch (pedido.estado) {
      case 'Pendiente':  return Colors.orange;
      case 'Preparando': return Colors.blue;
      case 'Listo':      return Colors.green;
      case 'En camino':  return Colors.indigo;
      case 'Entregado':  return Colors.teal;
      case 'Cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final esMesa = pedido.tipoPedido == 'mesa';
    final fecha = pedido.fecha;
    final fechaStr =
        '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')} '
        '${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(pedido.iconoEstado, style: const TextStyle(fontSize: 18)),
        ),
        title: Row(children: [
          Expanded(child: Text(pedido.clienteNombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          _EstadoBadge(estado: pedido.estado, color: color),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(esMesa ? Icons.table_restaurant : Icons.delivery_dining,
                size: 13, color: Colors.grey),
            const SizedBox(width: 3),
            Text(esMesa ? 'Mesa ${pedido.numeroMesa ?? "?"}' : 'Domicilio',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 10),
            Icon(Icons.schedule, size: 13, color: Colors.grey),
            const SizedBox(width: 3),
            Text(fechaStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const Spacer(),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
          ]),
        ),
        children: [
          _DetalleExpandido(pedido: pedido, color: color),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado; final Color color;
  const _EstadoBadge({required this.estado, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(estado,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );
}

// ── Detalle expandido ────────────────────────────────────────
class _DetalleExpandido extends StatelessWidget {
  final PedidoModel pedido;
  final Color color;
  const _DetalleExpandido({required this.pedido, required this.color});

  @override
  Widget build(BuildContext context) {
    final esMesa = pedido.tipoPedido == 'mesa';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),

        // ID copiable
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: pedido.id));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ID copiado'), duration: Duration(seconds: 1)));
          },
          child: Row(children: [
            Icon(Icons.tag, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('ID: ${pedido.id.substring(0, 12)}...',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
          ]),
        ),
        const SizedBox(height: 10),

        // Productos
        const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ...pedido.items.map((item) {
          final precio = ((item['precioTotal'] ?? item['precio'] ?? 0) as num).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${item['cantidad']}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  item['productoNombre'] ?? item['nombre'] ?? '',
                  style: const TextStyle(fontSize: 13))),
              Text('\$${precio.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          );
        }),

        const Divider(),

        // Resumen precios
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('\$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
        ]),
        const SizedBox(height: 10),

        // Info adicional
        if (!esMesa && pedido.direccionEntrega != null) ...[
          _InfoRow(Icons.location_on, 'Dirección',
              pedido.direccionEntrega!['direccion'] ?? ''),
          if ((pedido.direccionEntrega!['referencia'] ?? '').toString().isNotEmpty)
            _InfoRow(Icons.info_outline, 'Referencia',
                pedido.direccionEntrega!['referencia'].toString()),
        ],
        if (esMesa)
          _InfoRow(Icons.table_restaurant, 'Mesa', '${pedido.numeroMesa}'),
        if (pedido.clienteEmail != null)
          _InfoRow(Icons.email, 'Email', pedido.clienteEmail!),
        if (pedido.clienteTelefono != null)
          _InfoRow(Icons.phone, 'Teléfono', pedido.clienteTelefono!),
        _InfoRow(Icons.payment, 'Pago', pedido.metodoPago),
        if (pedido.notasEspeciales?.isNotEmpty == true)
          _InfoRow(Icons.note, 'Notas', pedido.notasEspeciales!),

        const SizedBox(height: 10),

        // Cambiar estado
        _CambiarEstado(pedido: pedido, color: color),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
    ]),
  );
}

// ── Cambiar estado ───────────────────────────────────────────
class _CambiarEstado extends StatefulWidget {
  final PedidoModel pedido; final Color color;
  const _CambiarEstado({required this.pedido, required this.color});
  @override
  State<_CambiarEstado> createState() => _CambiarEstadoState();
}

class _CambiarEstadoState extends State<_CambiarEstado> {
  bool _cargando = false;
  static const _todosEstados = [
    'Pendiente', 'Preparando', 'Listo', 'En camino', 'Entregado', 'Cancelado'
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.purple.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.swap_horiz, size: 16, color: Colors.purple),
      const SizedBox(width: 8),
      const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.pedido.estado,
            isDense: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: _todosEstados.map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: _cargando ? null : (nuevo) async {
              if (nuevo == null || nuevo == widget.pedido.estado) return;
              setState(() => _cargando = true);
              await PedidoService().actualizarEstado(widget.pedido.id, nuevo);
              if (mounted) {
                setState(() => _cargando = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ Estado cambiado a $nuevo'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
        ),
      ),
      if (_cargando)
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)),
    ]),
  );
}
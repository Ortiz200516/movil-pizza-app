import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reserva_model.dart';
import '../services/reservas_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);
const _kNar   = Color(0xFFFF6B35);
const _kVerde = Color(0xFF4ADE80);
const _kAzul  = Color(0xFF38BDF8);
const _kMor   = Color(0xFFA78BFA);

// ── Horarios disponibles ──────────────────────────────────────────────────────
const _kHorarios = [
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
  '18:00', '18:30', '19:00', '19:30', '20:00', '20:30', '21:00', '21:30',
];

// ── Página principal de reservas del cliente ──────────────────────────────────
class ReservasPage extends StatefulWidget {
  const ReservasPage({super.key});
  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        tabs: const [
          Tab(text: 'Nueva reserva'),
          Tab(text: 'Mis reservas'),
        ],
      ),
    ),
    body: TabBarView(controller: _tabs, children: [
      _FormReserva(onReservada: () => _tabs.animateTo(1)),
      const _MisReservas(),
    ]),
  );
}

// ── Formulario para crear reserva ────────────────────────────────────────────
class _FormReserva extends StatefulWidget {
  final VoidCallback onReservada;
  const _FormReserva({required this.onReservada});
  @override
  State<_FormReserva> createState() => _FormReservaState();
}

class _FormReservaState extends State<_FormReserva> {
  final _svc        = ReservasService();
  final _telCtrl    = TextEditingController();
  final _notasCtrl  = TextEditingController();

  DateTime  _fecha      = DateTime.now().add(const Duration(days: 1));
  String?   _hora;
  int       _personas   = 2;
  int?      _mesa;
  bool      _cargando   = false;
  bool      _exito      = false;
  List<int> _mesasDisp  = [];
  bool      _cargandoMesas = false;

  @override
  void dispose() {
    _telCtrl.dispose(); _notasCtrl.dispose(); super.dispose();
  }

  Future<void> _cargarMesas() async {
    if (_hora == null) return;
    setState(() => _cargandoMesas = true);
    final disp = await _svc.mesasDisponibles(_fecha, _hora!);
    setState(() { _mesasDisp = disp; _mesa = null; _cargandoMesas = false; });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _kNar, surface: _kCard),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _fecha = picked; _mesa = null; _mesasDisp = []; });
      if (_hora != null) _cargarMesas();
    }
  }

  Future<void> _reservar() async {
    if (_hora == null) {
      _snack('Selecciona una hora'); return;
    }
    if (_mesa == null) {
      _snack('Selecciona una mesa'); return;
    }
    if (_telCtrl.text.trim().isEmpty) {
      _snack('Ingresa tu teléfono de contacto'); return;
    }

    setState(() => _cargando = true);
    try {
      final result = await _svc.crearReserva(
        numeroMesa: _mesa!,
        personas:   _personas,
        fecha:      _fecha,
        hora:       _hora!,
        notas:      _notasCtrl.text.trim(),
        telefono:   _telCtrl.text.trim(),
      );

      if (!mounted) return;
      if (result == 'ocupada') {
        _snack('Esa mesa ya está reservada para esa hora. Elige otra.');
        await _cargarMesas();
      } else if (result != null) {
        HapticFeedback.heavyImpact();
        setState(() => _exito = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) widget.onReservada();
      } else {
        _snack('Error al crear la reserva. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          backgroundColor: _kCard));

  @override
  Widget build(BuildContext context) {
    if (_exito) return _PantallaExitoReserva(
        fecha: _fecha, hora: _hora!, mesa: _mesa!, personas: _personas);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Fecha ──────────────────────────────────────────────────────────
        _SecTit('📅 Fecha'),
        _Selector(
          label: _fechaLabel(_fecha),
          icono: Icons.calendar_today_outlined,
          color: _kAzul,
          onTap: _seleccionarFecha,
        ),
        const SizedBox(height: 16),

        // ── Hora ───────────────────────────────────────────────────────────
        _SecTit('🕐 Hora'),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kHorarios.map((h) {
            final sel = _hora == h;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() { _hora = h; _mesa = null; _mesasDisp = []; });
                _cargarMesas();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _kNar.withValues(alpha: 0.15) : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? _kNar : Colors.white.withValues(alpha: 0.08),
                      width: sel ? 1.5 : 1),
                ),
                child: Text(h, style: TextStyle(
                    color: sel ? _kNar : Colors.white54,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Personas ───────────────────────────────────────────────────────
        _SecTit('👥 Personas'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(children: [
            Text('$_personas persona${_personas != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            _BtnCant(
              icono: Icons.remove,
              onTap: () { if (_personas > 1) setState(() => _personas--); },
              activo: _personas > 1,
            ),
            const SizedBox(width: 8),
            _BtnCant(
              icono: Icons.add,
              onTap: () { if (_personas < 12) setState(() => _personas++); },
              activo: _personas < 12,
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Mesa ───────────────────────────────────────────────────────────
        _SecTit('🪑 Mesa'),
        if (_hora == null)
          _Aviso('Selecciona una hora para ver las mesas disponibles',
              Icons.info_outline, Colors.white24)
        else if (_cargandoMesas)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(
                color: _kNar, strokeWidth: 2)),
          )
        else if (_mesasDisp.isEmpty)
          _Aviso('No hay mesas disponibles para esa fecha y hora',
              Icons.warning_amber_rounded, Colors.orange)
        else
          Wrap(spacing: 8, runSpacing: 8,
            children: _mesasDisp.map((m) {
              final sel = _mesa == m;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _mesa = m);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: sel
                        ? _kVerde.withValues(alpha: 0.12)
                        : _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel
                            ? _kVerde
                            : Colors.white.withValues(alpha: 0.08),
                        width: sel ? 2 : 1),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text('🪑', style: TextStyle(
                        fontSize: sel ? 22 : 18)),
                    Text('Mesa $m', style: TextStyle(
                        color: sel ? _kVerde : Colors.white54,
                        fontSize: 11, fontWeight: sel
                            ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),

        // ── Teléfono ───────────────────────────────────────────────────────
        _SecTit('📞 Teléfono de contacto'),
        _Campo(_telCtrl, 'Ej: 0991234567',
            Icons.phone_outlined, TextInputType.phone),
        const SizedBox(height: 16),

        // ── Notas ──────────────────────────────────────────────────────────
        _SecTit('📝 Notas especiales (opcional)'),
        _Campo(_notasCtrl,
            'Cumpleaños, alergias, preferencias de ubicación…',
            Icons.edit_note, TextInputType.multiline, maxLines: 3),
        const SizedBox(height: 24),

        // ── Botón reservar ─────────────────────────────────────────────────
        GestureDetector(
          onTap: (_cargando || _mesa == null || _hora == null)
              ? null : _reservar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: (_mesa != null && _hora != null)
                  ? _kNar : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: _cargando
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Text('🍽️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    _mesa != null && _hora != null
                        ? 'Reservar Mesa $_mesa · $_hora'
                        : 'Completa los campos',
                    style: TextStyle(
                      color: (_mesa != null && _hora != null)
                          ? Colors.white : Colors.white24,
                      fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ])),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ── Pantalla de éxito ─────────────────────────────────────────────────────────
class _PantallaExitoReserva extends StatelessWidget {
  final DateTime fecha;
  final String hora;
  final int mesa, personas;
  const _PantallaExitoReserva({required this.fecha, required this.hora,
      required this.mesa, required this.personas});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kVerde.withValues(alpha: 0.1),
          border: Border.all(color: _kVerde.withValues(alpha: 0.3), width: 2),
        ),
        child: const Center(child: Text('✅', style: TextStyle(fontSize: 46))),
      ),
      const SizedBox(height: 20),
      const Text('¡Reserva enviada!', style: TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('Te confirmaremos pronto', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kNar.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          _FilaResumen('🪑 Mesa',     'Mesa $mesa'),
          _FilaResumen('📅 Fecha',    _fechaLabel(fecha)),
          _FilaResumen('🕐 Hora',     hora),
          _FilaResumen('👥 Personas', '$personas persona${personas != 1 ? 's' : ''}'),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: const Text(
          '⏳ Estado: Pendiente de confirmación\n'
          'El local revisará tu solicitud y te avisará.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.orange, fontSize: 12)),
      ),
    ]),
  ));
}

class _FilaResumen extends StatelessWidget {
  final String label, valor;
  const _FilaResumen(this.label, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
      const Spacer(),
      Text(valor, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

// ── Mis reservas ──────────────────────────────────────────────────────────────
class _MisReservas extends StatelessWidget {
  const _MisReservas();

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

  String _label(String e) {
    switch (e) {
      case 'confirmada':  return 'Confirmada';
      case 'rechazada':   return 'Rechazada';
      case 'cancelada':   return 'Cancelada';
      case 'completada':  return 'Completada';
      default:            return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReservaModel>>(
      stream: ReservasService().streamMisReservas(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: _kNar));

        if (snap.data!.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🍽️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('Sin reservas aún', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Haz tu primera reserva en la pestaña anterior',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13)),
        ]));

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: snap.data!.length,
          itemBuilder: (_, i) {
            final r = snap.data![i];
            final color = _color(r.estado);
            final puedeCanc = r.estado == 'pendiente' || r.estado == 'confirmada';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_emoji(r.estado),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Mesa ${r.numeroMesa} · ${r.hora}',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${r.fechaCorta} · ${r.personas} persona${r.personas != 1 ? 's' : ''}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(_label(r.estado), style: TextStyle(
                        color: color, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
                if (r.notasAdmin?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('📝 ${r.notasAdmin}', style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                  ),
                ],
                if (puedeCanc) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: _kCard,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          title: const Text('¿Cancelar reserva?',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          content: Text(
                              'Mesa ${r.numeroMesa} · ${r.fechaCorta} · ${r.hora}',
                              style: const TextStyle(color: Colors.white54)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No',
                                    style: TextStyle(color: Colors.white38))),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    elevation: 0),
                                child: const Text('Sí, cancelar')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ReservasService().cancelarReserva(r.id);
                      }
                    },
                    child: Row(children: [
                      Icon(Icons.cancel_outlined,
                          color: Colors.red.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 6),
                      Text('Cancelar reserva', style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.7),
                          fontSize: 12)),
                    ]),
                  ),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
String _fechaLabel(DateTime f) {
  final hoy    = DateTime.now();
  final manana = hoy.add(const Duration(days: 1));
  if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day)
    return 'Hoy, ${f.day}/${f.month}/${f.year}';
  if (f.year == manana.year && f.month == manana.month && f.day == manana.day)
    return 'Mañana, ${f.day}/${f.month}/${f.year}';
  return '${f.day}/${f.month}/${f.year}';
}

class _Selector extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  const _Selector({required this.label, required this.icono,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icono, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600,
            fontSize: 14))),
        Icon(Icons.chevron_right_rounded,
            color: Colors.white24, size: 20),
      ]),
    ),
  );
}

class _BtnCant extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  final bool activo;
  const _BtnCant({required this.icono, required this.onTap,
      required this.activo});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: activo ? () { HapticFeedback.lightImpact(); onTap(); } : null,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: activo ? _kNar.withValues(alpha: 0.15) : _kCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: activo ? _kNar.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Icon(icono,
          color: activo ? _kNar : Colors.white24, size: 18),
    ),
  );
}

Widget _Campo(TextEditingController ctrl, String hint, IconData icon,
    TextInputType tipo, {int maxLines = 1}) =>
    TextField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );

Widget _Aviso(String msg, IconData icon, Color color) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.withValues(alpha: 0.15)),
  ),
  child: Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 10),
    Expanded(child: Text(msg, style: TextStyle(
        color: color, fontSize: 12))),
  ]),
);

Widget _SecTit(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(t.toUpperCase(), style: TextStyle(
      color: Colors.white.withValues(alpha: 0.3), fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 1)),
);
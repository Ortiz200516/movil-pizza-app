import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fidelidad_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF0F172A);
const _kCard  = Color(0xFF1E293B);
const _kCard2 = Color(0xFF263348);

// ── Widget embebible para home_cliente (tarjeta compacta) ─────────────────────
class FidelidadCard extends StatelessWidget {
  final VoidCallback? onTap;
  const FidelidadCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: FidelidadService().streamPuntos(),
      builder: (_, snap) {
        final data    = snap.data ?? {'puntos': 0, 'puntosHistorico': 0};
        final puntos  = data['puntos'] as int;
        final hist    = data['puntosHistorico'] as int;
        final nivel   = nivelDePuntos(puntos);
        final siguiente = kNiveles.indexOf(nivel) < kNiveles.length - 1
            ? kNiveles[kNiveles.indexOf(nivel) + 1]
            : null;
        final progreso = siguiente == null ? 1.0
            : (puntos - nivel.puntosMin) /
              (siguiente.puntosMin - nivel.puntosMin).clamp(1, double.infinity);
        final color = Color(int.parse('FF${nivel.colorHex}', radix: 16));

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text(nivel.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text('Nivel ${nivel.nombre}',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const Spacer(),
                    Text('$puntos pts',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ]),
                  if (siguiente != null)
                    Text('${siguiente.puntosMin - puntos} pts para ${siguiente.emoji} ${siguiente.nombre}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11)),
                ])),
              ]),
              const SizedBox(height: 10),
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progreso.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('× ${nivel.multiplicador}x puntos por compra',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11)),
                const Spacer(),
                Text('≈ \$${puntosToDolares(puntos).toStringAsFixed(2)} en descuentos',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ── Página completa de fidelidad ──────────────────────────────────────────────
class FidelidadPage extends StatelessWidget {
  const FidelidadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('🏆 Mis Puntos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FidelidadService().streamPuntos(),
        builder: (_, snap) {
          final data   = snap.data ?? {'puntos': 0, 'puntosHistorico': 0, 'puntosCanjeados': 0};
          final puntos = data['puntos'] as int;
          final hist   = data['puntosHistorico'] as int;
          final canjd  = data['puntosCanjeados'] as int;
          final nivel  = nivelDePuntos(puntos);
          final color  = Color(int.parse('FF${nivel.colorHex}', radix: 16));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── Hero nivel ──────────────────────────────────────────────
              _HeroNivel(puntos: puntos, nivel: nivel, color: color),
              const SizedBox(height: 16),

              // ── Niveles ─────────────────────────────────────────────────
              _Sec('Niveles', _NivelesGrid(puntosActuales: puntos)),
              const SizedBox(height: 16),

              // ── Estadísticas ────────────────────────────────────────────
              _Sec('Resumen', Row(children: [
                _StatBox('Puntos\nDisponibles', '$puntos', color),
                const SizedBox(width: 10),
                _StatBox('Total\nGanados', '$hist', Colors.green),
                const SizedBox(width: 10),
                _StatBox('Total\nCanjeados', '$canjd', Colors.orange),
              ])),
              const SizedBox(height: 16),

              // ── Cómo ganar puntos ───────────────────────────────────────
              _Sec('¿Cómo funciona?', _ComoFunciona()),
              const SizedBox(height: 16),

              // ── Historial ───────────────────────────────────────────────
              _Sec('Historial', _Historial()),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero del nivel ────────────────────────────────────────────────────────────
class _HeroNivel extends StatelessWidget {
  final int puntos;
  final NivelFidelidad nivel;
  final Color color;
  const _HeroNivel({required this.puntos, required this.nivel, required this.color});

  @override
  Widget build(BuildContext context) {
    final idx       = kNiveles.indexOf(nivel);
    final siguiente = idx < kNiveles.length - 1 ? kNiveles[idx + 1] : null;
    final progreso  = siguiente == null ? 1.0
        : (puntos - nivel.puntosMin) /
          (siguiente.puntosMin - nivel.puntosMin).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(children: [
        Text(nivel.emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        Text('Nivel ${nivel.nombre}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900,
                fontSize: 22)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: '$puntos'));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('📋 Puntos copiados'),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
            ));
          },
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$puntos', style: TextStyle(
                color: color, fontWeight: FontWeight.w900,
                fontSize: 40, height: 1.1)),
            const SizedBox(width: 8),
            Text('puntos', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
          ]),
        ),
        const SizedBox(height: 6),
        Text('≈ \$${puntosToDolares(puntos).toStringAsFixed(2)} en descuentos',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        const SizedBox(height: 16),
        if (siguiente != null) ...[
          Row(children: [
            Text('${nivel.emoji} ${nivel.nombre}',
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
            const Spacer(),
            Text('${siguiente.emoji} ${siguiente.nombre}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text('Faltan ${siguiente.puntosMin - puntos} puntos para ${siguiente.nombre}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
        ] else
          Text('🏆 Nivel máximo alcanzado · ${nivel.multiplicador}x puntos',
              style: TextStyle(color: color, fontSize: 13,
                  fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Grid de niveles ───────────────────────────────────────────────────────────
class _NivelesGrid extends StatelessWidget {
  final int puntosActuales;
  const _NivelesGrid({required this.puntosActuales});

  @override
  Widget build(BuildContext context) => Column(
    children: kNiveles.map((n) {
      final color     = Color(int.parse('FF${n.colorHex}', radix: 16));
      final esCurrent = nivelDePuntos(puntosActuales) == n;
      final alcanzado = puntosActuales >= n.puntosMin;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: esCurrent
              ? color.withValues(alpha: 0.12)
              : alcanzado
                  ? _kCard
                  : _kCard2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: esCurrent
                  ? color.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
              width: esCurrent ? 1.5 : 1),
        ),
        child: Row(children: [
          Text(n.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(n.nombre, style: TextStyle(
                  color: alcanzado ? color : Colors.white38,
                  fontWeight: FontWeight.w700, fontSize: 14)),
              if (esCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('Tu nivel', style: TextStyle(
                      color: color, fontSize: 10,
                      fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            Text(
              n.puntosMax == -1
                  ? '${n.puntosMin}+ puntos'
                  : '${n.puntosMin}–${n.puntosMax} puntos',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('×${n.multiplicador}',
                style: TextStyle(
                    color: alcanzado ? color : Colors.white24,
                    fontWeight: FontWeight.w900, fontSize: 18)),
            Text('puntos', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10)),
          ]),
        ]),
      );
    }).toList(),
  );
}

// ── Cómo funciona ─────────────────────────────────────────────────────────────
class _ComoFunciona extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      ('🛒', 'Pide y gana',    '1 punto por cada \$1.00 gastado'),
      ('📈', 'Sube de nivel',  'Más nivel = más puntos por pedido'),
      ('🎁', 'Canjea',        '100 puntos = \$1.00 de descuento'),
      ('✅', 'Aplica al pedir','Usa tus puntos en el carrito'),
    ];
    return Column(
      children: items.map((it) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kCard2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Text(it.$1, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.$2, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700,
                fontSize: 13)),
            Text(it.$3, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12)),
          ])),
        ]),
      )).toList(),
    );
  }
}

// ── Historial ─────────────────────────────────────────────────────────────────
class _Historial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FidelidadService().streamHistorial(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B35), strokeWidth: 2)));
        }
        if (snap.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _kCard2, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(
                'Aún no tienes movimientos.\n¡Haz tu primer pedido y gana puntos!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13))),
          );
        }
        return Column(
          children: snap.data!.map((h) {
            final tipo    = h['tipo'] as String? ?? '';
            final pts     = h['puntos'] as int? ?? 0;
            final desc    = h['descripcion'] as String? ?? '';
            final fecha   = (h['fecha'] as Timestamp?)?.toDate();
            final esGanado = tipo != 'canjeado';
            final color   = esGanado ? Colors.green : Colors.orange;
            final sign    = pts > 0 ? '+' : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: color.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Center(child: Text(
                      tipo == 'ganado' ? '🎯' :
                      tipo == 'canjeado' ? '🎁' : '⚡',
                      style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(desc, style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (fecha != null)
                    Text(
                      '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10)),
                ])),
                Text('$sign$pts pts',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Stat box pequeño ──────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label, valor;
  final Color color;
  const _StatBox(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      Text(valor, style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10)),
    ]),
  ));
}

// ── Sección con título ────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Sec(this.titulo, this.child);
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo.toUpperCase(), style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3), fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1)),
    ),
    child,
  ]);
}

// ── Widget de canje en el carrito ─────────────────────────────────────────────
class CanjeePuntosWidget extends StatefulWidget {
  final int puntosDisponibles;
  final double totalCarrito;
  final ValueChanged<double> onDescuentoChanged; // descuento en dólares
  final ValueChanged<int> onPuntosCanjeadosChanged;

  const CanjeePuntosWidget({
    super.key,
    required this.puntosDisponibles,
    required this.totalCarrito,
    required this.onDescuentoChanged,
    required this.onPuntosCanjeadosChanged,
  });

  @override
  State<CanjeePuntosWidget> createState() => _CanjeePuntosWidgetState();
}

class _CanjeePuntosWidgetState extends State<CanjeePuntosWidget> {
  bool   _usando     = false;
  int    _puntosUsados = 0;
  late   TextEditingController _ctrl;

  // Máximo canjeable: min(disponibles, equivale a 50% del total)
  int get _maxCanjeable {
    final max50 = dolaresToPuntos(widget.totalCarrito * 0.5);
    return widget.puntosDisponibles.clamp(0, max50);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _aplicar() {
    final pts = int.tryParse(_ctrl.text) ?? 0;
    if (pts <= 0 || pts > _maxCanjeable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Máximo canjeable: $_maxCanjeable puntos'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() { _puntosUsados = pts; _usando = true; });
    widget.onDescuentoChanged(puntosToDolares(pts));
    widget.onPuntosCanjeadosChanged(pts);
  }

  void _quitar() {
    setState(() { _puntosUsados = 0; _usando = false; _ctrl.clear(); });
    widget.onDescuentoChanged(0);
    widget.onPuntosCanjeadosChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    final nivel = nivelDePuntos(widget.puntosDisponibles);
    final color = Color(int.parse('FF${nivel.colorHex}', radix: 16));

    if (widget.puntosDisponibles <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(nivel.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(
              '${widget.puntosDisponibles} puntos disponibles '
              '(≈ \$${puntosToDolares(widget.puntosDisponibles).toStringAsFixed(2)})',
              style: TextStyle(color: color,
                  fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
        const SizedBox(height: 10),
        if (!_usando) ...[
          Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Puntos a canjear (máx $_maxCanjeable)',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _aplicar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text('Usar', style: TextStyle(
                    color: color, fontWeight: FontWeight.w800,
                    fontSize: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('100 puntos = \$1.00 · Máx 50% del total',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10)),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  '🎁 -\$${puntosToDolares(_puntosUsados).toStringAsFixed(2)} '
                  '($_puntosUsados puntos aplicados)',
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700, fontSize: 12))),
              GestureDetector(
                onTap: _quitar,
                child: const Icon(Icons.close,
                    color: Colors.white38, size: 18),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
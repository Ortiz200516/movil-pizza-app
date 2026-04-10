import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';
import '../services/haptic_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kNar  = Color(0xFFFF6B35);
const _kAmb  = Color(0xFFFFD700);

/// Widget que muestra una calificación rápida (1-5 estrellas)
/// post-entrega. Se puede mostrar como bottom sheet o dialog.
class CalificacionRapidaSheet extends StatefulWidget {
  final PedidoModel pedido;
  final VoidCallback? onCalificado;
  const CalificacionRapidaSheet({
    super.key,
    required this.pedido,
    this.onCalificado,
  });

  /// Muestra el sheet si el pedido fue entregado y no fue calificado
  static Future<void> mostrarSiProcede(
      BuildContext context, PedidoModel pedido) async {
    if (pedido.estado != 'Entregado') return;
    // Verificar si ya fue calificado
    final doc = await FirebaseFirestore.instance
        .collection('pedidos').doc(pedido.id).get();
    final yaCalificado = doc.data()?['calificado'] as bool? ?? false;
    if (yaCalificado) return;
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => CalificacionRapidaSheet(pedido: pedido),
    );
  }

  @override
  State<CalificacionRapidaSheet> createState() =>
      _CalificacionRapidaSheetState();
}

class _CalificacionRapidaSheetState extends State<CalificacionRapidaSheet>
    with SingleTickerProviderStateMixin {
  int    _estrellas  = 0;
  bool   _enviando   = false;
  bool   _enviado    = false;
  String? _comentario;
  late AnimationController _starCtrl;
  late Animation<double>   _starScale;

  static const _emojisRating = ['', '😞', '😐', '🙂', '😊', '🤩'];
  static const _labelsRating = [
    '', 'Muy malo', 'Regular', 'Bien', 'Muy bien', '¡Excelente!'
  ];
  static const _comentariosRapidos = [
    '¡Todo perfecto!',
    'Llegó a tiempo',
    'Pizza deliciosa',
    'Buen servicio',
    'Mejoraría la entrega',
    'La próxima pido más',
  ];

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _starScale = Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(parent: _starCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _starCtrl.dispose(); super.dispose(); }

  Future<void> _enviar() async {
    if (_estrellas == 0) {
      HapticService.error();
      return;
    }
    setState(() => _enviando = true);
    try {
      await FirebaseFirestore.instance
          .collection('pedidos').doc(widget.pedido.id)
          .update({'calificado': true, 'calificacion': _estrellas,
                   'comentarioRapido': _comentario ?? ''});

      // Guardar también en resenas
      await FirebaseFirestore.instance.collection('resenas').add({
        'pedidoId':    widget.pedido.id,
        'clienteId':   widget.pedido.clienteId,
        'clienteNombre': widget.pedido.clienteNombre,
        'estrellas':   _estrellas,
        'comentario':  _comentario ?? '',
        'tipo':        'rapida',
        'fecha':       FieldValue.serverTimestamp(),
      });

      await HapticService.pedidoConfirmado();
      setState(() { _enviado = true; _enviando = false; });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        widget.onCalificado?.call();
      }
    } catch (e) {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24, right: 24, top: 8,
      ),
      child: _enviado ? _PantallaExito() : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _kNar.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _kNar.withValues(alpha: 0.3))),
              child: const Center(child: Text('🍕',
                  style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('¿Cómo estuvo tu pedido?',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${widget.pedido.items.length} producto(s) · '
                  '\$${widget.pedido.total.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12)),
            ])),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Ahora no', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 24),

          // Estrellas
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
            final filled = i < _estrellas;
            return GestureDetector(
              onTap: () {
                HapticService.seleccionarEstrella();
                setState(() => _estrellas = i + 1);
                _starCtrl.forward(from: 0);
              },
              child: AnimatedBuilder(
                animation: _starScale,
                builder: (_, child) => Transform.scale(
                  scale: filled && _estrellas == i + 1
                      ? _starScale.value : 1.0,
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(filled ? '⭐' : '☆',
                      style: TextStyle(
                          fontSize: 38,
                          color: filled ? null : Colors.white24)),
                ),
              ),
            );
          })),
          const SizedBox(height: 8),

          // Label dinámico
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _estrellas > 0
                ? Row(mainAxisAlignment: MainAxisAlignment.center,
                    key: ValueKey(_estrellas), children: [
                    Text(_emojisRating[_estrellas],
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(_labelsRating[_estrellas],
                        style: TextStyle(
                            color: _kAmb, fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ])
                : Text('Toca las estrellas para calificar',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13)),
          ),
          const SizedBox(height: 20),

          // Comentarios rápidos
          if (_estrellas > 0) ...[
            Align(alignment: Alignment.centerLeft,
              child: Text('Comentario rápido (opcional)',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6,
              children: _comentariosRapidos.map((c) {
                final sel = _comentario == c;
                return GestureDetector(
                  onTap: () {
                    HapticService.toque();
                    setState(() => _comentario = sel ? null : c);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _kNar.withValues(alpha: 0.15)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? _kNar.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(c, style: TextStyle(
                        color: sel ? _kNar : Colors.white54,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }).toList()),
            const SizedBox(height: 20),
          ],

          // Botón enviar
          GestureDetector(
            onTap: (_enviando || _estrellas == 0) ? null : _enviar,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _estrellas > 0
                    ? _kNar : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: _enviando
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(_estrellas > 0 ? '⭐' : '☆',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(_estrellas > 0 ? 'Enviar calificación'
                        : 'Selecciona las estrellas',
                        style: TextStyle(
                            color: _estrellas > 0
                                ? Colors.white
                                : Colors.white24,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ])),
            ),
          ),
        ],
      ),
    );
  }
}

class _PantallaExito extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(mainAxisSize: MainAxisSize.min,
        children: [
      const Text('🎉', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('¡Gracias por tu calificación!',
          style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 8),
      Text('Tu opinión nos ayuda a mejorar',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
    ]),
  );
}

/// Botón flotante que aparece cuando hay pedidos entregados sin calificar
class CalificacionPendienteBadge extends StatelessWidget {
  final String clienteId;
  final VoidCallback onTap;
  const CalificacionPendienteBadge({
    super.key, required this.clienteId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('clienteId', isEqualTo: clienteId)
          .where('estado', isEqualTo: 'Entregado')
          .where('calificado', isEqualTo: false)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kAmb,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: _kAmb.withValues(alpha: 0.35),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('⭐', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text('Califica tu pedido',
                  style: TextStyle(color: Colors.black87,
                      fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}
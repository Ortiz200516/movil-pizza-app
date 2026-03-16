import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Colores ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF6B00);
const _kBg     = Color(0xFF0F172A);
const _kCard   = Color(0xFF1E293B);
const _kCard2  = Color(0xFF263348);

// ── Mensajes rápidos por rol ───────────────────────────────────────────────────
const _rapidos_cliente = [
  '¿Cuánto falta?',
  'Estoy en la entrada',
  'Toca el timbre',
  'Llama cuando llegues',
  '¿Ya saliste?',
  'Gracias 🙏',
];

const _rapidos_repartidor = [
  'Ya salí 🛵',
  'Estoy cerca, 5 min',
  'Llegué, ¿dónde estás?',
  'No encuentro la dirección',
  'En camino ✅',
  '¡Entregado! 🎉',
];

// ─────────────────────────────────────────────────────────────────────────────
// ChatPage
// ─────────────────────────────────────────────────────────────────────────────
class ChatPage extends StatefulWidget {
  final String pedidoId;
  final String clienteId;
  final String? repartidorId;
  final String rolActual; // 'cliente' o 'repartidor'
  final String nombreOtro; // nombre del otro participante

  const ChatPage({
    super.key,
    required this.pedidoId,
    required this.clienteId,
    this.repartidorId,
    required this.rolActual,
    required this.nombreOtro,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _db      = FirebaseFirestore.instance;
  final _ctrl    = TextEditingController();
  final _scroll  = ScrollController();
  final _uid     = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _enviando    = false;
  bool _escribiendo = false;
  Timer? _typingTimer;

  CollectionReference get _mensajes =>
      _db.collection('chats').doc(widget.pedidoId).collection('mensajes');

  DocumentReference get _chatDoc =>
      _db.collection('chats').doc(widget.pedidoId);

  @override
  void initState() {
    super.initState();
    _marcarLeidos();
    _inicializarChat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _typingTimer?.cancel();
    // Limpiar estado "escribiendo" al salir
    _chatDoc.set({
      '${widget.rolActual}_escribiendo': false,
    }, SetOptions(merge: true));
    super.dispose();
  }

  Future<void> _inicializarChat() async {
    // Crear documento del chat si no existe
    await _chatDoc.set({
      'pedidoId':    widget.pedidoId,
      'clienteId':   widget.clienteId,
      'repartidorId': widget.repartidorId,
      'creadoEn':    FieldValue.serverTimestamp(),
      'cliente_escribiendo':    false,
      'repartidor_escribiendo': false,
    }, SetOptions(merge: true));
  }

  Future<void> _marcarLeidos() async {
    // Marcar como leídos los mensajes del otro
    final snap = await _mensajes
        .where('autorId', isNotEqualTo: _uid)
        .where('leido', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leido': true});
    }
    await batch.commit();
  }

  void _onTextChanged(String val) {
    // Actualizar estado "escribiendo"
    final escribiendo = val.isNotEmpty;
    if (escribiendo != _escribiendo) {
      _escribiendo = escribiendo;
      _chatDoc.set({
        '${widget.rolActual}_escribiendo': escribiendo,
      }, SetOptions(merge: true));
    }

    // Auto-apagar "escribiendo" tras 3s de inactividad
    _typingTimer?.cancel();
    if (escribiendo) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _escribiendo = false;
        _chatDoc.set({
          '${widget.rolActual}_escribiendo': false,
        }, SetOptions(merge: true));
      });
    }
  }

  Future<void> _enviar([String? textoRapido]) async {
    final texto = (textoRapido ?? _ctrl.text).trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);
    HapticFeedback.lightImpact();

    try {
      await _mensajes.add({
        'texto':     texto,
        'autorId':   _uid,
        'autorRol':  widget.rolActual,
        'ts':        FieldValue.serverTimestamp(),
        'leido':     false,
      });

      // Actualizar último mensaje en el doc del chat
      await _chatDoc.set({
        'ultimoMensaje': texto,
        'ultimoTs':      FieldValue.serverTimestamp(),
        'ultimoAutor':   widget.rolActual,
      }, SetOptions(merge: true));

      if (textoRapido == null) _ctrl.clear();
      _escribiendo = false;
      _typingTimer?.cancel();
      _chatDoc.set({
        '${widget.rolActual}_escribiendo': false,
      }, SetOptions(merge: true));

      // Scroll al fondo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _ChatAppBar(
        nombreOtro:  widget.nombreOtro,
        rolActual:   widget.rolActual,
        pedidoId:    widget.pedidoId,
        chatDoc:     _chatDoc,
      ),
      body: Column(children: [
        // ── Lista de mensajes ──────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _mensajes
                .orderBy('ts', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kOrange));
              }

              final docs = snap.data?.docs ?? [];

              // Marcar leídos cuando llegan mensajes nuevos
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _marcarLeidos();
                if (_scroll.hasClients) {
                  _scroll.animateTo(
                    _scroll.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });

              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    const Text('Sin mensajes aún',
                        style: TextStyle(color: Colors.white38,
                            fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Escribe al ${widget.rolActual == 'cliente'
                        ? 'repartidor' : 'cliente'}',
                        style: const TextStyle(color: Colors.white24,
                            fontSize: 12)),
                  ],
                ));
              }

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final esMio = data['autorId'] == _uid;
                  final ts    = (data['ts'] as Timestamp?)?.toDate();
                  final leido = data['leido'] as bool? ?? false;

                  // Mostrar separador de fecha si cambia el día
                  final anterior = i > 0
                      ? (docs[i - 1].data() as Map<String, dynamic>)
                      : null;
                  final tsAnterior =
                      (anterior?['ts'] as Timestamp?)?.toDate();
                  final mostrarFecha = tsAnterior == null ||
                      (ts != null &&
                          !_mismodia(ts, tsAnterior));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mostrarFecha && ts != null)
                        _SeparadorFecha(fecha: ts),
                      _BurbujaMensaje(
                        texto:  data['texto'] ?? '',
                        esMio:  esMio,
                        ts:     ts,
                        leido:  leido,
                        rol:    data['autorRol'] ?? '',
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // ── Indicador "escribiendo" ────────────────────────────────────────
        _IndicadorEscribiendo(
          chatDoc:  _chatDoc,
          rolOtro:  widget.rolActual == 'cliente'
              ? 'repartidor' : 'cliente',
          nombre:   widget.nombreOtro,
        ),

        // ── Mensajes rápidos ───────────────────────────────────────────────
        _MensajesRapidos(
          opciones: widget.rolActual == 'cliente'
              ? _rapidos_cliente : _rapidos_repartidor,
          onTap: _enviar,
        ),

        // ── Input ──────────────────────────────────────────────────────────
        _InputMensaje(
          ctrl:      _ctrl,
          enviando:  _enviando,
          onChanged: _onTextChanged,
          onEnviar:  () => _enviar(),
        ),
      ]),
    );
  }

  bool _mismodia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── AppBar del chat ───────────────────────────────────────────────────────────
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String nombreOtro, rolActual, pedidoId;
  final DocumentReference chatDoc;
  const _ChatAppBar({
    required this.nombreOtro, required this.rolActual,
    required this.pedidoId,   required this.chatDoc,
  });
  @override Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final esCliente = rolActual == 'cliente';
    return AppBar(
      backgroundColor: _kCard,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
          ),
          child: Center(child: Text(
            esCliente ? '🛵' : '👤',
            style: const TextStyle(fontSize: 18),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombreOtro.isNotEmpty ? nombreOtro
                : (esCliente ? 'Repartidor' : 'Cliente'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              esCliente ? '🛵 Tu repartidor' : '👤 Tu cliente',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white38),
            ),
          ],
        )),
      ]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.circle, color: Colors.green, size: 8),
              SizedBox(width: 4),
              Text('En camino',
                  style: TextStyle(
                      color: Colors.green, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────
class _BurbujaMensaje extends StatelessWidget {
  final String texto, rol;
  final bool esMio, leido;
  final DateTime? ts;
  const _BurbujaMensaje({
    required this.texto, required this.esMio,
    required this.leido, required this.rol, this.ts,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left:  esMio ? 48 : 0,
          right: esMio ? 0  : 48,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esMio ? _kOrange : _kCard2,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4  : 16),
          ),
          boxShadow: [BoxShadow(
            color: (esMio ? _kOrange : Colors.black)
                .withValues(alpha: 0.15),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          crossAxisAlignment: esMio
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(texto, style: TextStyle(
                color: esMio ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontSize: 14, height: 1.3)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (ts != null)
                Text(_formatHora(ts!), style: TextStyle(
                    color: esMio
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white24,
                    fontSize: 10)),
              if (esMio) ...[
                const SizedBox(width: 4),
                Icon(
                  leido ? Icons.done_all : Icons.done,
                  size: 12,
                  color: leido
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  String _formatHora(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Separador de fecha ────────────────────────────────────────────────────────
class _SeparadorFecha extends StatelessWidget {
  final DateTime fecha;
  const _SeparadorFecha({required this.fecha});

  @override
  Widget build(BuildContext context) {
    final hoy   = DateTime.now();
    final ayer  = hoy.subtract(const Duration(days: 1));
    String texto;
    if (_mismodia(fecha, hoy))        texto = 'Hoy';
    else if (_mismodia(fecha, ayer))  texto = 'Ayer';
    else texto = '${fecha.day}/${fecha.month}/${fecha.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.white12, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(texto, style: const TextStyle(
              color: Colors.white24, fontSize: 11)),
        ),
        Expanded(child: Divider(color: Colors.white12, height: 1)),
      ]),
    );
  }

  bool _mismodia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Indicador "escribiendo..." ────────────────────────────────────────────────
class _IndicadorEscribiendo extends StatelessWidget {
  final DocumentReference chatDoc;
  final String rolOtro, nombre;
  const _IndicadorEscribiendo({
    required this.chatDoc, required this.rolOtro, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: chatDoc.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final escribiendo = data['${rolOtro}_escribiendo'] as bool? ?? false;
        if (!escribiendo) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            _PuntosAnimados(),
            const SizedBox(width: 8),
            Text(
              '${nombre.isNotEmpty ? nombre : rolOtro} está escribiendo',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ]),
        );
      },
    );
  }
}

class _PuntosAnimados extends StatefulWidget {
  @override State<_PuntosAnimados> createState() => _PuntosAnimadosState();
}

class _PuntosAnimadosState extends State<_PuntosAnimados>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _paso = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 500),
        (_) { if (mounted) setState(() => _paso = (_paso + 1) % 3); });
  }
  @override void dispose() { _ctrl.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 3),
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: _paso == i
              ? _kOrange : Colors.white24,
          shape: BoxShape.circle,
        ),
      ),
    ));
  }
}

// ── Mensajes rápidos ──────────────────────────────────────────────────────────
class _MensajesRapidos extends StatelessWidget {
  final List<String> opciones;
  final void Function(String) onTap;
  const _MensajesRapidos(
      {required this.opciones, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: _kBg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(opciones[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kCard2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _kOrange.withValues(alpha: 0.25)),
            ),
            child: Text(opciones[i], style: const TextStyle(
                color: Colors.white70, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

// ── Input de mensaje ──────────────────────────────────────────────────────────
class _InputMensaje extends StatelessWidget {
  final TextEditingController ctrl;
  final bool enviando;
  final void Function(String) onChanged;
  final VoidCallback onEnviar;
  const _InputMensaje({
    required this.ctrl, required this.enviando,
    required this.onChanged, required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: _kCard,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            onSubmitted: (_) => onEnviar(),
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Escribe un mensaje...',
              hintStyle: const TextStyle(
                  color: Colors.white24, fontSize: 14),
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                    color: _kOrange.withValues(alpha: 0.5), width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: enviando ? null : onEnviar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: enviando
                  ? Colors.white38 : _kOrange,
              shape: BoxShape.circle,
              boxShadow: enviando ? null : [BoxShadow(
                  color: _kOrange.withValues(alpha: 0.4),
                  blurRadius: 8, spreadRadius: 1)],
            ),
            child: Center(child: enviando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatBadge — botón flotante con contador de mensajes sin leer
// Úsalo en tracking_page.dart y home_repartidor.dart
// ─────────────────────────────────────────────────────────────────────────────
class ChatBadge extends StatelessWidget {
  final String pedidoId;
  final String clienteId;
  final String? repartidorId;
  final String rolActual;
  final String nombreOtro;

  const ChatBadge({
    super.key,
    required this.pedidoId,
    required this.clienteId,
    this.repartidorId,
    required this.rolActual,
    required this.nombreOtro,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(pedidoId)
          .collection('mensajes')
          .where('autorId', isNotEqualTo: uid)
          .where('leido', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final sinLeer = snap.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatPage(
              pedidoId:     pedidoId,
              clienteId:    clienteId,
              repartidorId: repartidorId,
              rolActual:    rolActual,
              nombreOtro:   nombreOtro,
            ),
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: sinLeer > 0
                      ? _kOrange.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text('Chat', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 13)),
              if (sinLeer > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$sinLeer',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
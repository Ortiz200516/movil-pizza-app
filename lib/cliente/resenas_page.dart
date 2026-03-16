import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _kBg      = Color(0xFF0F172A);
const _kCard    = Color(0xFF1E293B);
const _kCard2   = Color(0xFF263348);
const _kNaranja = Color(0xFFFF6B35);

class ResenasPage extends StatefulWidget {
  const ResenasPage({super.key});
  @override
  State<ResenasPage> createState() => _ResenasPageState();
}

class _ResenasPageState extends State<ResenasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _filtro = 'Todas';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg, elevation: 0,
        title: const Row(children: [
          Text('⭐', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Reseñas', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kNaranja,
          indicatorWeight: 3,
          labelColor: _kNaranja,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '📋 Todas'),
            Tab(text: '✏️ Mi reseña'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabTodas(filtro: _filtro,
              onFiltroChanged: (f) => setState(() => _filtro = f)),
          const _TabMiResena(),
        ],
      ),
    );
  }
}

// ── Tab: Todas las reseñas ────────────────────────────────────────────────────
class _TabTodas extends StatelessWidget {
  final String filtro;
  final ValueChanged<String> onFiltroChanged;
  const _TabTodas({required this.filtro, required this.onFiltroChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('resenas')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kNaranja));
        }

        final todas = (snap.data?.docs ?? []).map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _ResenaModel(
            id: d.id,
            clienteNombre: data['clienteNombre'] ?? 'Anónimo',
            clienteId: data['clienteId'] ?? '',
            texto: data['texto'] ?? '',
            estrellas: (data['estrellas'] ?? 5) as int,
            fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
            respuesta: data['respuesta'],
            pedidoId: data['pedidoId'],
          );
        }).toList();

        // Stats
        final total     = todas.length;
        final promedio  = total == 0 ? 0.0
            : todas.fold(0, (s, r) => s + r.estrellas) / total;
        final por5      = todas.where((r) => r.estrellas == 5).length;
        final por4      = todas.where((r) => r.estrellas == 4).length;
        final por3      = todas.where((r) => r.estrellas <= 3).length;

        // Filtrar
        var filtradas = todas;
        if (filtro == '5 ⭐')      filtradas = todas.where((r) => r.estrellas == 5).toList();
        else if (filtro == '4 ⭐') filtradas = todas.where((r) => r.estrellas == 4).toList();
        else if (filtro == '≤ 3 ⭐') filtradas = todas.where((r) => r.estrellas <= 3).toList();

        return CustomScrollView(
          slivers: [
            // Stats resumen
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(children: [
                  Column(children: [
                    Text(promedio.toStringAsFixed(1),
                        style: const TextStyle(
                            color: _kNaranja, fontSize: 40,
                            fontWeight: FontWeight.w900)),
                    _Estrellas(promedio.round(), size: 16),
                    const SizedBox(height: 4),
                    Text('$total reseñas', style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(child: Column(children: [
                    _BarraRating('5 ⭐', por5, total),
                    _BarraRating('4 ⭐', por4, total),
                    _BarraRating('≤ 3 ⭐', por3, total),
                  ])),
                ]),
              ),
            ),

            // Filtros
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todas', '5 ⭐', '4 ⭐', '≤ 3 ⭐'].map((f) {
                      final sel = filtro == f;
                      return GestureDetector(
                        onTap: () => onFiltroChanged(f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? _kNaranja.withValues(alpha: 0.15)
                                : _kCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? _kNaranja.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          child: Text(f, style: TextStyle(
                              color: sel ? _kNaranja : Colors.white38,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Lista de reseñas
            if (filtradas.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    const Text('Sin reseñas aún',
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TarjetaResena(resena: filtradas[i]),
                    childCount: filtradas.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Tab: Escribir mi reseña ───────────────────────────────────────────────────
class _TabMiResena extends StatefulWidget {
  const _TabMiResena();
  @override
  State<_TabMiResena> createState() => _TabMiResenaState();
}

class _TabMiResenaState extends State<_TabMiResena> {
  int    _estrellas = 5;
  final  _textoCtrl = TextEditingController();
  bool   _enviando  = false;
  bool   _enviado   = false;

  @override
  void dispose() { _textoCtrl.dispose(); super.dispose(); }

  Future<void> _enviar() async {
    if (_textoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe tu opinión antes de enviar'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _enviando = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('resenas').add({
        'clienteId':     user.uid,
        'clienteNombre': user.displayName ?? user.email ?? 'Cliente',
        'clienteEmail':  user.email,
        'texto':         _textoCtrl.text.trim(),
        'estrellas':     _estrellas,
        'fecha':         Timestamp.now(),
        'respuesta':     null,
      });
      if (mounted) setState(() { _enviado = true; _enviando = false; });
      _textoCtrl.clear();
    } catch (e) {
      if (mounted) setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enviado) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('¡Gracias por tu reseña!', style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Tu opinión nos ayuda a mejorar cada día.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => setState(() => _enviado = false),
            icon: const Icon(Icons.edit_outlined, size: 16, color: _kNaranja),
            label: const Text('Escribir otra reseña',
                style: TextStyle(color: _kNaranja)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kNaranja),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Cabecera
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_kNaranja.withValues(alpha: 0.15),
                         _kCard],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kNaranja.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Text('🍕', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¿Cómo fue tu experiencia?', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 15)),
              SizedBox(height: 4),
              Text('Tu opinión es muy valiosa para nosotros',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        // Selector estrellas
        const Text('Tu calificación', style: TextStyle(
            color: Colors.white54, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children:
          List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _estrellas = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                i < _estrellas ? '⭐' : '☆',
                style: TextStyle(
                    fontSize: i < _estrellas ? 36 : 28,
                    color: i < _estrellas ? null : Colors.white24),
              ),
            ),
          )),
        ),
        const SizedBox(height: 6),
        Center(child: Text(
          _estrellas == 5 ? '¡Excelente! 🤩'
              : _estrellas == 4 ? 'Muy bueno 😊'
              : _estrellas == 3 ? 'Regular 😐'
              : _estrellas == 2 ? 'Malo 😕'
              : 'Muy malo 😞',
          style: const TextStyle(color: _kNaranja, fontWeight: FontWeight.bold),
        )),
        const SizedBox(height: 24),

        // Texto
        const Text('Tu comentario', style: TextStyle(
            color: Colors.white54, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        TextField(
          controller: _textoCtrl,
          maxLines: 5,
          maxLength: 300,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cuéntanos cómo fue tu pedido, el sabor, la entrega...',
            hintStyle: const TextStyle(
                color: Colors.white24, fontSize: 13),
            filled: true, fillColor: _kCard,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kNaranja, width: 1.5)),
            counterStyle: const TextStyle(color: Colors.white24),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_enviando ? 'Enviando...' : 'Enviar reseña',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNaranja, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Tarjeta de reseña ─────────────────────────────────────────────────────────
class _TarjetaResena extends StatelessWidget {
  final _ResenaModel resena;
  const _TarjetaResena({required this.resena});

  @override
  Widget build(BuildContext context) {
    final user   = FirebaseAuth.instance.currentUser;
    final esMia  = user?.uid == resena.clienteId;
    final fecha  = '${resena.fecha.day.toString().padLeft(2, '0')}/'
        '${resena.fecha.month.toString().padLeft(2, '0')}/'
        '${resena.fecha.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: esMia
                ? _kNaranja.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_kNaranja.withValues(alpha: 0.6), _kNaranja]),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              resena.clienteNombre.isNotEmpty
                  ? resena.clienteNombre[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 16),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(esMia ? 'Tú' : resena.clienteNombre,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              if (esMia) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kNaranja.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('Tú', style: TextStyle(
                      color: _kNaranja, fontSize: 9,
                      fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            Text(fecha, style: const TextStyle(
                color: Colors.white24, fontSize: 10)),
          ])),
          _Estrellas(resena.estrellas),
        ]),

        // Texto
        if (resena.texto.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(resena.texto, style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.5)),
        ],

        // Respuesta del admin
        if (resena.respuesta?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kNaranja.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _kNaranja.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('🍕', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('La Italiana respondió:',
                    style: TextStyle(color: _kNaranja, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(resena.respuesta!,
                    style: const TextStyle(color: Colors.white60,
                        fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _Estrellas extends StatelessWidget {
  final int estrellas;
  final double size;
  const _Estrellas(this.estrellas, {this.size = 13});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Text(
      i < estrellas ? '⭐' : '☆',
      style: TextStyle(fontSize: size,
          color: i < estrellas ? null : Colors.white12),
    )),
  );
}

class _BarraRating extends StatelessWidget {
  final String label;
  final int cant, total;
  const _BarraRating(this.label, this.cant, this.total);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? cant / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 40, child: Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10))),
        const SizedBox(width: 6),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: const AlwaysStoppedAnimation(_kNaranja),
            minHeight: 6,
          ),
        )),
        const SizedBox(width: 6),
        SizedBox(width: 20, child: Text('$cant',
            style: const TextStyle(color: Colors.white24, fontSize: 10))),
      ]),
    );
  }
}

// ── Modelo ────────────────────────────────────────────────────────────────────
class _ResenaModel {
  final String id, clienteNombre, clienteId, texto;
  final int estrellas;
  final DateTime fecha;
  final String? respuesta, pedidoId;

  const _ResenaModel({
    required this.id, required this.clienteNombre,
    required this.clienteId, required this.texto,
    required this.estrellas, required this.fecha,
    this.respuesta, this.pedidoId,
  });
}
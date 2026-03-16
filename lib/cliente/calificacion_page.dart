import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pedido_model.dart';

class CalificacionPage extends StatefulWidget {
  final PedidoModel pedido;
  const CalificacionPage({super.key, required this.pedido});
  @override
  State<CalificacionPage> createState() => _CalificacionPageState();
}

class _CalificacionPageState extends State<CalificacionPage>
    with SingleTickerProviderStateMixin {
  int    _estrellas   = 0;
  bool   _enviando    = false;
  bool   _enviado     = false;
  bool   _cargando    = true;
  bool   _yaCalifico  = false;
  bool   _subiendoFoto = false;
  File?  _foto;

  final _comentCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double>   _scaleAnim;

  static const _aspectos = [
    ('comida',       '🍕', 'Comida'),
    ('rapidez',      '⚡', 'Rapidez'),
    ('presentacion', '✨', 'Presentación'),
    ('atencion',     '😊', 'Atención'),
  ];
  final Map<String, int> _aspectoRating = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _verificarSiYaCalifico();
  }

  @override
  void dispose() {
    _comentCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarSiYaCalifico() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('calificaciones')
          .where('pedidoId', isEqualTo: widget.pedido.id)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _yaCalifico = snap.docs.isNotEmpty;
          _cargando   = false;
        });
        if (_yaCalifico) _animCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, maxHeight: 800, imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _foto = File(picked.path));
    }
  }

  Future<void> _enviar() async {
    if (_estrellas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⭐ Selecciona al menos una estrella'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _enviando = true);
    try {
      String? fotoUrl;
      if (_foto != null) {
        setState(() => _subiendoFoto = true);
        final ref = FirebaseStorage.instance
            .ref()
            .child('calificaciones/${widget.pedido.id}.jpg');
        await ref.putFile(_foto!);
        fotoUrl = await ref.getDownloadURL();
        setState(() => _subiendoFoto = false);
      }

      await FirebaseFirestore.instance.collection('calificaciones').add({
        'pedidoId':   widget.pedido.id,
        'clienteId':  widget.pedido.clienteId,
        'estrellas':  _estrellas,
        'comentario': _comentCtrl.text.trim(),
        'aspectos':   _aspectoRating,
        'fotoUrl':    fotoUrl,
        'fecha':      FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedido.id)
          .update({'calificado': true, 'calificacion': _estrellas});

      setState(() { _enviando = false; _enviado = true; });
      _animCtrl.forward();
    } catch (e) {
      setState(() { _enviando = false; _subiendoFoto = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('⭐ Califica tu pedido',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _yaCalifico
              ? _buildYaCalificado()
              : _enviado
                  ? _buildExito()
                  : _buildFormulario(),
    );
  }

  Widget _buildYaCalificado() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('✅', style: TextStyle(fontSize: 80)),
        const SizedBox(height: 20),
        const Text('¡Ya calificaste este pedido!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('Gracias por tu opinión',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    ),
  );

  Widget _buildExito() => Center(
    child: ScaleTransition(
      scale: _scaleAnim,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎉', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          const Text('¡Gracias por tu opinión!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Nos ayuda a mejorar cada día',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
          const SizedBox(height: 40),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(i < _estrellas ? '⭐' : '☆',
                        style: const TextStyle(fontSize: 32))))),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Volver al inicio',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    ),
  );

  Widget _buildFormulario() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      // Info pedido
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          const Text('📦', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pedido #${widget.pedido.id.substring(0, 6).toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${widget.pedido.items.length} producto(s)  •  \$${widget.pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ])),
        ]),
      ),
      const SizedBox(height: 28),

      // Estrellas
      const Text('¿Cómo fue tu experiencia?',
          style: TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 16),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _estrellas = i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(i < _estrellas ? '⭐' : '☆',
                      style: TextStyle(fontSize: i < _estrellas ? 42 : 36)),
                ),
              ))),
      if (_estrellas > 0) ...[
        const SizedBox(height: 8),
        Text(_labelEstrellas(_estrellas),
            style: TextStyle(color: _colorEstrellas(_estrellas),
                fontWeight: FontWeight.bold, fontSize: 16)),
      ],
      const SizedBox(height: 28),

      // Aspectos
      const Align(
          alignment: Alignment.centerLeft,
          child: Text('Califica aspectos específicos',
              style: TextStyle(color: Colors.white70, fontSize: 14,
                  fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: 2.0,
        children: _aspectos.map((a) {
          final rating = _aspectoRating[a.$1] ?? 0;
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: rating > 0
                      ? const Color(0xFFFF6B00).withValues(alpha: 0.4)
                      : Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Text(a.$2, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(a.$3, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Row(children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setState(() => _aspectoRating[a.$1] = i + 1),
                    child: Text(i < rating ? '⭐' : '☆',
                        style: const TextStyle(fontSize: 14))))),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),

      // Foto opcional
      const Align(
          alignment: Alignment.centerLeft,
          child: Text('Foto del pedido (opcional)',
              style: TextStyle(color: Colors.white70, fontSize: 14,
                  fontWeight: FontWeight.bold))),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _seleccionarFoto,
        child: Container(
          width: double.infinity,
          height: _foto != null ? 180 : 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _foto != null
                    ? const Color(0xFFFF6B00).withValues(alpha: 0.4)
                    : Colors.white12),
          ),
          child: _foto != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(_foto!, fit: BoxFit.cover),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _foto = null),
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                )
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate, color: Colors.white38, size: 28),
                  SizedBox(height: 6),
                  Text('Agregar foto del pedido',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
        ),
      ),
      const SizedBox(height: 24),

      // Comentario
      const Align(
          alignment: Alignment.centerLeft,
          child: Text('Comentario (opcional)',
              style: TextStyle(color: Colors.white70, fontSize: 14,
                  fontWeight: FontWeight.bold))),
      const SizedBox(height: 10),
      TextField(
        controller: _comentCtrl,
        maxLines: 4, maxLength: 300,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '¿Qué te gustó? ¿Qué podemos mejorar?',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
          filled: true, fillColor: const Color(0xFF1E293B),
          counterStyle: const TextStyle(color: Colors.white24),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5)),
        ),
      ),
      const SizedBox(height: 28),

      // Botón enviar
      SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _enviando ? null : _enviar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _enviando
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)),
                  const SizedBox(width: 12),
                  Text(_subiendoFoto ? 'Subiendo foto...' : 'Enviando...',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ])
              : const Text('ENVIAR CALIFICACIÓN',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
      const SizedBox(height: 40),
    ]),
  );
}

String _labelEstrellas(int n) {
  switch (n) {
    case 1: return 'Muy malo 😞';
    case 2: return 'Malo 😕';
    case 3: return 'Regular 😐';
    case 4: return 'Bueno 😊';
    case 5: return '¡Excelente! 🤩';
    default: return '';
  }
}

Color _colorEstrellas(int n) {
  if (n <= 2) return Colors.red;
  if (n == 3) return Colors.orange;
  return Colors.green;
}
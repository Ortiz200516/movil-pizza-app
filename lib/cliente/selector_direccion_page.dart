import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kNar  = Color(0xFFFF6B35);

class SelectorDireccionPage extends StatefulWidget {
  final Map<String, dynamic>? direccionInicial;
  const SelectorDireccionPage({super.key, this.direccionInicial});

  @override
  State<SelectorDireccionPage> createState() => _SelectorDireccionPageState();
}

class _SelectorDireccionPageState extends State<SelectorDireccionPage> {
  GoogleMapController? _mapCtrl;
  LatLng _posicion = const LatLng(-2.1962, -79.8861); // Guayaquil centro
  bool _cargandoUbicacion = false;
  bool _confirming = false;

  final _calleCtrl     = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  final _nombreCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargar dirección inicial si existe
    final dir = widget.direccionInicial;
    if (dir != null) {
      _calleCtrl.text      = dir['direccion'] ?? '';
      _referenciaCtrl.text = dir['referencia'] ?? '';
      _nombreCtrl.text     = dir['nombre'] ?? '';
      final lat = dir['lat'] as double?;
      final lng = dir['lng'] as double?;
      if (lat != null && lng != null) {
        _posicion = LatLng(lat, lng);
      }
    }
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _calleCtrl.dispose();
    _referenciaCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _cargandoUbicacion = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _cargandoUbicacion = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final nuevaPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _posicion = nuevaPos;
        _cargandoUbicacion = false;
      });
      _mapCtrl?.animateCamera(
          CameraUpdate.newLatLngZoom(nuevaPos, 16));
    } catch (_) {
      setState(() => _cargandoUbicacion = false);
    }
  }

  void _confirmar() {
    if (_calleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa la dirección'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, {
      'direccion':  _calleCtrl.text.trim(),
      'referencia': _referenciaCtrl.text.trim(),
      'nombre':     _nombreCtrl.text.trim(),
      'lat':        _posicion.latitude,
      'lng':        _posicion.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('¿Dónde entregamos?',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          if (_cargandoUbicacion)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: _kNar, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location_rounded,
                  color: _kNar, size: 22),
              tooltip: 'Mi ubicación',
              onPressed: _obtenerUbicacion,
            ),
        ],
      ),
      body: Column(children: [

        // ── Mapa ────────────────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: _posicion, zoom: 15.5),
              onMapCreated: (ctrl) => _mapCtrl = ctrl,
              onCameraMove: (pos) =>
                  setState(() => _posicion = pos.target),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
            ),

            // Pin central fijo
            Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_pin,
                    color: _kNar, size: 48,
                    shadows: [Shadow(color: Colors.black38,
                        blurRadius: 8, offset: Offset(0, 2))]),
                const SizedBox(height: 20), // offset para que el tip quede en el centro
              ],
            )),

            // Coordenadas actuales
            Positioned(
              bottom: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_posicion.latitude.toStringAsFixed(5)}, '
                  '${_posicion.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white60,
                      fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ]),
        ),

        // ── Formulario ──────────────────────────────────────────────────────
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [

                // Handle
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),

                // Instrucción
                Row(children: [
                  const Icon(Icons.touch_app_outlined,
                      color: _kNar, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Mueve el mapa para ajustar el pin a tu ubicación exacta',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12),
                  )),
                ]),
                const SizedBox(height: 16),

                // Campo dirección
                _CampoForm(
                  ctrl: _calleCtrl,
                  label: 'Dirección',
                  hint: 'Ej: Av. 9 de Octubre 123',
                  icono: Icons.location_on_outlined,
                  requerido: true,
                ),
                const SizedBox(height: 12),

                // Campo referencia
                _CampoForm(
                  ctrl: _referenciaCtrl,
                  label: 'Referencia (opcional)',
                  hint: 'Ej: Frente al parque, casa azul',
                  icono: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 12),

                // Campo nombre del lugar
                _CampoForm(
                  ctrl: _nombreCtrl,
                  label: 'Guardar como (opcional)',
                  hint: 'Ej: Casa, Oficina, Universidad',
                  icono: Icons.bookmark_outline_rounded,
                ),
                const SizedBox(height: 20),

                // Botón confirmar
                GestureDetector(
                  onTap: _confirmar,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _kNar,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: _kNar.withValues(alpha: 0.35),
                          blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Confirmar dirección',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _CampoForm extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icono;
  final bool requerido;
  const _CampoForm({required this.ctrl, required this.label,
      required this.hint, required this.icono, this.requerido = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12, fontWeight: FontWeight.w600)),
        if (requerido)
          Text(' *', style: TextStyle(
              color: _kNar.withValues(alpha: 0.8), fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
          prefixIcon: Icon(icono, color: Colors.white38, size: 18),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kNar, width: 1.5)),
        ),
      ),
    ],
  );
}
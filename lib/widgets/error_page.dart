import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kNar  = Color(0xFFFF6B35);

/// Tipos de error que puede mostrar la pantalla
enum TipoError { sinConexion, serverError, noEncontrado, permisoDenegado, generico }

/// Pantalla de error completa — reemplaza el Widget de error por defecto de Flutter
class PantallaError extends StatefulWidget {
  final TipoError tipo;
  final String? mensaje;
  final VoidCallback? onReintentar;
  final VoidCallback? onVolver;

  const PantallaError({
    super.key,
    this.tipo = TipoError.generico,
    this.mensaje,
    this.onReintentar,
    this.onVolver,
  });

  @override
  State<PantallaError> createState() => _PantallaErrorState();
}

class _PantallaErrorState extends State<PantallaError>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;
  bool _reintentando = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  _ErrorInfo get _info {
    switch (widget.tipo) {
      case TipoError.sinConexion:
        return _ErrorInfo(
          emoji: '📡',
          titulo: 'Sin conexión',
          subtitulo: 'Verifica tu conexión a internet',
          color: Colors.orange,
          tips: ['Activa el WiFi o datos móviles', 'Verifica que el avión no esté activado',
                 'Intenta acercarte al router'],
        );
      case TipoError.serverError:
        return _ErrorInfo(
          emoji: '🔧',
          titulo: 'Error del servidor',
          subtitulo: 'Estamos trabajando para solucionarlo',
          color: Colors.red,
          tips: ['El problema es de nuestro lado', 'Intenta de nuevo en unos minutos',
                 'Si persiste, contáctanos'],
        );
      case TipoError.noEncontrado:
        return _ErrorInfo(
          emoji: '🔍',
          titulo: 'No encontrado',
          subtitulo: 'Este contenido no existe o fue eliminado',
          color: _kNar,
          tips: [],
        );
      case TipoError.permisoDenegado:
        return _ErrorInfo(
          emoji: '🔒',
          titulo: 'Acceso denegado',
          subtitulo: 'No tienes permiso para ver esto',
          color: Colors.purple,
          tips: ['Verifica que iniciaste sesión', 'Contacta al administrador'],
        );
      default:
        return _ErrorInfo(
          emoji: '⚠️',
          titulo: 'Algo salió mal',
          subtitulo: widget.mensaje ?? 'Ocurrió un error inesperado',
          color: Colors.red,
          tips: ['Intenta de nuevo', 'Si el error persiste, reinicia la app'],
        );
    }
  }

  Future<void> _reintentar() async {
    HapticFeedback.mediumImpact();
    setState(() => _reintentando = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _reintentando = false);
    widget.onReintentar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Spacer(),

          // Icono animado
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(opacity: _fadeAnim.value, child: child),
            ),
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: info.color.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(child: Text(info.emoji,
                  style: const TextStyle(fontSize: 48))),
            ),
          ),
          const SizedBox(height: 28),

          // Título y subtítulo
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              Text(info.titulo, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900,
                  fontSize: 24),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(info.subtitulo, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center),
            ]),
          ),

          // Tips
          if (info.tips.isNotEmpty) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06))),
              child: Column(children: info.tips.asMap().entries.map((e) =>
                Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < info.tips.length - 1 ? 10 : 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(top: 5, right: 10),
                      decoration: BoxDecoration(
                          color: info.color, shape: BoxShape.circle)),
                    Expanded(child: Text(e.value, style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13, height: 1.4))),
                  ]),
                ),
              ).toList()),
            ),
          ],

          const Spacer(),

          // Botones
          Column(children: [
            if (widget.onReintentar != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reintentando ? null : _reintentar,
                  icon: _reintentando
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_reintentando ? 'Reintentando...' : 'Intentar de nuevo',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: info.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            if (widget.onVolver != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onVolver,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Volver al inicio',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }
}

class _ErrorInfo {
  final String emoji, titulo, subtitulo;
  final Color color;
  final List<String> tips;
  const _ErrorInfo({required this.emoji, required this.titulo,
      required this.subtitulo, required this.color, required this.tips});
}

/// Banner compacto de sin conexión para integrar en cualquier pantalla
class BannerSinConexion extends StatelessWidget {
  final bool visible;
  const BannerSinConexion({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: visible ? 38 : 0,
      color: Colors.orange.shade700,
      child: visible
          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
              SizedBox(width: 8),
              Text('Sin conexión — mostrando datos guardados',
                  style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ])
          : null,
    );
  }
}

/// StreamBuilder wrapper con manejo de errores integrado
class StreamConError<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;

  const StreamConError({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return PantallaError(
            tipo: TipoError.serverError,
            mensaje: snap.error.toString(),
            onReintentar: () {},
          );
        }
        if (!snap.hasData) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator(
                  color: Color(0xFFFF6B35)));
        }
        return builder(snap.data as T);
      },
    );
  }
}
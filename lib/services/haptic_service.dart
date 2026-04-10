import 'package:flutter/services.dart';

/// Servicio centralizado de feedback háptico y sonido visual
/// Todos los eventos de la app usan este servicio para consistencia
class HapticService {
  HapticService._();

  // ── Acciones del cliente ──────────────────────────────────────────────────
  /// Agregar producto al carrito
  static Future<void> agregarAlCarrito() async {
    await HapticFeedback.mediumImpact();
  }

  /// Confirmar pedido exitoso
  static Future<void> pedidoConfirmado() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Calificar con estrella
  static Future<void> seleccionarEstrella() async {
    await HapticFeedback.selectionClick();
  }

  /// Navegación entre tabs
  static Future<void> cambiarTab() async {
    await HapticFeedback.selectionClick();
  }

  /// Pull to refresh
  static Future<void> refresh() async {
    await HapticFeedback.mediumImpact();
  }

  // ── Acciones del cocinero/mesero ──────────────────────────────────────────
  /// Cambiar estado de pedido
  static Future<void> cambiarEstado() async {
    await HapticFeedback.mediumImpact();
  }

  /// Pedido nuevo llegó (alerta)
  static Future<void> nuevoPedido() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
  }

  /// Cronómetro terminó (cocina)
  static Future<void> timerTerminado() async {
    for (int i = 0; i < 4; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  // ── Acciones generales ────────────────────────────────────────────────────
  /// Error / validación fallida
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// Éxito genérico
  static Future<void> exito() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Toque suave (botones secundarios)
  static Future<void> toque() async {
    await HapticFeedback.lightImpact();
  }

  /// Long press
  static Future<void> longPress() async {
    await HapticFeedback.heavyImpact();
  }

  /// Deslizar / swipe
  static Future<void> swipe() async {
    await HapticFeedback.selectionClick();
  }
}
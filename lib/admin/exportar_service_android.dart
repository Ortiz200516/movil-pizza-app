import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido_model.dart';

class ExportarService {
  static Future<void> exportarPedidosCSV({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    // Exportar CSV solo está disponible en la versión web
    // En Android se puede implementar con path_provider en el futuro
  }

  static Future<void> exportarResumenCSV({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    // Exportar CSV solo está disponible en la versión web
    // En Android se puede implementar con path_provider en el futuro
  }
}

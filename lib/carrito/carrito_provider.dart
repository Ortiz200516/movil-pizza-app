import 'package:flutter/material.dart';

class CarritoProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  int get cantidadTotal => _items.fold(0, (s, i) => s + ((i['cantidad'] ?? 1) as int));
  bool get estaVacio => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  double get subtotal => _items.fold(0.0, (s, i) {
    final precio = (i['precio'] ?? i['precioBase'] ?? 0.0) as double;
    final cantidad = (i['cantidad'] ?? 1) as int;
    return s + (precio * cantidad);
  });

  double get impuesto => subtotal * 0.15;
  double get total => subtotal + impuesto;

  // Agrega cualquier producto al carrito (pizza, hamburguesa, cerveza, etc.)
  void agregarProducto(Map<String, dynamic> producto) {
    final index = _items.indexWhere((i) => i['id'] == producto['id'] &&
        i['opcionesKey'] == producto['opcionesKey']);
    if (index != -1) {
      _items[index]['cantidad'] = (_items[index]['cantidad'] ?? 1) + 1;
    } else {
      final item = Map<String, dynamic>.from(producto);
      item['cantidad'] = 1;
      _items.add(item);
    }
    notifyListeners();
  }

  // Alias para compatibilidad
  void agregarPizza(Map<String, dynamic> pizza) => agregarProducto(pizza);

  void aumentarCantidad(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index]['cantidad'] = (_items[index]['cantidad'] ?? 1) + 1;
      notifyListeners();
    }
  }

  void disminuirCantidad(int index) {
    if (index >= 0 && index < _items.length) {
      final cant = _items[index]['cantidad'] ?? 1;
      if (cant > 1) {
        _items[index]['cantidad'] = cant - 1;
        notifyListeners();
      } else {
        eliminarItem(index);
      }
    }
  }

  void eliminarItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void eliminarPizza(int index) => eliminarItem(index);

  void limpiarCarrito() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> obtenerItemsParaFirestore() => _items.map((i) => {
    'productoId': i['id'] ?? '',
    'productoNombre': i['nombre'] ?? '',
    'productoCategoria': i['categoria'] ?? i['categoriaNombre'] ?? 'otros',
    'cantidad': i['cantidad'] ?? 1,
    'precioUnitario': (i['precio'] ?? i['precioBase'] ?? 0.0),
    'opcionesSeleccionadas': i['opcionesSeleccionadas'],
    'notasEspeciales': i['notasEspeciales'],
    'precioTotal': (i['precio'] ?? i['precioBase'] ?? 0.0) * (i['cantidad'] ?? 1),
  }).toList();
}
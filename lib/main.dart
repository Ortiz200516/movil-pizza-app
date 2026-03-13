import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'carrito/carrito_provider.dart';
import 'services/producto_service.dart';
import 'services/notificacion_service.dart';
import 'services/theme_provider.dart';
import 'splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  try { await NotificacionService().inicializar(); } catch (_) {}
  try { await ProductoService().inicializarProductosEjemplo(); } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CarritoProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'La Pizzería',
          themeMode: theme.themeMode,
          theme: ThemeProvider.temaClaro,
          darkTheme: ThemeProvider.temaOscuro,
          // Ruta raíz para que los home files puedan hacer logout
          // sin necesidad de importar LoginPage directamente
          initialRoute: '/',
          routes: {
            '/': (_) => const NotificacionBanner(child: SplashPage()),
          },
        ),
      ),
    );
  }
}
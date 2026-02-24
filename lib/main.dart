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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificacionService().inicializar();
  await ProductoService().inicializarProductosEjemplo();
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
          themeMode:  theme.themeMode,
          theme:      ThemeProvider.temaClaro,
          darkTheme:  ThemeProvider.temaOscuro,
          home: const NotificacionBanner(child: SplashPage()),
        ),
      ),
    );
  }
}
# ❓ Preguntas Frecuentes - Pizzeria App

## 🔥 Firebase

### P: ¿Por qué mi app funciona en Android pero no en Web?
**R:** Android usa Firebase nativo (a través de Gradle y google-services.json), mientras que Web requiere los SDKs de JavaScript cargados explícitamente en el `index.html`. Sin estos scripts, Flutter no puede conectarse a Firebase en la web.

### P: ¿Puedo usar la misma configuración de Firebase para Android y Web?
**R:** Sí, usas el mismo proyecto de Firebase, pero:
- **Android:** Configuración en `google-services.json`
- **Web:** Configuración en `index.html` (objeto JavaScript)
- **iOS:** Configuración en `GoogleService-Info.plist`

### P: ¿Qué versión de Firebase SDK debo usar en web?
**R:** Se recomienda usar la versión 10.8.0 (o superior compatible). Usa los scripts `-compat` para compatibilidad con Flutter:
```javascript
firebase-app-compat.js
firebase-auth-compat.js
firebase-firestore-compat.js
```

---

## 🗺️ Google Maps

### P: ¿Por qué Google Maps no se muestra en mi app web?
**R:** Debes cargar la API de Google Maps en el `index.html`:
```html
<script src="https://maps.googleapis.com/maps/api/js?key=TU_API_KEY"></script>
```

### P: ¿Necesito una API Key diferente para web y Android?
**R:** No necesariamente. Puedes usar la misma API Key, pero es **MUY RECOMENDABLE** tener Keys separadas y restringidas:
- **Android:** Restricción por nombre de paquete (`com.example.pizzeria_app`)
- **Web:** Restricción por dominio (`tudominio.com`)

### P: ¿Cómo obtengo una API Key de Google Maps?
**R:** 
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea o selecciona un proyecto
3. Habilita "Maps JavaScript API"
4. Ve a "Credenciales" → "Crear credenciales" → "Clave de API"
5. Restringe la clave según la plataforma

---

## 📦 Dependencias

### P: ¿Por qué flutter pub get falla?
**R:** Posibles causas:
1. **Versiones sin `^`:** Cambia `firebase_messaging: 16.1.0` por `firebase_messaging: ^16.1.0`
2. **Conflictos de versiones:** Ejecuta `flutter pub upgrade` para actualizar todo
3. **Cache corrupto:** Ejecuta `flutter clean` y luego `flutter pub get`

### P: ¿Qué significa el símbolo `^` en las versiones?
**R:** El `^` permite actualizaciones compatibles. Ejemplo:
- `^16.1.0` acepta versiones desde 16.1.0 hasta <17.0.0
- `16.1.0` acepta SOLO la versión exacta 16.1.0

### P: ¿Necesito google_maps_flutter_web?
**R:** **Sí**, es necesario para que Google Maps funcione en web. Agrégalo a `pubspec.yaml`:
```yaml
google_maps_flutter_web: ^0.5.10
```

---

## 🔧 Configuración

### P: ¿Dónde van los permisos en AndroidManifest.xml?
**R:** Los permisos DEBEN estar FUERA del tag `<application>`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ✅ CORRECTO - AQUÍ -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application>
        <!-- ❌ INCORRECTO - NO AQUÍ -->
    </application>
</manifest>
```

### P: ¿Qué es firebase-messaging-sw.js?
**R:** Es un Service Worker que permite recibir notificaciones push en segundo plano cuando la app web está cerrada. Debe estar en la carpeta `web/`.

### P: ¿Cómo sé si mi Service Worker está funcionando?
**R:** 
1. Abre Chrome DevTools (F12)
2. Ve a la pestaña "Application"
3. En el menú lateral, busca "Service Workers"
4. Deberías ver `firebase-messaging-sw.js` registrado

---

## 🚀 Ejecución

### P: ¿Cómo ejecuto la app en web?
**R:** 
```bash
flutter run -d chrome        # Modo debug
flutter run -d chrome --release  # Modo release
```

### P: ¿Cómo compilo para producción?
**R:** 
```bash
flutter build web --release
```
Los archivos se generan en `build/web/`

### P: ¿Puedo ejecutar en otros navegadores?
**R:** Sí, Flutter soporta:
- Chrome: `flutter run -d chrome`
- Edge: `flutter run -d edge`
- Servidor web: `flutter run -d web-server`

### P: ¿Qué es flutter clean y cuándo usarlo?
**R:** `flutter clean` elimina archivos temporales y cache. Úsalo cuando:
- Cambias dependencias en `pubspec.yaml`
- La app se comporta de forma extraña
- Actualizas Flutter
- Hay errores de compilación sin razón aparente

---

## 🐛 Errores Comunes

### P: Error: "Firebase is not defined"
**R:** El SDK de Firebase no se cargó. Verifica:
1. Los scripts están en `web/index.html`
2. La URL de los scripts es correcta
3. Hay conexión a internet

### P: Error: "Null check operator used on a null value"
**R:** Firebase no está inicializado. Asegúrate de:
1. Tener los scripts de Firebase en `index.html`
2. Ejecutar `firebase.initializeApp(config)` antes de Flutter
3. Tener el `firebaseConfig` correcto

### P: Error: "MissingPluginException"
**R:** El plugin no está registrado. Solución:
```bash
flutter clean
flutter pub get
```

### P: Error: "Failed to load asset"
**R:** 
1. Ejecuta `flutter clean`
2. Verifica que no haya errores de sintaxis en `pubspec.yaml`
3. Asegúrate de que la ruta del asset sea correcta

### P: Google Maps muestra pantalla gris
**R:** Posibles causas:
1. API Key incorrecta o sin permisos
2. API de Maps no habilitada en Google Cloud
3. Restricciones de API Key muy estrictas
4. Cuota de API excedida

---

## 🔐 Seguridad

### P: ¿Es seguro exponer las API Keys en el código?
**R:** Las API Keys de **cliente** (web/Android) están diseñadas para ser públicas, PERO:
1. **SIEMPRE** usa restricciones (dominio/paquete)
2. Activa Firebase App Check
3. Monitorea el uso en la consola
4. Usa reglas de seguridad en Firestore

### P: ¿Cómo restrinjo mi Firebase API Key?
**R:** 
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Project Settings → General
3. En "Your apps" → Web app
4. Configura "App Check" o usa restricciones de Cloud Console

### P: ¿Alguien puede robar mi API Key y usarla?
**R:** Con restricciones adecuadas, no pueden:
- **Web:** Solo funciona en dominios autorizados
- **Android:** Solo funciona con tu package name y SHA-1
- **Firebase:** Las reglas de seguridad protegen los datos

---

## 📱 Multiplataforma

### P: ¿Puedo usar el mismo código para Android y Web?
**R:** Sí, Flutter es multiplataforma. Solo necesitas:
1. Configurar cada plataforma (AndroidManifest, index.html)
2. Agregar dependencias específicas si es necesario
3. Manejar diferencias con `kIsWeb` si es necesario

### P: ¿Cómo detecto si estoy en web desde el código?
**R:** Usa `kIsWeb`:
```dart
import 'package:flutter/foundation.dart';

if (kIsWeb) {
  // Código específico para web
} else {
  // Código para mobile
}
```

### P: ¿Todos los plugins funcionan en web?
**R:** No. Verifica en [pub.dev](https://pub.dev/) si el plugin tiene soporte web. Busca el badge "Web" en la página del paquete.

---

## 🌐 Despliegue

### P: ¿Cómo subo mi app a un servidor web?
**R:** 
1. Compila: `flutter build web --release`
2. Los archivos están en `build/web/`
3. Súbelos a tu hosting (Firebase Hosting, Netlify, Vercel, etc.)
4. Asegúrate de servir con HTTPS (requerido para geolocalización)

### P: ¿Qué servidor necesito?
**R:** Cualquier servidor que sirva archivos estáticos:
- Firebase Hosting
- Netlify
- Vercel
- GitHub Pages
- Apache/Nginx
- Cualquier CDN

### P: ¿Por qué necesito HTTPS?
**R:** Los navegadores modernos requieren HTTPS para:
- Geolocalización
- Notificaciones push
- Service Workers
- Algunas APIs de Firebase

---

## 🎓 Buenas Prácticas

### P: ¿Debo hacer commit de google-services.json?
**R:** **No** si tu repositorio es público. Usa:
1. `.gitignore` para excluirlo
2. Variables de entorno
3. Firebase App Distribution para testing

### P: ¿Cómo organizo mis archivos de configuración?
**R:** 
```
project/
├── android/
│   └── app/
│       ├── google-services.json       # No hacer commit si es público
│       └── src/main/AndroidManifest.xml
├── web/
│   ├── index.html                     # OK hacer commit
│   └── firebase-messaging-sw.js       # OK hacer commit
├── lib/
│   ├── firebase_options.dart          # Generado por FlutterFire CLI
│   └── ...
└── pubspec.yaml
```

### P: ¿Debo tener archivos diferentes para dev y producción?
**R:** Sí, es recomendable:
1. Usa diferentes proyectos de Firebase (dev/prod)
2. Usa flavors en Flutter
3. Usa variables de entorno

---

## 📊 Debugging

### P: ¿Cómo veo los logs en web?
**R:** 
1. Abre DevTools (F12) en Chrome
2. Ve a la pestaña "Console"
3. Filtra por errores o busca mensajes específicos

### P: ¿Cómo debuggeo Firebase en web?
**R:** 
1. Abre DevTools
2. En Console, escribe: `firebase.app().options`
3. Verifica que la configuración sea correcta
4. Revisa la pestaña "Network" para ver las peticiones

### P: ¿Qué es flutter doctor y cómo lo uso?
**R:** `flutter doctor` verifica tu instalación de Flutter:
```bash
flutter doctor
```
Muestra:
- Versión de Flutter
- SDK de Android/iOS instalados
- Dispositivos conectados
- Problemas en la configuración

---

## 💡 Tips Adicionales

### P: ¿Cómo actualizo Flutter?
**R:** 
```bash
flutter upgrade
```

### P: ¿Cómo limpio completamente el proyecto?
**R:** 
```bash
flutter clean
rm -rf build/
flutter pub get
```

### P: ¿Puedo usar hot reload en web?
**R:** Sí, funciona igual que en móvil. Presiona `r` en la terminal o `Ctrl+S` en tu IDE.

---

**¿Tienes más preguntas?**
Revisa la [documentación oficial de Flutter](https://flutter.dev/docs) o la [documentación de Firebase](https://firebase.google.com/docs).

---

**Última actualización:** 5 de Febrero, 2026
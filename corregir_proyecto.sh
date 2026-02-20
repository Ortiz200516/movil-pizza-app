#!/bin/bash

echo "========================================"
echo "  CORRECTOR AUTOMATICO - PIZZERIA APP"
echo "========================================"
echo ""

# Verificar que estamos en la carpeta del proyecto
if [ ! -f "pubspec.yaml" ]; then
    echo "ERROR: Este script debe ejecutarse en la raiz del proyecto Flutter"
    echo "Por favor, navega a la carpeta de tu proyecto y ejecuta nuevamente"
    exit 1
fi

echo "[1/6] Haciendo backup de archivos originales..."
mkdir -p backup
cp web/index.html backup/index.html.bak 2>/dev/null
cp pubspec.yaml backup/pubspec.yaml.bak 2>/dev/null
cp android/app/src/main/AndroidManifest.xml backup/AndroidManifest.xml.bak 2>/dev/null
echo "✓ Backup creado en carpeta 'backup'"
echo ""

echo "[2/6] Limpiando proyecto..."
flutter clean
if [ $? -ne 0 ]; then
    echo "ERROR: No se pudo ejecutar 'flutter clean'"
    exit 1
fi
echo "✓ Proyecto limpiado"
echo ""

echo "[3/6] Descargando dependencias..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "ERROR: No se pudo ejecutar 'flutter pub get'"
    exit 1
fi
echo "✓ Dependencias descargadas"
echo ""

echo "[4/6] Verificando entorno Flutter..."
flutter doctor
echo ""

echo "[5/6] Verificando archivos corregidos..."
echo ""
echo "IMPORTANTE: Asegurate de haber reemplazado estos archivos:"
echo "  - web/index.html"
echo "  - web/firebase-messaging-sw.js (NUEVO)"
echo "  - pubspec.yaml"
echo "  - android/app/src/main/AndroidManifest.xml"
echo ""
read -p "¿Ya reemplazaste todos los archivos? (s/n): " continuar
if [[ ! "$continuar" =~ ^[Ss]$ ]]; then
    echo ""
    echo "Por favor, reemplaza los archivos y ejecuta este script nuevamente"
    exit 0
fi

echo ""
echo "[6/6] ¿Que plataforma deseas ejecutar?"
echo ""
echo "1. Web (Chrome)"
echo "2. Android (Emulador/Dispositivo)"
echo "3. Solo compilar para web"
echo "4. Salir"
echo ""
read -p "Selecciona una opcion (1-4): " opcion

case $opcion in
    1)
        echo ""
        echo "Ejecutando en Chrome..."
        flutter run -d chrome
        ;;
    2)
        echo ""
        echo "Ejecutando en Android..."
        flutter run
        ;;
    3)
        echo ""
        echo "Compilando para web (modo release)..."
        flutter build web --release
        echo ""
        echo "✓ Compilacion completada. Los archivos estan en: build/web/"
        ;;
    *)
        echo ""
        echo "Saliendo..."
        exit 0
        ;;
esac

echo ""
echo "========================================"
echo "  PROCESO COMPLETADO"
echo "========================================"
@echo off
echo ========================================
echo   CORRECTOR AUTOMATICO - PIZZERIA APP
echo ========================================
echo.

REM Verificar que estamos en la carpeta del proyecto
if not exist "pubspec.yaml" (
    echo ERROR: Este script debe ejecutarse en la raiz del proyecto Flutter
    echo Por favor, navega a la carpeta de tu proyecto y ejecuta nuevamente
    pause
    exit /b 1
)

echo [1/6] Haciendo backup de archivos originales...
if not exist "backup" mkdir backup
copy web\index.html backup\index.html.bak >nul 2>&1
copy pubspec.yaml backup\pubspec.yaml.bak >nul 2>&1
copy android\app\src\main\AndroidManifest.xml backup\AndroidManifest.xml.bak >nul 2>&1
echo ✓ Backup creado en carpeta 'backup'
echo.

echo [2/6] Limpiando proyecto...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: No se pudo ejecutar 'flutter clean'
    pause
    exit /b 1
)
echo ✓ Proyecto limpiado
echo.

echo [3/6] Descargando dependencias...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: No se pudo ejecutar 'flutter pub get'
    pause
    exit /b 1
)
echo ✓ Dependencias descargadas
echo.

echo [4/6] Verificando entorno Flutter...
call flutter doctor
echo.

echo [5/6] Verificando archivos corregidos...
echo.
echo IMPORTANTE: Asegurate de haber reemplazado estos archivos:
echo   - web/index.html
echo   - web/firebase-messaging-sw.js (NUEVO)
echo   - pubspec.yaml
echo   - android/app/src/main/AndroidManifest.xml
echo.
set /p continuar="¿Ya reemplazaste todos los archivos? (S/N): "
if /i not "%continuar%"=="S" (
    echo.
    echo Por favor, reemplaza los archivos y ejecuta este script nuevamente
    pause
    exit /b 0
)

echo.
echo [6/6] ¿Que plataforma deseas ejecutar?
echo.
echo 1. Web (Chrome)
echo 2. Android (Emulador/Dispositivo)
echo 3. Solo compilar para web
echo 4. Salir
echo.
set /p opcion="Selecciona una opcion (1-4): "

if "%opcion%"=="1" (
    echo.
    echo Ejecutando en Chrome...
    call flutter run -d chrome
) else if "%opcion%"=="2" (
    echo.
    echo Ejecutando en Android...
    call flutter run
) else if "%opcion%"=="3" (
    echo.
    echo Compilando para web (modo release)...
    call flutter build web --release
    echo.
    echo ✓ Compilacion completada. Los archivos estan en: build\web\
) else (
    echo.
    echo Saliendo...
    exit /b 0
)

echo.
echo ========================================
echo   PROCESO COMPLETADO
echo ========================================
pause
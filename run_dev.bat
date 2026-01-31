@echo off
echo ==================================================
echo      Planmapp - Lanzador Maestro (Web) v2 ≡ƒÜÇ
echo      Modo: "Anti-Bloqueo de OneDrive"
echo ==================================================

cd /d "%~dp0"

echo [0] Deteniendo procesos fantasma...
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM flutter.exe >nul 2>&1

echo [1] Borrando carpeta build a la fuerza...
if exist "build" (
    rmdir /s /q "build"
    if exist "build" (
        echo [!] No se pudo borrar 'build'. OneDrive la tiene secuestrada.
        echo Por favor, PAUSA LA SINCRONIZACION de OneDrive momentaneamente.
        pause
    )
)

echo [2] Limpiando cache de Flutter...
:: Intento preventivo de borrar .dart_tool (Suele bloquearse por OneDrive)
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool" >nul 2>&1
    if exist ".dart_tool" (
        echo [!] Archivo bloqueado. Reintentando limpieza...
        timeout /t 2 /nobreak >nul
        rmdir /s /q ".dart_tool" >nul 2>&1
    )
)
call "%~dp0flutter_sdk\bin\flutter.bat" clean

echo [3] Obteniendo paquetes...
call "%~dp0flutter_sdk\bin\flutter.bat" pub get

echo [4] Lanzando App en Chrome (Puerto 8081)...
echo ---------------------------------------------------
echo ESTADO: Abriendo navegador. NO CIERRES ESTA VENTANA.
echo Si ves letras rojas de "Failed to delete", intentalo de nuevo.
echo ---------------------------------------------------
call "%~dp0flutter_sdk\bin\flutter.bat" run -d chrome --web-hostname localhost --web-port 8081
pause

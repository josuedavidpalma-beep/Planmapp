@echo off
echo ==================================================
echo      Planmapp - Instalador Android (RAPIDO) ⚡
echo ==================================================

echo [1] Deteniendo procesos trabados...
taskkill /F /IM java.exe >nul 2>&1
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM flutter.exe >nul 2>&1

echo [2] Preparando entorno...
:: No borramos build completo para aprovechar cache si existe algo util
:: Pero si hubo fallo masivo, mejor limpiar.
:: En debug es mas permisivo.

echo [3] Instalando en tu Samsung (SM A057M) - MODO DEBUG...
echo ---------------------------------------------------
echo Esto sera MUCHO mas rapido que el intento anterior.
echo Acepta permisos si el movil te pregunta.
echo ---------------------------------------------------

call .\flutter_sdk\bin\flutter.bat run -d R7AX80JJMWA --debug

echo.
echo [!] Si ha terminado, la app deberia abrirse en tu movil.
pause

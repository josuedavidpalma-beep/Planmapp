@echo off
echo =======================================
echo Iniciando Planmapp Web Version...
echo =======================================
echo Cerrando instancias previas si existen...

cd "C:\Users\Josue\OneDrive\Documents\Planmapp_Project"
call flutter_sdk\bin\flutter.bat run -d chrome

echo =======================================
echo Proceso finalizado.
pause

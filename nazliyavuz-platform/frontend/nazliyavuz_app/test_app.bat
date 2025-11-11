@echo off
echo ========================================
echo UYGULAMA TEST ARACI
echo ========================================
echo.
echo 1. Paketler indiriliyor...
call flutter pub get
echo.

echo 2. Cihazlar kontrol ediliyor...
call flutter devices
echo.

echo 3. Uygulama baslatiliyor...
echo.
call flutter run


@echo off
echo ========================================
echo SHA-1 FINGERPRINT ALMA ARACI
echo ========================================
echo.
echo Lutfen bekleyin, SHA-1 alinyor...
echo.

cd android
call gradlew signingReport

echo.
echo ========================================
echo YUKARDAKI CIKTIYI KONTROL EDIN!
echo ========================================
echo.
echo "SHA1:" satirini bulun ve kopyalayin!
echo Ornek: SHA1: A1:B2:C3:D4:E5:F6:...
echo.
echo Sonra Firebase Console'a gidin:
echo https://console.firebase.google.com
echo.
pause


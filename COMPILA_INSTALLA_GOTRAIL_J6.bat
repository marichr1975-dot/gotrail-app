@echo off
setlocal
title GoTr-Ail - Compila Installa Avvia J6

cd /d "%~dp0"

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

echo.
echo ==========================================
echo       GoTr-Ail - BUILD + J6
echo ==========================================
echo.

if not exist "%ADB%" (
    echo ERRORE: ADB non trovato:
    echo %ADB%
    pause
    exit /b 1
)

echo [1/4] Controllo Samsung J6...
"%ADB%" start-server >nul
"%ADB%" devices
"%ADB%" get-state 1>nul 2>nul
if errorlevel 1 (
    echo.
    echo ERRORE: nessun dispositivo ADB disponibile.
    echo Collega il J6, sbloccalo e autorizza Debug USB.
    pause
    exit /b 1
)

echo.
echo [2/4] Compilazione Organic Maps / GoTr-Ail...
if exist "gradlew.bat" (
    call gradlew.bat assembleFdroidDebug
) else if exist "android\gradlew.bat" (
    pushd android
    call gradlew.bat assembleFdroidDebug
    popd
) else (
    echo ERRORE: gradlew.bat non trovato.
    echo Metti questo BAT nella cartella principale OrganicMaps-XX22.
    pause
    exit /b 1
)

if errorlevel 1 (
    echo.
    echo ERRORE durante la compilazione.
    pause
    exit /b 1
)

echo.
echo [3/4] Cerco l'APK appena compilato...
set "APK="
for /f "delims=" %%F in ('dir /b /s /a-d "android\app\build\outputs\apk\fdroid\debug\*.apk" 2^>nul') do set "APK=%%F"

if not defined APK (
    echo ERRORE: APK fdroid debug non trovato.
    pause
    exit /b 1
)

echo APK trovato:
echo "%APK%"
echo.
echo Installazione sul J6...
"%ADB%" install -r "%APK%"

if errorlevel 1 (
    echo.
    echo ERRORE durante l'installazione.
    echo Se e' un problema di firma, NON disinstallo automaticamente:
    echo cosi' non perdiamo dati senza volerlo.
    pause
    exit /b 1
)

echo.
echo [4/4] Avvio dell'app...
"%ADB%" shell monkey -p app.organicmaps.debug -c android.intent.category.LAUNCHER 1 >nul 2>nul

echo.
echo ==========================================
echo     COMPLETATO - GoTr-Ail installata
echo ==========================================
echo.
pause
endlocal

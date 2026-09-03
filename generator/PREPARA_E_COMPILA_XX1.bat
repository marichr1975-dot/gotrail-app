@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo     GoTr-Ail XX1 - PREPARAZIONE E COMPILAZIONE J6 ARM32
echo ============================================================
echo.

where git >nul 2>nul
if errorlevel 1 (
  echo ERRORE: Git non trovato.
  pause
  exit /b 1
)

if not exist android\gradlew.bat (
  echo ERRORE: cartella sorgente non valida.
  pause
  exit /b 1
)

echo [1/3] Completo i componenti sorgente Organic Maps...
git submodule update --init --recursive
if errorlevel 1 (
  echo.
  echo ERRORE durante il download dei submodule.
  echo Controlla Internet e rilancia questo BAT.
  pause
  exit /b 1
)

echo.
echo [2/3] Compilo GoTr-Ail XX1 per Samsung J6 ^(ARM32^) ...
cd android
call gradlew.bat assembleFdroidDebug -Parm32
if errorlevel 1 (
  echo.
  echo COMPILAZIONE NON RIUSCITA.
  echo Mandami le PRIME righe dell'errore, non solo BUILD FAILED.
  pause
  exit /b 1
)

cd ..
echo.
echo [3/3] Cerco APK prodotto...
set "APK="
for /f "delims=" %%F in ('dir /b /s /o-d android\app\build\outputs\apk\*debug*.apk 2^>nul') do if not defined APK set "APK=%%F"
if not defined APK (
  echo Compilazione completata ma APK non trovato automaticamente.
  echo Controlla android\app\build\outputs\apk\
  pause
  exit /b 0
)

echo.
echo APK XX1:
echo %APK%
echo.

set "ADB=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe"
if exist "%ADB%" (
  echo Dispositivo collegato:
  "%ADB%" devices
  echo.
  choice /M "Vuoi installare ora GoTr-Ail XX1 sul J6"
  if errorlevel 2 goto fine
  "%ADB%" install -r "%APK%"
)

:fine
echo.
echo ============================================================
echo FINE
 echo Package separato: com.gotrail.xx1
 echo Organic Maps originale puo' restare installato.
echo ============================================================
pause

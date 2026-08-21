@echo off
setlocal
title CONFIGURA GEMINI - GoTr-Ail

echo.
echo ==========================================
echo   CONFIGURAZIONE GEMINI PER GOTR-AIL
echo ==========================================
echo.
echo Questo BAT crea nella cartella del progetto:
echo   gemini.json
echo e aggiunge gemini.json al .gitignore.
echo.
echo La chiave NON verra' caricata su GitHub.
echo.

set /p APIKEY=Incolla qui la nuova chiave Gemini e premi INVIO: 

if "%APIKEY%"=="" (
    echo.
    echo ERRORE: non hai inserito nessuna chiave.
    pause
    exit /b 1
)

> "%~dp0gemini.json" echo {
>> "%~dp0gemini.json" echo   "GEMINI_API_KEY": "%APIKEY%"
>> "%~dp0gemini.json" echo }

findstr /x /c:"gemini.json" "%~dp0.gitignore" >nul 2>&1
if errorlevel 1 (
    echo gemini.json>>"%~dp0.gitignore"
)

echo.
echo ==========================================
echo   FATTO
echo ==========================================
echo.
echo Creato:
echo   %~dp0gemini.json
echo.
echo gemini.json e' escluso da GitHub.
echo.
echo Per avviare GoTr-Ail usa:
echo   flutter run --dart-define-from-file=gemini.json
echo.
pause
endlocal

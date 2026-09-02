@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CREA_GOTRAIL_ANALISI_LITE.ps1" "%CD%"
pause

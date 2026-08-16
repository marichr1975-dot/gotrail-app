
Write-Host "GoTr-AI 3.0 - preparazione pacchetto offline Auronzo" -ForegroundColor Green
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart run tool/download_auronzo.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Pacchetto pronto. Ora esegui:" -ForegroundColor Green
Write-Host "flutter run -d 537ed2aa"

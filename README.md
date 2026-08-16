# GoTr-AI 4.0

Aggiornamento basato sulla 3.10.

## Modifiche 4.0
- Home: immagine in `BoxFit.cover`, non più stirata.
- Planner GoTr-AI responsive anche su telefoni con schermo piccolo.
- Scelte bambini, cane, bosco e avventura influenzano davvero la selezione dei sentieri usando tag OSM.
- Giro ad anello costruito con waypoint in settori distinti e ritorno al GPS.
- Anteprima percorso centrata sull'intera traccia.
- Pulsanti `CAMBIA PERCORSO` e `AVVIA` ridisegnati.
- `CAMBIA PERCORSO` e indietro dall'anteprima tornano al planner AI.
- Indietro dal planner torna alla mappa.
- Indietro dalla mappa mostra `Uscire da GoTr-AI?` invece di tornare alla Home.

## Avvio
```powershell
flutter clean
flutter pub get
flutter run -d 537ed2aa
```

GoTr-AI 6.6 - BASE MULTI-MAPPA

NOVITA
- PIANIFICA usa ricerca reale delle localita (Nominatim/OpenStreetMap), senza lista manuale di paesi.
- Dalle coordinate, MapManager sceglie automaticamente la mappa pubblicata che contiene quel punto.
- Il catalogo online e: https://raw.githubusercontent.com/marichr1975-dot/nuove-mappe/main/maps.json
- Se maps.json non e ancora presente, la 6.6 usa un fallback integrato per Veneto.
- Le mappe MBTiles vengono scaricate solo se mancanti/obsolete e restano offline sul telefono.
- Download sicuro: la vecchia mappa viene sostituita solo dopo aver completato e verificato la nuova.
- MapScreen scarica automaticamente, quando servono, i vecchi piccoli GeoJSON provinciali per le 4 funzioni Sentieri/Parcheggi/Fontane/Rifugi.

PER AGGIUNGERE UNA NUOVA MAPPA SENZA MODIFICARE L'APP
1. Caricare il file .mbtiles come asset di una GitHub Release nel repository nuove-mappe.
2. Aggiornare maps.json nel repository aggiungendo id, nome, regione, versione, url, size e bounds.
3. La ricerca della 6.6 trovera automaticamente la nuova zona tramite coordinate.

NOTA
Le 4 funzioni usano ancora temporaneamente il vecchio catalogo GeoJSON. La cartografia MBTiles e gia multi-mappa.

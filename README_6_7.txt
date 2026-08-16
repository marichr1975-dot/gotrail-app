GoTr-AI 6.7 - FIX INIZIA + AI PERCORSI

- INIZIA usa lo stesso archivio MBTiles di PIANIFICA e non riscarica la grande mappa regionale se già installata.
- I piccoli dati GeoJSON delle 4 icone vengono scaricati solo se mancanti.
- BAMBINI esclude come mete i tratti OSM marcati montani, alpini, demanding, steep, steps o con fondo molto problematico.
- La distanza richiesta è un obiettivo con tolleranza +/-35%; percorsi molto diversi vengono rifiutati.
- ANELLO viene accettato solo se torna realmente alla partenza e se andata/ritorno non risultano troppo sovrapposti.
- Se non esiste un percorso coerente, GoTr-AI lo dichiara invece di mostrare un falso anello.

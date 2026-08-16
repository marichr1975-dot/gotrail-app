GoTr-AI 4.6 - prova navigazione orientata

Modifiche principali:
- freccia blu di navigazione al posto del semplice punto GPS
- orientamento tramite bussola del telefono (fallback direzione GPS)
- smorzamento della bussola per ridurre il tremolio
- mappa ruotata in modalita' navigazione, con direzione di marcia verso l'alto
- percorso blu piu' spesso e visibile
- leggera prospettiva 3D simulata
- pulsante GPS per tornare a modalita' centrata/orientata dopo aver mosso la mappa
- include anche l'ultima correzione del dialog mappa offline della 4.5

NOTA: la prospettiva 3D e' una prima prova grafica. flutter_map non supporta un vero pitch 3D della camera; questa versione serve soprattutto per testare sul Samsung J6 freccia, bussola e leggibilita' del percorso.

# GoTr-AI 4.0 - ANELLO FIX

Base: GoTr_AI_4_0 originale.

NON sono stati modificati:
- Home
- GPS
- mappa
- Cosa c'è qui?
- rifugi/fontane/panorami/parcheggi
- flow AI
- anteprima
- navigazione

Modifiche:
1. Nuova icona verde GoTr-Ail.
2. Algoritmo anello:
   - fissa una meta a circa il 45% della distanza scelta;
   - calcola l'ANDATA passando da un punto laterale;
   - calcola il RITORNO passando dal lato opposto;
   - unisce le due tracce;
   - chiude esattamente sul GPS;
   - controlla che i due rami non siano quasi sovrapposti;
   - se sono troppo simili prova una seconda variante;
   - se ancora non esiste un vero anello, NON mostra un falso anello.

Nessuna chiave API richiesta: viene usato BRouter già presente nella 4.0.

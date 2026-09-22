# The Last Quest

MVP commerciale separato dal prototipo Pasaporte del Novio e da Slotta.

## Stato

- Landing commerciale responsive
- Configuratore evento
- Demo giocabile con missioni, filtri e punteggio
- Accesso tramite codice evento
- Supabase dedicato con autenticazione anonima e RLS
- Creazione atomica di una bozza evento tramite `create_event`
- Ingresso tramite codice tramite `join_event_by_code`
- Checkout Stripe una tantum da 19,99 €
- Webhook Stripe con verifica della firma
- Attivazione idempotente dell'evento dopo pagamento confermato
- Completamento missioni sincronizzato in tempo reale
- Prove fotografiche e video in bucket privato
- Accesso ai media limitato ai membri dello stesso evento
- Modifica e disattivazione missioni riservata all'organizzatore
- Invito partecipanti tramite QR, link, codice e condivisione nativa mobile
- Catalogo classico bilanciato: 13 missioni e 190 punti per le tipologie principali
- Catalogo Folle: 8 missioni e 340 punti disponibili
- PWA installabile con schermata offline e icona dedicata
- Checkout consentito esclusivamente all'organizzatore autenticato
- Limiti anti-abuso sulle bozze e protezione del ciclo di vita dell'evento
- Stati evento protetti: bozza, pronto, attivo, concluso e ricordo
- Galleria privata con URL temporanei firmati

## Verifica locale

```bash
npm run check
python3 -m http.server 4173
```

Il codice `DEMO26` apre la demo senza scrivere dati.

## Configurazione pagamenti

Impostare le variabili elencate in `.env.example`. Il webhook Stripe deve puntare a
`/api/stripe-webhook` e ascoltare `checkout.session.completed` e
`checkout.session.async_payment_succeeded`.

Dopo Stripe Checkout il browser riapre automaticamente la bozza e attende che
il webhook imposti `purchase_status = paid`. Se il webhook è in ritardo, la
bozza resta recuperabile da **I miei eventi** e può essere riaperta senza perdere dati.

Il pagamento non va considerato operativo finché le variabili Stripe non sono
configurate su Vercel e non è stato completato almeno un test end-to-end in modalità test.

## Prossima milestone

Completare la checklist manuale di rilascio e il test end-to-end del pagamento.

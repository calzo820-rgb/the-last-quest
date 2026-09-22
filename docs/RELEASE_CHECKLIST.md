# Checklist release commerciale

Questa checklist raccoglie soltanto le operazioni che richiedono intervento del proprietario o decisioni commerciali/legali.

## Stripe test

- Inserire su Vercel `STRIPE_SECRET_KEY` in modalità test.
- Inserire `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `SUPABASE_SERVICE_ROLE_KEY`.
- Impostare `APP_URL=https://the-last-quest.vercel.app`.
- Creare in Stripe il webhook `https://the-last-quest.vercel.app/api/stripe-webhook`.
- Abilitare `checkout.session.completed` e `checkout.session.async_payment_succeeded`.
- Inserire su Vercel il relativo `STRIPE_WEBHOOK_SECRET`.
- Eseguire un redeploy e un acquisto completo con carta di test.
- Verificare ritorno all'evento, stato `READY` e impossibilità di riacquistare lo stesso evento.

## Dati legali e commerciali

- Inserire titolare del trattamento e contatto privacy.
- Definire tempi di conservazione di eventi, foto e video.
- Inserire dati del venditore e riferimenti fiscali.
- Approvare politica di rimborso e condizioni di vendita.
- Far revisionare informativa privacy e termini prima dell'apertura al pubblico.

## Passaggio in produzione

- Sostituire le chiavi Stripe test con quelle live.
- Creare un webhook Stripe live separato e aggiornare il signing secret.
- Eseguire un pagamento reale controllato da 19,99 €.
- Verificare ricevuta, accredito, attivazione evento e log del webhook.
- Definire un indirizzo email di assistenza visibile agli utenti.

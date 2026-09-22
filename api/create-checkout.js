const Stripe = require('stripe');

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Metodo non consentito' });
  if (!process.env.STRIPE_SECRET_KEY || !process.env.SUPABASE_URL || !process.env.SUPABASE_PUBLISHABLE_KEY) {
    return res.status(503).json({ error: 'Pagamenti non ancora configurati' });
  }

  try {
    const { eventId } = req.body || {};
    const authHeader = req.headers.authorization || '';
    if (!uuidPattern.test(eventId || '') || !authHeader.startsWith('Bearer ')) {
      return res.status(400).json({ error: 'Richiesta non valida' });
    }

    const userResponse = await fetch(`${process.env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: process.env.SUPABASE_PUBLISHABLE_KEY,
        Authorization: authHeader
      }
    });
    if (!userResponse.ok) {
      return res.status(401).json({ error: 'Sessione non valida o scaduta' });
    }
    const user = await userResponse.json();
    if (!uuidPattern.test(user?.id || '')) {
      return res.status(401).json({ error: 'Sessione non valida o scaduta' });
    }

    const eventResponse = await fetch(
      `${process.env.SUPABASE_URL}/rest/v1/events?id=eq.${encodeURIComponent(eventId)}&select=id,name,purchase_status,owner_user_id`,
      { headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, Authorization: authHeader } }
    );
    if (!eventResponse.ok) {
      console.error('Supabase event lookup failed', eventResponse.status);
      return res.status(502).json({ error: 'Verifica evento non riuscita' });
    }

    const events = await eventResponse.json();
    const event = events[0];
    if (!event) return res.status(403).json({ error: 'Evento non disponibile' });
    if (event.owner_user_id !== user.id) {
      return res.status(403).json({ error: 'Solo l’organizzatore può acquistare l’evento' });
    }
    if (event.purchase_status === 'paid') {
      return res.status(409).json({ error: 'Evento già pagato' });
    }

    const origin = process.env.APP_URL || `https://${req.headers.host}`;
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2026-02-25.clover' });
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      client_reference_id: event.id,
      line_items: [{
        quantity: 1,
        price_data: {
          currency: 'eur',
          unit_amount: 1999,
          product_data: {
            name: 'The Last Quest — Evento completo',
            description: event.name
          }
        }
      }],
      metadata: {
        event_id: event.id,
        event_name: String(event.name || '').slice(0, 500),
        owner_user_id: event.owner_user_id,
        product: 'single_event'
      },
      payment_intent_data: {
        metadata: {
          event_id: event.id,
          owner_user_id: event.owner_user_id,
          product: 'single_event'
        }
      },
      success_url: `${origin}/?payment=success&event=${event.id}&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/?payment=cancelled&event=${event.id}`,
      allow_promotion_codes: false
    });

    return res.status(200).json({ url: session.url, sessionId: session.id });
  } catch (error) {
    console.error('Stripe checkout creation failed', error);
    return res.status(500).json({ error: 'Impossibile avviare il pagamento' });
  }
};

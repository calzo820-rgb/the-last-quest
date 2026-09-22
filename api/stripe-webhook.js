const Stripe = require('stripe');

module.exports.config = { api: { bodyParser: false } };

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(Buffer.from(chunk)));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  if (!process.env.STRIPE_SECRET_KEY || !process.env.STRIPE_WEBHOOK_SECRET || !process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(503).json({ error: 'Webhook non configurato' });
  }

  const signature = req.headers['stripe-signature'];
  if (!signature) return res.status(400).json({ error: 'Firma webhook mancante' });

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2026-02-25.clover' });
  let stripeEvent;
  try {
    const body = await readRawBody(req);
    stripeEvent = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (error) {
    console.error('Stripe webhook signature verification failed', error.message);
    return res.status(400).json({ error: 'Firma webhook non valida' });
  }

  if (['checkout.session.completed', 'checkout.session.async_payment_succeeded'].includes(stripeEvent.type)) {
    const session = stripeEvent.data.object;
    const eventId = session.metadata?.event_id || session.client_reference_id;
    if (session.payment_status === 'paid' && uuidPattern.test(eventId || '')) {
      try {
        const response = await fetch(`${process.env.SUPABASE_URL}/rest/v1/rpc/activate_paid_event`, {
          method: 'POST',
          headers: {
            apikey: process.env.SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ target_event: eventId, stripe_session_id: session.id })
        });
        if (!response.ok) {
          const details = await response.text();
          console.error('Paid event activation failed', response.status, details);
          return res.status(500).json({ error: 'Attivazione evento non riuscita' });
        }
      } catch (error) {
        console.error('Paid event activation request failed', error);
        return res.status(500).json({ error: 'Attivazione evento non riuscita' });
      }
    }
  }

  return res.status(200).json({ received: true });
};

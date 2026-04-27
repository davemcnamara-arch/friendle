// Vercel Serverless Function: Create Stripe Checkout Session
// This endpoint creates a Stripe checkout session for purchasing additional circles

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// UUID v4 pattern — Supabase auth IDs are always UUID v4
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// In-process rate limit: max 5 checkout sessions per userId per minute.
// Resets on cold start (stateless). Sufficient to block rapid automated bursts
// within a single warm instance. For stricter enforcement across instances,
// integrate Upstash Rate Limit backed by Redis.
const rateLimitMap = new Map(); // userId → [timestamp, ...]
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 60_000;

function isRateLimited(userId) {
  const now = Date.now();
  const window = (rateLimitMap.get(userId) || []).filter(t => now - t < RATE_LIMIT_WINDOW_MS);
  if (window.length >= RATE_LIMIT_MAX) return true;
  window.push(now);
  rateLimitMap.set(userId, window);
  return false;
}

module.exports = async (req, res) => {
  // CORS — only the app origin needs to reach this endpoint
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { userId, userEmail, circleCode } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Validate userId is a Supabase UUID — reject anything that isn't
    if (!UUID_RE.test(userId)) {
      return res.status(400).json({ error: 'Invalid userId format' });
    }

    // Validate optional email format if provided
    if (userEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(userEmail)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // Rate limit per user
    if (isRateLimited(userId)) {
      return res.status(429).json({ error: 'Too many requests. Please try again in a minute.' });
    }

    // Get the base URL from the request headers
    const protocol = req.headers['x-forwarded-proto'] || 'https';
    const host = req.headers['x-forwarded-host'] || req.headers.host;
    const baseUrl = `${protocol}://${host}`;

    // Build metadata object
    const metadata = {
      userId: userId,
      product: 'additional_circle',
    };

    // Add circle code to metadata if provided (for verification after payment)
    if (circleCode) {
      metadata.circleCode = circleCode;
    }

    // Create Stripe checkout session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price: 'price_1STvWa3OnHlYYT3Osc3uMslr', // $1.99 AUD one-time price
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `${baseUrl}/?purchase=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/?purchase=cancelled`,
      client_reference_id: userId, // Store user ID for webhook processing
      customer_email: userEmail || undefined,
      metadata: metadata,
    });

    // Return the session ID and URL to the client
    return res.status(200).json({
      sessionId: session.id,
      url: session.url,
    });

  } catch (error) {
    console.error('Error creating checkout session:', error);
    return res.status(500).json({
      error: 'Failed to create checkout session',
      message: error.message,
    });
  }
};

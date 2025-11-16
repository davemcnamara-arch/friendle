// Vercel Serverless Function: Create Stripe Checkout Session
// This endpoint creates a Stripe checkout session for purchasing additional circles

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

module.exports = async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { userId, userEmail } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Get the base URL from the request headers
    const protocol = req.headers['x-forwarded-proto'] || 'https';
    const host = req.headers['x-forwarded-host'] || req.headers.host;
    const baseUrl = `${protocol}://${host}`;

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
      metadata: {
        userId: userId,
        product: 'additional_circle',
      },
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

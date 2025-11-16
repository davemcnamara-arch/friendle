// Vercel Serverless Function: Stripe Webhook Handler
// This endpoint handles Stripe webhook events, particularly successful payments

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase with service role key (for admin operations)
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Disable body parsing, we need the raw body for webhook verification
export const config = {
  api: {
    bodyParser: false,
  },
};

// Helper function to get raw body
async function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

module.exports = async (req, res) => {
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get the raw body for signature verification
    const rawBody = await getRawBody(req);
    const sig = req.headers['stripe-signature'];

    // Verify webhook signature
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        rawBody,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).json({ error: `Webhook Error: ${err.message}` });
    }

    // Handle the event
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;

        // Get user ID from client_reference_id or metadata
        const userId = session.client_reference_id || session.metadata?.userId;

        if (!userId) {
          console.error('No userId found in checkout session');
          return res.status(400).json({ error: 'Missing userId in session' });
        }

        console.log(`Processing payment for user: ${userId}`);
        console.log(`Session ID: ${session.id}`);
        console.log(`Payment intent: ${session.payment_intent}`);
        console.log(`Amount: ${session.amount_total}`);

        // 1. Increment circles_purchased in profiles table
        const { data: profile, error: updateError } = await supabase
          .from('profiles')
          .update({
            circles_purchased: supabase.raw('circles_purchased + 1'),
            stripe_customer_id: session.customer || null,
          })
          .eq('id', userId)
          .select()
          .single();

        if (updateError) {
          console.error('Error updating profile:', updateError);
          return res.status(500).json({ error: 'Failed to update profile' });
        }

        console.log(`Updated profile for user ${userId}:`, profile);

        // 2. Record the purchase in circle_purchases table
        const { data: purchase, error: insertError } = await supabase
          .from('circle_purchases')
          .insert({
            profile_id: userId,
            amount: session.amount_total,
            stripe_payment_intent_id: session.payment_intent,
            stripe_checkout_session_id: session.id,
          })
          .select()
          .single();

        if (insertError) {
          console.error('Error recording purchase:', insertError);
          // Don't fail the webhook if purchase recording fails
          // The user still got their circle credit
        } else {
          console.log(`Recorded purchase:`, purchase);
        }

        console.log(`Successfully processed payment for user ${userId}`);
        break;
      }

      case 'checkout.session.expired':
      case 'checkout.session.async_payment_failed': {
        const session = event.data.object;
        console.log(`Checkout session ${event.type} for session: ${session.id}`);
        // Could track failed/expired sessions if needed
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    // Return 200 to acknowledge receipt
    return res.status(200).json({ received: true });

  } catch (error) {
    console.error('Error processing webhook:', error);
    return res.status(500).json({
      error: 'Webhook handler failed',
      message: error.message,
    });
  }
};

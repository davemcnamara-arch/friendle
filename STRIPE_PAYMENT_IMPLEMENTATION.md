# Stripe Payment Implementation Guide

This document provides setup instructions for the Stripe payment integration in Friendle.

## Overview

The payment system allows users to:
- Get their first circle for free
- Pay $1.99 AUD for each additional circle they create or join
- Pay via Stripe Checkout (redirect flow)

## Implementation Status

✅ **Completed:**
- Database schema changes (migration file created)
- Vercel serverless functions for Stripe integration
- Payment modal UI
- Payment checking logic in circle creation/joining
- Stripe redirect return handling
- CORS configuration

## Setup Steps

### 1. Database Migration

Run the following SQL in your Supabase SQL editor:

```bash
# Apply the migration
cat MIGRATION_add_stripe_payments.sql
```

This will:
- Add `circles_purchased` column to profiles (defaults to 1 for free circle)
- Add `stripe_customer_id` column to profiles
- Create `circle_purchases` table for tracking purchases
- Set up RLS policies

### 2. Vercel Environment Variables

The following environment variables are already set in Vercel (you mentioned):
- ✅ `STRIPE_SECRET_KEY`
- ✅ `SUPABASE_URL`
- ✅ `SUPABASE_SERVICE_KEY`

**You still need to add:**
- `STRIPE_WEBHOOK_SECRET` (obtained in step 3)

### 3. Configure Stripe Webhook

1. Go to Stripe Dashboard → Developers → Webhooks
2. Click "Add endpoint"
3. Set the endpoint URL to: `https://your-app-domain.vercel.app/api/stripe-webhook`
4. Select events to listen to:
   - `checkout.session.completed` (required)
   - `checkout.session.expired` (optional)
   - `checkout.session.async_payment_failed` (optional)
5. Copy the **Signing secret** and add it to Vercel as `STRIPE_WEBHOOK_SECRET`

### 4. Deploy to Vercel

```bash
# Install dependencies (if not already done)
npm install

# Deploy
git add .
git commit -m "Add Stripe payment integration"
git push
```

Vercel will automatically deploy the serverless functions in the `/api` folder.

### 5. Test the Integration

#### Test Payment Flow:
1. Log in to your Friendle app
2. Try to create or join a second circle
3. You should see the payment modal
4. Click "Purchase Additional Circle - $1.99"
5. You'll be redirected to Stripe Checkout
6. Use Stripe test card: `4242 4242 4242 4242` (any future expiry, any CVC)
7. Complete payment
8. You should be redirected back to the app with a success message
9. Verify in Supabase that `circles_purchased` was incremented

#### Verify Webhook:
1. Check Vercel Function logs for `/api/stripe-webhook`
2. Check Stripe Dashboard → Webhooks for successful deliveries
3. Check Supabase `circle_purchases` table for new records

## Files Modified/Created

### New Files:
- `/api/create-checkout-session.js` - Creates Stripe checkout sessions
- `/api/stripe-webhook.js` - Handles Stripe webhook events
- `/package.json` - Added Stripe and Supabase dependencies
- `/vercel.json` - Vercel configuration for serverless functions
- `/MIGRATION_add_stripe_payments.sql` - Database schema changes

### Modified Files:
- `/index.html` - Added payment modal UI and logic

## Key Functions

### Payment Modal Functions (index.html)
- `showPaymentModal()` - Shows payment modal with current circle count
- `closePaymentModal()` - Closes payment modal
- `proceedToPayment()` - Creates Stripe checkout session and redirects

### Updated Circle Functions
- `finalizeCircleCreation()` - Now checks payment status before creating
- `joinCircle()` - Now checks payment status before joining

### Redirect Handling
- DOMContentLoaded event listener handles success/cancelled returns from Stripe

## Payment Flow

1. User tries to create/join a circle
2. System checks: `current_circles >= circles_purchased`
3. If true → Show payment modal
4. User clicks "Purchase" → Creates Stripe checkout session
5. User redirected to Stripe → Completes payment
6. Stripe sends webhook to `/api/stripe-webhook`
7. Webhook increments `circles_purchased` and records purchase
8. User redirected back to app with success message
9. User can now create/join the circle

## Security Features

✅ Webhook signature verification
✅ RLS policies prevent manual insertions
✅ Service role key used only in webhook (server-side)
✅ User ID validated in webhook

## Troubleshooting

### Payment modal not showing:
- Check browser console for errors
- Verify `circles_purchased` column exists in profiles table
- Check that payment modal HTML is present in index.html

### Webhook not firing:
- Check Stripe webhook configuration
- Verify webhook URL is correct
- Check `STRIPE_WEBHOOK_SECRET` environment variable in Vercel
- Check Vercel function logs

### Circles not incrementing:
- Check webhook delivery in Stripe Dashboard
- Check Vercel function logs for errors
- Verify `SUPABASE_SERVICE_KEY` is correct
- Check RLS policies in Supabase

## Price Configuration

The Stripe Price ID is hardcoded in `/api/create-checkout-session.js`:
```javascript
price: 'price_1QTNpUP6o7Mi3KJG5k4j2sSk' // $1.99 AUD one-time
```

To change the price:
1. Create a new price in Stripe Dashboard
2. Update the Price ID in the code
3. Redeploy

## Next Steps

After deployment, you should:

1. Run the database migration in Supabase
2. Add the webhook endpoint in Stripe Dashboard
3. Add `STRIPE_WEBHOOK_SECRET` to Vercel environment variables
4. Test with Stripe test mode
5. Switch to live mode when ready

## Support

If you encounter issues:
- Check Vercel function logs
- Check Stripe webhook delivery logs
- Check Supabase logs
- Verify all environment variables are set correctly

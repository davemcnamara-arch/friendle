-- Migration: Add Stripe payment support for circles
-- Date: 2024
-- Description: Add payment tracking columns and table for circle purchases

-- Add payment columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS circles_purchased INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

-- Create circle_purchases table for tracking purchases
CREATE TABLE IF NOT EXISTS circle_purchases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  purchase_date TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  stripe_payment_intent_id TEXT,
  stripe_checkout_session_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_circle_purchases_profile_id ON circle_purchases(profile_id);
CREATE INDEX IF NOT EXISTS idx_circle_purchases_checkout_session ON circle_purchases(stripe_checkout_session_id);

-- Enable RLS on circle_purchases
ALTER TABLE circle_purchases ENABLE ROW LEVEL SECURITY;

-- RLS Policies for circle_purchases

-- Users can read their own purchases
CREATE POLICY "Users can view own purchases"
  ON circle_purchases
  FOR SELECT
  USING (auth.uid() = profile_id);

-- Only authenticated users can insert (via webhook with service role)
-- No INSERT policy for regular users - only service role can insert
CREATE POLICY "Service role can insert purchases"
  ON circle_purchases
  FOR INSERT
  WITH CHECK (false); -- Regular users cannot insert directly

-- No UPDATE or DELETE policies - purchases are immutable

-- Add comment to table
COMMENT ON TABLE circle_purchases IS 'Tracks Stripe payment purchases for additional circles';
COMMENT ON COLUMN profiles.circles_purchased IS 'Number of circles the user has purchased (includes 1 free circle)';
COMMENT ON COLUMN profiles.stripe_customer_id IS 'Stripe customer ID for recurring billing if needed';

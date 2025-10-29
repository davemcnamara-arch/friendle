-- Migration: Add completed_tutorials field to profiles table
-- Purpose: Track which tutorial popups each user has completed
-- Date: 2025-10-29

-- Add completed_tutorials JSONB column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS completed_tutorials JSONB DEFAULT '{}';

-- Create an index for efficient querying
CREATE INDEX IF NOT EXISTS idx_profiles_completed_tutorials ON profiles USING GIN (completed_tutorials);

-- Add a comment explaining the field
COMMENT ON COLUMN profiles.completed_tutorials IS 'Tracks which tutorial popups the user has completed. Structure: {"activities": true, "circles": true, "matches": true}';

-- Migration: Add inactivity tracking to match_participants
-- Phase 4: Inactivity Auto-Cleanup System

-- Add last_interaction_at column to match_participants
ALTER TABLE match_participants
ADD COLUMN IF NOT EXISTS last_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Initialize last_interaction_at with created_at or current time for existing records
UPDATE match_participants
SET last_interaction_at = COALESCE(created_at, NOW())
WHERE last_interaction_at IS NULL;

-- Add index for efficient querying of inactive participants
CREATE INDEX IF NOT EXISTS idx_match_participants_last_interaction
ON match_participants(last_interaction_at);

-- Add index for querying inactive participants by match
CREATE INDEX IF NOT EXISTS idx_match_participants_match_interaction
ON match_participants(match_id, last_interaction_at);

-- Create a table to track inactivity warnings
CREATE TABLE IF NOT EXISTS inactivity_warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    warned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'removed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(match_id, profile_id)
);

-- Add index for efficient warning lookups
CREATE INDEX IF NOT EXISTS idx_inactivity_warnings_match_profile
ON inactivity_warnings(match_id, profile_id, status);

-- Add index for efficient warning queries by status
CREATE INDEX IF NOT EXISTS idx_inactivity_warnings_status
ON inactivity_warnings(status, warned_at);

-- Add comments for documentation
COMMENT ON COLUMN match_participants.last_interaction_at IS 'Timestamp of last interaction (message sent, event created/joined, or Stay Interested clicked)';
COMMENT ON TABLE inactivity_warnings IS 'Tracks Day 5 warnings sent to inactive match participants';
COMMENT ON COLUMN inactivity_warnings.status IS 'pending: warning sent, resolved: user clicked Stay Interested, removed: user was auto-removed on Day 7';

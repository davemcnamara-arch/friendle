-- Migration: Add last_read_at to event_participants
-- This migration adds unread tracking for event chats

-- Add last_read_at column to event_participants table
ALTER TABLE event_participants
ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Set initial value for existing rows to now (all existing events will be marked as read)
UPDATE event_participants
SET last_read_at = NOW()
WHERE last_read_at IS NULL;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_event_participants_last_read
ON event_participants(event_id, profile_id, last_read_at);

-- Verify the change
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'event_participants' AND column_name = 'last_read_at';

-- Migration: Add circle_id support to muted_chats table
-- This allows users to mute circle chats

-- First ensure the muted_chats table exists
CREATE TABLE IF NOT EXISTS muted_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add circle_id column if it doesn't exist
ALTER TABLE muted_chats
ADD COLUMN IF NOT EXISTS circle_id UUID REFERENCES circles(id) ON DELETE CASCADE;

-- Add index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_muted_chats_circle
ON muted_chats(profile_id, circle_id);

-- Add constraint to ensure at least one chat type is specified
-- Note: This will be a check constraint that one of match_id, event_id, or circle_id must be non-null
ALTER TABLE muted_chats
DROP CONSTRAINT IF EXISTS muted_chats_chat_type_check;

ALTER TABLE muted_chats
ADD CONSTRAINT muted_chats_chat_type_check
CHECK (
    (match_id IS NOT NULL AND event_id IS NULL AND circle_id IS NULL) OR
    (match_id IS NULL AND event_id IS NOT NULL AND circle_id IS NULL) OR
    (match_id IS NULL AND event_id IS NULL AND circle_id IS NOT NULL)
);

-- Add unique constraint to prevent duplicate mutes
CREATE UNIQUE INDEX IF NOT EXISTS idx_muted_chats_unique_circle
ON muted_chats(profile_id, circle_id)
WHERE circle_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_muted_chats_unique_match
ON muted_chats(profile_id, match_id)
WHERE match_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_muted_chats_unique_event
ON muted_chats(profile_id, event_id)
WHERE event_id IS NOT NULL;

-- Migration: Add Soft Delete for Messages
-- Implements privacy-preserving message deletion using is_deleted flag
-- instead of permanently removing messages from the database

-- Add is_deleted column to match_messages
ALTER TABLE match_messages
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

-- Add is_deleted column to circle_messages
ALTER TABLE circle_messages
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

-- Add is_deleted column to event_messages
ALTER TABLE event_messages
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

-- Add deleted_at timestamp for audit trail (optional, but recommended for GDPR)
ALTER TABLE match_messages
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE circle_messages
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE event_messages
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_match_messages_deleted
ON match_messages(is_deleted) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_circle_messages_deleted
ON circle_messages(is_deleted) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_event_messages_deleted
ON event_messages(is_deleted) WHERE is_deleted = false;

-- Update RLS policies to allow users to soft-delete their own messages
-- (The UPDATE policies should already exist from previous migrations)

-- Add comments for documentation
COMMENT ON COLUMN match_messages.is_deleted IS 'Soft delete flag - when true, message content is hidden';
COMMENT ON COLUMN circle_messages.is_deleted IS 'Soft delete flag - when true, message content is hidden';
COMMENT ON COLUMN event_messages.is_deleted IS 'Soft delete flag - when true, message content is hidden';

COMMENT ON COLUMN match_messages.deleted_at IS 'Timestamp when message was soft-deleted (for GDPR compliance)';
COMMENT ON COLUMN circle_messages.deleted_at IS 'Timestamp when message was soft-deleted (for GDPR compliance)';
COMMENT ON COLUMN event_messages.deleted_at IS 'Timestamp when message was soft-deleted (for GDPR compliance)';

-- Migration: Add Circle Chat Support
-- This adds circle-level chat functionality (Phase 3)

-- Create circle_messages table (similar to match_messages and event_messages)
CREATE TABLE IF NOT EXISTS circle_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_circle_messages_circle_id
ON circle_messages(circle_id);

CREATE INDEX IF NOT EXISTS idx_circle_messages_created_at
ON circle_messages(circle_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_circle_messages_sender
ON circle_messages(sender_id);

-- Add last_read_at to circle_members for unread tracking
ALTER TABLE circle_members
ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add index for read tracking queries
CREATE INDEX IF NOT EXISTS idx_circle_members_last_read
ON circle_members(circle_id, profile_id, last_read_at);

-- Enable RLS (Row Level Security) for circle_messages
ALTER TABLE circle_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read circle messages if they're members of the circle
CREATE POLICY "Users can read circle messages if they are circle members"
ON circle_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circle_messages.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Policy: Users can insert messages to circles they're members of
CREATE POLICY "Users can insert messages to circles they are members of"
ON circle_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circle_messages.circle_id
    AND circle_members.profile_id = auth.uid()
  )
  AND sender_id = auth.uid()
);

-- Policy: Users can delete their own messages
CREATE POLICY "Users can delete their own circle messages"
ON circle_messages FOR DELETE
USING (sender_id = auth.uid());

-- Policy: Users can update their own messages
CREATE POLICY "Users can update their own circle messages"
ON circle_messages FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON circle_messages TO authenticated;

COMMENT ON TABLE circle_messages IS 'General chat messages for entire circles (not activity-specific)';
COMMENT ON COLUMN circle_members.last_read_at IS 'Timestamp when user last read circle chat messages';

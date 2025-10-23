-- Migration: Add Message Reactions Support
-- This adds emoji reaction functionality to all message types

-- Create match_message_reactions table
CREATE TABLE IF NOT EXISTS match_message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES match_messages(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL CHECK (emoji IN ('👍', '❤️', '😂', '🎉', '😮', '👏')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Ensure a user can only have one reaction per emoji per message
  UNIQUE(message_id, profile_id, emoji)
);

-- Create event_message_reactions table
CREATE TABLE IF NOT EXISTS event_message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES event_messages(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL CHECK (emoji IN ('👍', '❤️', '😂', '🎉', '😮', '👏')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Ensure a user can only have one reaction per emoji per message
  UNIQUE(message_id, profile_id, emoji)
);

-- Create circle_message_reactions table
CREATE TABLE IF NOT EXISTS circle_message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES circle_messages(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL CHECK (emoji IN ('👍', '❤️', '😂', '🎉', '😮', '👏')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Ensure a user can only have one reaction per emoji per message
  UNIQUE(message_id, profile_id, emoji)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_match_message_reactions_message_id
ON match_message_reactions(message_id);

CREATE INDEX IF NOT EXISTS idx_match_message_reactions_profile_id
ON match_message_reactions(profile_id);

CREATE INDEX IF NOT EXISTS idx_event_message_reactions_message_id
ON event_message_reactions(message_id);

CREATE INDEX IF NOT EXISTS idx_event_message_reactions_profile_id
ON event_message_reactions(profile_id);

CREATE INDEX IF NOT EXISTS idx_circle_message_reactions_message_id
ON circle_message_reactions(message_id);

CREATE INDEX IF NOT EXISTS idx_circle_message_reactions_profile_id
ON circle_message_reactions(profile_id);

-- Enable RLS (Row Level Security) for all reaction tables
ALTER TABLE match_message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE circle_message_reactions ENABLE ROW LEVEL SECURITY;

-- Policies for match_message_reactions
-- Users can read reactions on messages they can see
CREATE POLICY "Users can read match message reactions"
ON match_message_reactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM match_messages
    WHERE match_messages.id = match_message_reactions.message_id
  )
);

-- Users can add reactions to messages they can see
CREATE POLICY "Users can add match message reactions"
ON match_message_reactions FOR INSERT
WITH CHECK (
  profile_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM match_messages
    WHERE match_messages.id = match_message_reactions.message_id
  )
);

-- Users can delete their own reactions
CREATE POLICY "Users can delete their own match message reactions"
ON match_message_reactions FOR DELETE
USING (profile_id = auth.uid());

-- Policies for event_message_reactions
CREATE POLICY "Users can read event message reactions"
ON event_message_reactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM event_messages
    WHERE event_messages.id = event_message_reactions.message_id
  )
);

CREATE POLICY "Users can add event message reactions"
ON event_message_reactions FOR INSERT
WITH CHECK (
  profile_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM event_messages
    WHERE event_messages.id = event_message_reactions.message_id
  )
);

CREATE POLICY "Users can delete their own event message reactions"
ON event_message_reactions FOR DELETE
USING (profile_id = auth.uid());

-- Policies for circle_message_reactions
CREATE POLICY "Users can read circle message reactions"
ON circle_message_reactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_messages cm
    JOIN circle_members cmem ON cmem.circle_id = cm.circle_id
    WHERE cm.id = circle_message_reactions.message_id
    AND cmem.profile_id = auth.uid()
  )
);

CREATE POLICY "Users can add circle message reactions"
ON circle_message_reactions FOR INSERT
WITH CHECK (
  profile_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM circle_messages cm
    JOIN circle_members cmem ON cmem.circle_id = cm.circle_id
    WHERE cm.id = circle_message_reactions.message_id
    AND cmem.profile_id = auth.uid()
  )
);

CREATE POLICY "Users can delete their own circle message reactions"
ON circle_message_reactions FOR DELETE
USING (profile_id = auth.uid());

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON match_message_reactions TO authenticated;
GRANT SELECT, INSERT, DELETE ON event_message_reactions TO authenticated;
GRANT SELECT, INSERT, DELETE ON circle_message_reactions TO authenticated;

COMMENT ON TABLE match_message_reactions IS 'Emoji reactions for match messages';
COMMENT ON TABLE event_message_reactions IS 'Emoji reactions for event messages';
COMMENT ON TABLE circle_message_reactions IS 'Emoji reactions for circle messages';

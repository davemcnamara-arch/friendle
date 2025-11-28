-- Migration: Remove Match Chat System and Add Event Planning Features
-- This migration removes the match chat messaging system and enhances events
-- with planning mode, proposed timeframes, and polling capabilities

-- ============================================================================
-- STEP 1: Add new columns to events table
-- ============================================================================

-- Add status column (planning, scheduled, completed, cancelled)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'scheduled'
CHECK (status IN ('planning', 'scheduled', 'completed', 'cancelled'));

-- Make scheduled_date nullable (not required during planning phase)
ALTER TABLE events
ALTER COLUMN scheduled_date DROP NOT NULL;

-- Add proposed timeframe for planning phase
ALTER TABLE events
ADD COLUMN IF NOT EXISTS proposed_timeframe TEXT;

-- Update existing events to have 'scheduled' status
UPDATE events SET status = 'scheduled' WHERE status IS NULL;

-- ============================================================================
-- STEP 2: Create polling system tables
-- ============================================================================

-- Polls table for event planning
CREATE TABLE IF NOT EXISTS polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  options JSONB NOT NULL, -- Array of option strings: ["Option 1", "Option 2"]
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Poll votes table
CREATE TABLE IF NOT EXISTS poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID REFERENCES polls(id) ON DELETE CASCADE,
  voter_id UUID REFERENCES profiles(id),
  option_index INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(poll_id, voter_id) -- One vote per user per poll
);

-- ============================================================================
-- STEP 3: Modify event_messages table to support different message types
-- ============================================================================

-- Add message type column (text, image, poll, system)
ALTER TABLE event_messages
ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text'
CHECK (message_type IN ('text', 'image', 'poll', 'system'));

-- Add poll_id reference for poll messages
ALTER TABLE event_messages
ADD COLUMN IF NOT EXISTS poll_id UUID REFERENCES polls(id) ON DELETE CASCADE;

-- ============================================================================
-- STEP 4: Remove match chat tables and columns
-- ============================================================================

-- Drop match message related tables (CASCADE will remove dependencies)
DROP TABLE IF EXISTS match_message_reactions CASCADE;
DROP TABLE IF EXISTS match_message_reads CASCADE;
DROP TABLE IF EXISTS match_messages CASCADE;

-- Remove notifications_muted column from match_participants
-- (Keep only on event_participants for event-level muting)
ALTER TABLE match_participants
DROP COLUMN IF EXISTS notifications_muted;

-- ============================================================================
-- STEP 5: Add RLS policies for new tables
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;

-- Polls policies: Event participants can read polls
CREATE POLICY "Event participants can read polls"
ON polls FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.event_id = polls.event_id
    AND event_participants.profile_id = auth.uid()
  )
);

-- Polls policies: Event participants can create polls
CREATE POLICY "Event participants can create polls"
ON polls FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.event_id = polls.event_id
    AND event_participants.profile_id = auth.uid()
  )
  AND created_by = auth.uid()
);

-- Poll votes policies: Anyone can read votes (to see results)
CREATE POLICY "Event participants can read poll votes"
ON poll_votes FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM polls
    JOIN event_participants ON event_participants.event_id = polls.event_id
    WHERE polls.id = poll_votes.poll_id
    AND event_participants.profile_id = auth.uid()
  )
);

-- Poll votes policies: Event participants can vote
CREATE POLICY "Event participants can vote on polls"
ON poll_votes FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM polls
    JOIN event_participants ON event_participants.event_id = polls.event_id
    WHERE polls.id = poll_votes.poll_id
    AND event_participants.profile_id = auth.uid()
  )
  AND voter_id = auth.uid()
);

-- Poll votes policies: Users can update their own votes
CREATE POLICY "Users can update their own votes"
ON poll_votes FOR UPDATE
TO authenticated
USING (voter_id = auth.uid())
WITH CHECK (voter_id = auth.uid());

-- Poll votes policies: Users can delete their own votes
CREATE POLICY "Users can delete their own votes"
ON poll_votes FOR DELETE
TO authenticated
USING (voter_id = auth.uid());

-- ============================================================================
-- STEP 6: Create indexes for performance
-- ============================================================================

-- Index for faster poll lookups by event
CREATE INDEX IF NOT EXISTS idx_polls_event_id ON polls(event_id);

-- Index for faster vote lookups by poll
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_id ON poll_votes(poll_id);

-- Index for faster vote lookups by voter
CREATE INDEX IF NOT EXISTS idx_poll_votes_voter_id ON poll_votes(voter_id);

-- Index for faster event status queries
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Summary of changes:
-- ✓ Added event.status column (planning/scheduled/completed/cancelled)
-- ✓ Made event.scheduled_date nullable
-- ✓ Added event.proposed_timeframe column
-- ✓ Created polls and poll_votes tables with RLS policies
-- ✓ Added message_type and poll_id to event_messages
-- ✓ Dropped match_messages, match_message_reads, match_message_reactions tables
-- ✓ Removed notifications_muted from match_participants
-- ✓ Added performance indexes

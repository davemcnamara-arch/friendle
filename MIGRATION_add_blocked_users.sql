-- ========================================
-- Migration: Add Blocked Users Feature
-- ========================================
-- This migration adds a blocked_users table to allow users to block other users.
-- Blocking prevents:
-- - Seeing the blocked user's profile
-- - Receiving messages from the blocked user
-- - Being matched with the blocked user in activities
--
-- IMPORTANT: This migration is safe to run on existing data.
-- It will not delete or modify any existing rows.
--
-- Run this migration in your Supabase SQL Editor.
-- ========================================

-- Create blocked_users table
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id),
    -- Ensure users can't block themselves
    CHECK (blocker_id != blocked_id)
);

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker
ON blocked_users(blocker_id);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked
ON blocked_users(blocked_id);

-- Enable RLS on blocked_users table
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- ========================================
-- BLOCKED_USERS TABLE POLICIES
-- ========================================

-- Users can read their own blocks (who they have blocked)
DROP POLICY IF EXISTS "Users can read own blocks" ON blocked_users;
CREATE POLICY "Users can read own blocks"
ON blocked_users FOR SELECT
USING (blocker_id = auth.uid());

-- Users can also see who has blocked them (optional - comment out if you want blocks to be invisible)
-- This is useful for debugging but you may want to hide this in production
DROP POLICY IF EXISTS "Users can see who blocked them" ON blocked_users;
CREATE POLICY "Users can see who blocked them"
ON blocked_users FOR SELECT
USING (blocked_id = auth.uid());

-- Users can block other users (insert)
DROP POLICY IF EXISTS "Users can block others" ON blocked_users;
CREATE POLICY "Users can block others"
ON blocked_users FOR INSERT
WITH CHECK (blocker_id = auth.uid());

-- Users can unblock others (delete their own blocks)
DROP POLICY IF EXISTS "Users can unblock others" ON blocked_users;
CREATE POLICY "Users can unblock others"
ON blocked_users FOR DELETE
USING (blocker_id = auth.uid());

-- ========================================
-- UPDATE EXISTING POLICIES TO FILTER BLOCKED USERS
-- ========================================

-- Update profiles policy to hide blocked users
DROP POLICY IF EXISTS "Users can read circle member profiles" ON profiles;
CREATE POLICY "Users can read circle member profiles"
ON profiles FOR SELECT
USING (
  -- Must be in same circle
  EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.profile_id = auth.uid()
    AND cm2.profile_id = profiles.id
  )
  -- Must not be blocked by the viewer
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid()
    AND blocked_id = profiles.id
  )
  -- Must not have blocked the viewer
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = profiles.id
    AND blocked_id = auth.uid()
  )
);

-- Update circle_members policy to filter blocked users
DROP POLICY IF EXISTS "Users can read circle members" ON circle_members;
CREATE POLICY "Users can read circle members"
ON circle_members FOR SELECT
USING (
  -- Must be in same circle
  EXISTS (
    SELECT 1 FROM circle_members cm
    WHERE cm.circle_id = circle_members.circle_id
    AND cm.profile_id = auth.uid()
  )
  -- Must not be blocked
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = circle_members.profile_id)
    OR (blocker_id = circle_members.profile_id AND blocked_id = auth.uid())
  )
);

-- Update match_participants policy to filter blocked users
DROP POLICY IF EXISTS "Users can read match participants" ON match_participants;
CREATE POLICY "Users can read match participants"
ON match_participants FOR SELECT
USING (
  -- Must be in same circle as the match
  EXISTS (
    SELECT 1 FROM matches m
    JOIN circle_members cm ON cm.circle_id = m.circle_id
    WHERE m.id = match_participants.match_id
    AND cm.profile_id = auth.uid()
  )
  -- Must not be blocked
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = match_participants.profile_id)
    OR (blocker_id = match_participants.profile_id AND blocked_id = auth.uid())
  )
);

-- Update event_participants policy to filter blocked users
DROP POLICY IF EXISTS "Users can read event participants" ON event_participants;
CREATE POLICY "Users can read event participants"
ON event_participants FOR SELECT
USING (
  -- Must be in same circle as the event
  EXISTS (
    SELECT 1 FROM events e
    JOIN circle_members cm ON cm.circle_id = e.circle_id
    WHERE e.id = event_participants.event_id
    AND cm.profile_id = auth.uid()
  )
  -- Must not be blocked
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = event_participants.profile_id)
    OR (blocker_id = event_participants.profile_id AND blocked_id = auth.uid())
  )
);

-- Update match_messages policy to filter messages from blocked users
DROP POLICY IF EXISTS "Users can read match messages if they are participants" ON match_messages;
CREATE POLICY "Users can read match messages if they are participants"
ON match_messages FOR SELECT
USING (
  -- Must be a participant in the match
  EXISTS (
    SELECT 1 FROM match_participants
    WHERE match_participants.match_id = match_messages.match_id
    AND match_participants.profile_id = auth.uid()
  )
  -- Message must not be from a blocked user
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = match_messages.sender_id)
    OR (blocker_id = match_messages.sender_id AND blocked_id = auth.uid())
  )
);

-- Update event_messages policy to filter messages from blocked users
DROP POLICY IF EXISTS "Users can read event messages if they are participants" ON event_messages;
CREATE POLICY "Users can read event messages if they are participants"
ON event_messages FOR SELECT
USING (
  -- Must be a participant in the event
  EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.event_id = event_messages.event_id
    AND event_participants.profile_id = auth.uid()
  )
  -- Message must not be from a blocked user
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = event_messages.sender_id)
    OR (blocker_id = event_messages.sender_id AND blocked_id = auth.uid())
  )
);

-- Update circle_messages policy to filter messages from blocked users
DROP POLICY IF EXISTS "Users can read circle messages if they are members" ON circle_messages;
CREATE POLICY "Users can read circle messages if they are members"
ON circle_messages FOR SELECT
USING (
  -- Must be a member of the circle
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circle_messages.circle_id
    AND circle_members.profile_id = auth.uid()
  )
  -- Message must not be from a blocked user
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = circle_messages.sender_id)
    OR (blocker_id = circle_messages.sender_id AND blocked_id = auth.uid())
  )
);

-- ========================================
-- Grant necessary permissions
-- ========================================

GRANT SELECT, INSERT, DELETE ON blocked_users TO authenticated;

-- ========================================
-- Verification Query
-- ========================================

-- Run this to verify policies were created successfully:
SELECT
    schemaname,
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'blocked_users'
ORDER BY policyname;

-- Expected result: You should see 4 policies for blocked_users

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration, test the following:

-- 1. Test that users can block other users:
--    INSERT INTO blocked_users (blocker_id, blocked_id, reason)
--    VALUES (auth.uid(), 'some-other-user-id', 'spam');

-- 2. Test that users can see their blocks:
--    SELECT * FROM blocked_users WHERE blocker_id = auth.uid();

-- 3. Test that blocked users are hidden from profiles:
--    SELECT * FROM profiles;
--    (Should not include blocked users)

-- 4. Test that messages from blocked users are hidden:
--    SELECT * FROM match_messages WHERE match_id = 'some-match-id';
--    (Should not include messages from blocked users)

-- 5. Test that users can unblock:
--    DELETE FROM blocked_users WHERE blocker_id = auth.uid() AND blocked_id = 'some-user-id';

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE blocked_users IS 'RLS enabled: Users can block other users to prevent interaction';

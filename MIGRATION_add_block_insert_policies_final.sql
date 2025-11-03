-- ========================================
-- Migration: Add Working INSERT Policies for Blocking
-- ========================================
-- This migration creates PostgreSQL functions and policies that properly
-- block users from sending messages to each other.
--
-- IMPORTANT: Run this AFTER:
-- - MIGRATION_add_blocked_users.sql
-- - MIGRATION_add_reports.sql
-- - MIGRATION_fix_rls_recursion.sql
--
-- WHY FUNCTIONS ARE NEEDED:
-- Direct policy queries couldn't read from blocked_users due to RLS.
-- SECURITY DEFINER functions bypass this limitation.
-- ========================================

-- ========================================
-- STEP 1: Fix blocked_users SELECT Policy
-- ========================================

-- Allow users to see blocks where they're involved (blocker OR blocked)
DROP POLICY IF EXISTS "Users can read own blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can read blocks involving them" ON blocked_users;

CREATE POLICY "Users can read blocks involving them"
ON blocked_users FOR SELECT
TO authenticated
USING (
  blocker_id = auth.uid() OR blocked_id = auth.uid()
);

-- Also fix INSERT and DELETE to use authenticated role
DROP POLICY IF EXISTS "Users can block others" ON blocked_users;
CREATE POLICY "Users can block others"
ON blocked_users FOR INSERT
TO authenticated
WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Users can unblock others" ON blocked_users;
CREATE POLICY "Users can unblock others"
ON blocked_users FOR DELETE
TO authenticated
USING (blocker_id = auth.uid());

-- ========================================
-- STEP 2: Create Helper Functions
-- ========================================

-- Function to check if user is blocked in a match
CREATE OR REPLACE FUNCTION is_blocked_in_match(user_id UUID, check_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM match_participants WHERE match_id = check_match_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM match_participants WHERE match_id = check_match_id
      ))
    )
  );
END;
$$;

-- Function to check if user is blocked in an event
CREATE OR REPLACE FUNCTION is_blocked_in_event(user_id UUID, check_event_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM event_participants WHERE event_id = check_event_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM event_participants WHERE event_id = check_event_id
      ))
    )
  );
END;
$$;

-- Function to check if user is blocked in a circle
CREATE OR REPLACE FUNCTION is_blocked_in_circle(user_id UUID, check_circle_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM circle_members WHERE circle_id = check_circle_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM circle_members WHERE circle_id = check_circle_id
      ))
    )
  );
END;
$$;

-- ========================================
-- STEP 3: Create INSERT Policies Using Functions
-- ========================================

-- Match Messages
DROP POLICY IF EXISTS "Users can insert messages in matches" ON match_messages;
DROP POLICY IF EXISTS "Users can insert match messages if they are participants" ON match_messages;
DROP POLICY IF EXISTS "Users can insert match messages with block check" ON match_messages;
DROP POLICY IF EXISTS "Match message insert with blocking" ON match_messages;
DROP POLICY IF EXISTS "Block test policy" ON match_messages;

CREATE POLICY "Match message insert with blocking"
ON match_messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM match_participants
    WHERE match_participants.match_id = match_messages.match_id
    AND match_participants.profile_id = auth.uid()
  )
  AND NOT is_blocked_in_match(auth.uid(), match_messages.match_id)
);

-- Event Messages
DROP POLICY IF EXISTS "Users can send messages in their events" ON event_messages;
DROP POLICY IF EXISTS "Event message insert with blocking" ON event_messages;

CREATE POLICY "Event message insert with blocking"
ON event_messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.event_id = event_messages.event_id
    AND event_participants.profile_id = auth.uid()
  )
  AND NOT is_blocked_in_event(auth.uid(), event_messages.event_id)
);

-- Circle Messages
DROP POLICY IF EXISTS "Users can insert messages to circles they are members of" ON circle_messages;
DROP POLICY IF EXISTS "Circle message insert with blocking" ON circle_messages;

CREATE POLICY "Circle message insert with blocking"
ON circle_messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circle_messages.circle_id
    AND circle_members.profile_id = auth.uid()
  )
  AND NOT is_blocked_in_circle(auth.uid(), circle_messages.circle_id)
);

-- ========================================
-- STEP 4: Fix Duplicate SELECT Policy
-- ========================================

-- Remove the old SELECT policy without blocking filter
DROP POLICY IF EXISTS "Users can view messages in their matches" ON match_messages;

-- The policy "Users can read match messages if they are participants"
-- already has blocking filter, so we keep that one

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Run these to verify everything is set up correctly:

-- 1. Check blocked_users policies
SELECT
    policyname,
    cmd,
    roles
FROM pg_policies
WHERE tablename = 'blocked_users'
ORDER BY cmd;

-- 2. Check message INSERT policies
SELECT
    tablename,
    policyname,
    roles
FROM pg_policies
WHERE tablename IN ('match_messages', 'event_messages', 'circle_messages')
    AND cmd = 'INSERT'
ORDER BY tablename;

-- 3. Check functions exist
SELECT routine_name
FROM information_schema.routines
WHERE routine_name LIKE 'is_blocked_in_%'
ORDER BY routine_name;

-- ========================================
-- TESTING
-- ========================================

-- Test blocking:
-- 1. User A blocks User B
-- 2. User B tries to send a message → should get 403 error
-- 3. User A tries to send a message → should get 403 error (bidirectional)
-- 4. User A unblocks User B
-- 5. Both users can send messages again

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON FUNCTION is_blocked_in_match IS 'Checks if a user has a block relationship with any participant in a match';
COMMENT ON FUNCTION is_blocked_in_event IS 'Checks if a user has a block relationship with any participant in an event';
COMMENT ON FUNCTION is_blocked_in_circle IS 'Checks if a user has a block relationship with any member in a circle';

-- ========================================
-- Migration: Change to Unilateral Blocking
-- ========================================
-- This migration changes the blocking system from BIDIRECTIONAL to UNILATERAL.
--
-- BIDIRECTIONAL (old): If A blocks B, both A and B cannot message each other
-- UNILATERAL (new): If A blocks B:
--   ✅ A doesn't see B's messages
--   ✅ B can still send messages (but A never sees them)
--   ✅ B doesn't know they're blocked
--   ✅ A can still send messages to B (if needed)
--
-- This matches modern social media behavior (Twitter, Instagram, Discord).
--
-- IMPORTANT: Run this AFTER all previous blocking migrations:
-- - MIGRATION_add_blocked_users.sql
-- - MIGRATION_fix_rls_recursion.sql
-- - MIGRATION_add_block_insert_policies_final.sql
-- ========================================

-- ========================================
-- STEP 1: Update Message SELECT Policies
-- ========================================
-- These control which messages users can SEE.
-- Change from: "Hide if EITHER user blocked the other"
-- To: "Hide only if VIEWER blocked SENDER"

-- Match Messages
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
  -- Message must not be from a user that the VIEWER has blocked (unilateral)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = match_messages.sender_id
  )
);

-- Event Messages
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
  -- Message must not be from a user that the VIEWER has blocked (unilateral)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = event_messages.sender_id
  )
);

-- Circle Messages
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
  -- Message must not be from a user that the VIEWER has blocked (unilateral)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = circle_messages.sender_id
  )
);

-- ========================================
-- STEP 2: Update Helper Functions for INSERT
-- ========================================
-- These control who can SEND messages.
-- Change from: "Block if EITHER user blocked the other"
-- To: "Block only if any RECIPIENT has blocked SENDER"

-- Function to check if any match participant has blocked the sender
CREATE OR REPLACE FUNCTION is_blocked_in_match(user_id UUID, check_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Check if any participant in the match has blocked the sender (unilateral)
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    JOIN match_participants mp ON mp.profile_id = bu.blocker_id
    WHERE mp.match_id = check_match_id
      AND bu.blocked_id = user_id
      AND mp.profile_id != user_id  -- Don't check if sender blocked themselves
  );
END;
$$;

-- Function to check if any event participant has blocked the sender
CREATE OR REPLACE FUNCTION is_blocked_in_event(user_id UUID, check_event_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Check if any participant in the event has blocked the sender (unilateral)
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    JOIN event_participants ep ON ep.profile_id = bu.blocker_id
    WHERE ep.event_id = check_event_id
      AND bu.blocked_id = user_id
      AND ep.profile_id != user_id  -- Don't check if sender blocked themselves
  );
END;
$$;

-- Function to check if any circle member has blocked the sender
CREATE OR REPLACE FUNCTION is_blocked_in_circle(user_id UUID, check_circle_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Check if any member in the circle has blocked the sender (unilateral)
  RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    JOIN circle_members cm ON cm.profile_id = bu.blocker_id
    WHERE cm.circle_id = check_circle_id
      AND bu.blocked_id = user_id
      AND cm.profile_id != user_id  -- Don't check if sender blocked themselves
  );
END;
$$;

-- ========================================
-- STEP 3: Update Participant SELECT Policies
-- ========================================
-- Control who can see participant lists.
-- Change to unilateral: only hide if VIEWER blocked them.

-- Match Participants
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
  -- Must not be blocked by the VIEWER (unilateral)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = match_participants.profile_id
  )
);

-- Event Participants
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
  -- Must not be blocked by the VIEWER (unilateral)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = event_participants.profile_id
  )
);

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- 1. Check that message SELECT policies only check one direction
SELECT
    tablename,
    policyname,
    qual::text as policy_condition
FROM pg_policies
WHERE tablename IN ('match_messages', 'event_messages', 'circle_messages')
    AND cmd = 'SELECT'
ORDER BY tablename;

-- Look for: should only have "blocker_id = auth.uid()" without the OR clause

-- 2. Check that INSERT functions exist and are updated
SELECT
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name LIKE 'is_blocked_in_%'
ORDER BY routine_name;

-- 3. Check participant policies
SELECT
    tablename,
    policyname,
    qual::text as policy_condition
FROM pg_policies
WHERE tablename IN ('match_participants', 'event_participants')
    AND cmd = 'SELECT'
ORDER BY tablename;

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- Test unilateral blocking:
--
-- 1. User A blocks User B:
--    INSERT INTO blocked_users (blocker_id, blocked_id)
--    VALUES ('user-a-id', 'user-b-id');
--
-- 2. User A's view:
--    - SELECT * FROM match_messages WHERE ...
--    - Should NOT see any messages from User B
--    - CAN send messages to the match (no 403 error)
--
-- 3. User B's view:
--    - SELECT * FROM match_messages WHERE ...
--    - STILL SEES all messages (including from User A)
--    - CAN send messages (but User A won't see them)
--    - DOESN'T KNOW they're blocked (no error, just User A won't see it)
--
-- 4. Unblock:
--    DELETE FROM blocked_users
--    WHERE blocker_id = 'user-a-id' AND blocked_id = 'user-b-id';
--
-- 5. Both users can now see each other's messages normally

-- ========================================
-- BEHAVIOR SUMMARY
-- ========================================

-- BEFORE (Bidirectional):
-- A blocks B → Neither can message each other (403 errors for both)
--
-- AFTER (Unilateral):
-- A blocks B:
--   ✅ A doesn't see B's messages (invisible to A)
--   ✅ B can still message (no errors)
--   ✅ B doesn't know they're blocked (no indication)
--   ✅ A can still message B if needed (though rare)
--
-- This is the standard behavior for:
-- - Twitter/X (blocker hides tweets)
-- - Instagram (blocker hides posts/messages)
-- - Discord (blocker hides messages)
-- - WhatsApp (blocker doesn't receive messages)

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON FUNCTION is_blocked_in_match IS 'Unilateral blocking: Checks if any match participant has blocked the sender';
COMMENT ON FUNCTION is_blocked_in_event IS 'Unilateral blocking: Checks if any event participant has blocked the sender';
COMMENT ON FUNCTION is_blocked_in_circle IS 'Unilateral blocking: Checks if any circle member has blocked the sender';

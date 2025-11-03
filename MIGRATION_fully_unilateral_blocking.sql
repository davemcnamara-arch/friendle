-- ========================================
-- Migration: Fully Unilateral Blocking
-- ========================================
-- This migration makes blocking FULLY unilateral by removing INSERT
-- restrictions. Blocked users CAN send messages, but blockers don't see them.
--
-- BEFORE (Semi-Unilateral):
-- - A blocks B
-- - B gets 403 when trying to send (prevented from sending)
-- - C (who hasn't blocked B) also doesn't see B's messages
--
-- AFTER (Fully Unilateral):
-- - A blocks B
-- - B can send messages (no 403 error)
-- - A doesn't see B's messages (SELECT filtered)
-- - C sees B's messages normally (no block relationship)
-- - B doesn't know they're blocked (no error indication)
--
-- This matches Twitter/X behavior exactly!
--
-- IMPORTANT: Run this AFTER:
-- - MIGRATION_unilateral_blocking.sql
-- - MIGRATION_fix_duplicate_policies.sql
-- ========================================

-- ========================================
-- STEP 1: Remove INSERT Blocking Functions
-- ========================================
-- These functions are no longer needed since we're not blocking INSERTs

-- Drop the functions (keep them for now in case we need to revert)
-- We'll just stop using them in the policies

-- ========================================
-- STEP 2: Simplify INSERT Policies
-- ========================================
-- Remove the blocking check from INSERT policies
-- Users can send messages - only SELECT will filter who sees them

-- Match Messages: Allow sending without checking blocks
DROP POLICY IF EXISTS "Match message insert with blocking" ON match_messages;
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
  -- Removed: AND NOT is_blocked_in_match(auth.uid(), match_messages.match_id)
  -- Now blocked users CAN send, but blockers won't see their messages
);

-- Event Messages: Allow sending without checking blocks
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
  -- Removed: AND NOT is_blocked_in_event(auth.uid(), event_messages.event_id)
  -- Now blocked users CAN send, but blockers won't see their messages
);

-- Circle Messages: Allow sending without checking blocks
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
  -- Removed: AND NOT is_blocked_in_circle(auth.uid(), circle_messages.circle_id)
  -- Now blocked users CAN send, but blockers won't see their messages
);

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- 1. Check INSERT policies no longer reference blocking functions
SELECT
    tablename,
    policyname,
    with_check::text as policy_check
FROM pg_policies
WHERE tablename IN ('match_messages', 'event_messages', 'circle_messages')
    AND cmd = 'INSERT'
ORDER BY tablename;

-- Look for: should NOT contain "is_blocked_in_" references

-- 2. Verify SELECT policies still have blocking filters
SELECT
    tablename,
    policyname,
    CASE
        WHEN qual::text LIKE '%blocked_users%' THEN '✅ Has blocking filter'
        ELSE '❌ Missing blocking filter'
    END as has_blocking
FROM pg_policies
WHERE tablename IN ('match_messages', 'event_messages', 'circle_messages')
    AND cmd = 'SELECT'
ORDER BY tablename;

-- Expected: All should show "✅ Has blocking filter"

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- Test fully unilateral blocking:
--
-- Setup: User A, User B, User C are all in the same match
--
-- 1. User A blocks User B:
--    INSERT INTO blocked_users (blocker_id, blocked_id)
--    VALUES ('user-a-id', 'user-b-id');
--
-- 2. User B sends a message:
--    INSERT INTO match_messages (match_id, sender_id, content)
--    VALUES ('match-id', 'user-b-id', 'Hello everyone!');
--    Expected: ✅ SUCCESS (no 403 error!)
--
-- 3. User A queries messages:
--    SELECT * FROM match_messages WHERE match_id = 'match-id';
--    Expected: Does NOT see User B's message (filtered by SELECT policy)
--
-- 4. User C queries messages:
--    SELECT * FROM match_messages WHERE match_id = 'match-id';
--    Expected: ✅ SEES User B's message (C hasn't blocked B)
--
-- 5. User B queries messages:
--    SELECT * FROM match_messages WHERE match_id = 'match-id';
--    Expected: ✅ SEES their own message and everyone else's
--
-- Result: User B doesn't know they're blocked (no error, message appears for them)
--         but User A never sees it. User C sees it normally.

-- ========================================
-- BEHAVIOR COMPARISON
-- ========================================

-- BEFORE (Semi-Unilateral):
-- ┌─────────┬────────────┬──────────────────────────┐
-- │ User    │ Can Send?  │ What They See            │
-- ├─────────┼────────────┼──────────────────────────┤
-- │ A       │ ✅ Yes     │ A's, C's (B filtered)    │
-- │ B       │ ❌ No      │ A's, B's, C's            │
-- │ C       │ ✅ Yes     │ A's, C's (B can't send)  │
-- └─────────┴────────────┴──────────────────────────┘
--
-- AFTER (Fully Unilateral):
-- ┌─────────┬────────────┬──────────────────────────┐
-- │ User    │ Can Send?  │ What They See            │
-- ├─────────┼────────────┼──────────────────────────┤
-- │ A       │ ✅ Yes     │ A's, C's (B filtered)    │
-- │ B       │ ✅ Yes     │ A's, B's, C's            │
-- │ C       │ ✅ Yes     │ A's, B's, C's            │
-- └─────────┴────────────┴──────────────────────────┘

-- ========================================
-- ADVANTAGES OF FULLY UNILATERAL
-- ========================================

-- ✅ B doesn't get error messages (no indication of being blocked)
-- ✅ C (innocent bystander) is not affected by A's block
-- ✅ B's messages exist in database (can be reported/moderated if needed)
-- ✅ B can still participate in group conversations
-- ✅ Only A's view is affected (truly unilateral)
-- ✅ Matches Twitter/X behavior exactly
-- ✅ Less confrontational (B doesn't realize they're blocked)

-- ========================================
-- SECURITY CONSIDERATIONS
-- ========================================

-- ⚠️ Blocked users can send messages
--    - This is by design (fully unilateral)
--    - Blocker doesn't see them (protected)
--    - Messages can still be reported
--
-- ⚠️ Database will contain messages from blocked users
--    - This is normal (same as Twitter)
--    - SELECT policies filter them from blockers
--    - Admins can still see all messages for moderation
--
-- ⚠️ Blocked user doesn't know they're blocked
--    - This is a feature, not a bug
--    - Reduces escalation risk
--    - Matches modern social platform behavior

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON POLICY "Match message insert with blocking" ON match_messages IS
'Fully unilateral: allows all participants to send, SELECT policies filter who sees messages';

COMMENT ON POLICY "Event message insert with blocking" ON event_messages IS
'Fully unilateral: allows all participants to send, SELECT policies filter who sees messages';

COMMENT ON POLICY "Circle message insert with blocking" ON circle_messages IS
'Fully unilateral: allows all participants to send, SELECT policies filter who sees messages';

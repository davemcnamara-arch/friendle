-- ========================================
-- Migration: Allow Event Participants to Lock Event Details
-- ========================================
-- This migration updates the events UPDATE policy to allow any participant
-- in an event chat (planning mode) to lock in details, not just the creator.
--
-- CHANGE: Previously only event creators could update their events.
-- NOW: Event creators OR event participants can update events.
--
-- This enables collaborative event planning where any participant can
-- finalize the event details when consensus is reached.
-- ========================================

-- ========================================
-- STEP 1: Drop existing UPDATE policy
-- ========================================

DROP POLICY IF EXISTS "Event creators can update their events" ON events;

-- ========================================
-- STEP 2: Create new UPDATE policy for creators AND participants
-- ========================================

-- UPDATE: Event creators OR event participants can update events
-- This allows anyone in the event chat to lock in details
CREATE POLICY "Event creators and participants can update events"
ON events FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid()
  OR
  id IN (
    SELECT event_id FROM event_participants WHERE profile_id = auth.uid()
  )
)
WITH CHECK (
  created_by = auth.uid()
  OR
  id IN (
    SELECT event_id FROM event_participants WHERE profile_id = auth.uid()
  )
);

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check that the new policy exists
SELECT
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'events' AND cmd = 'UPDATE'
ORDER BY policyname;

-- Expected output:
-- | events | Event creators and participants can update events | UPDATE |

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration:
--
-- 1. As an event creator, try to lock in event details (should work)
-- 2. As an event participant (non-creator), try to lock in details (should NOW work)
-- 3. As a non-participant, try to update an event (should be blocked)

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE events IS 'RLS: Creators AND participants can update events (allows collaborative detail locking)';

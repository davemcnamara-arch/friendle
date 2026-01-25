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
--
-- SOLUTION: Uses a SECURITY DEFINER function to check participation
-- without triggering RLS recursion on event_participants table.
-- ========================================

-- ========================================
-- STEP 1: Create helper function to check event participation
-- ========================================

-- This function checks if a user is a participant in an event
-- SECURITY DEFINER bypasses RLS to avoid infinite recursion
CREATE OR REPLACE FUNCTION is_event_participant(event_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_id = event_uuid AND profile_id = user_uuid
  );
$$;

-- ========================================
-- STEP 2: Drop existing UPDATE policy
-- ========================================

DROP POLICY IF EXISTS "Event creators can update their events" ON events;
DROP POLICY IF EXISTS "Event creators and participants can update events" ON events;

-- ========================================
-- STEP 3: Create new UPDATE policy for creators AND participants
-- ========================================

-- UPDATE: Event creators OR event participants can update events
-- Uses the helper function to avoid RLS recursion
CREATE POLICY "Event creators and participants can update events"
ON events FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid()
  OR
  is_event_participant(id, auth.uid())
)
WITH CHECK (
  created_by = auth.uid()
  OR
  is_event_participant(id, auth.uid())
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

-- Test the helper function (replace UUIDs with real values)
-- SELECT is_event_participant('event-uuid-here', 'user-uuid-here');

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

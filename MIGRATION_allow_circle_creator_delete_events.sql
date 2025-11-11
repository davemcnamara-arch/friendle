-- ========================================
-- Migration: Allow Circle Creators to Delete Events
-- ========================================
-- This migration updates the event deletion policy to allow both:
-- 1. Event creators (as before)
-- 2. Circle creators/admins
--
-- This fixes the issue where events created by circle members cannot be
-- deleted by the circle admin, which is useful for managing suggested events.
-- ========================================

-- Drop the existing restrictive delete policy
DROP POLICY IF EXISTS "Event creators can delete their events" ON events;

-- Create new policy that allows event creator OR circle creator to delete
CREATE POLICY "Event and circle creators can delete events"
ON events FOR DELETE
TO authenticated
USING (
  created_by = auth.uid()
  OR
  circle_id IN (
    SELECT id FROM circles WHERE created_by = auth.uid()
  )
);

-- ========================================
-- VERIFICATION QUERY
-- ========================================

-- Check that the policy was created
SELECT
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'events' AND cmd = 'DELETE'
ORDER BY policyname;

-- Expected output:
-- | events | Event and circle creators can delete events | DELETE |

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration:
--
-- 1. As event creator: Try to delete your own event (should work)
-- 2. As circle creator: Try to delete any event in your circle (should work)
-- 3. As regular circle member: Try to delete another member's event (should be blocked)
-- 4. As non-member: Try to delete event from another circle (should be blocked)

-- ========================================
-- WHY THIS FIXES THE ISSUE
-- ========================================

/*
Previously, only the event creator could delete events:
  USING (created_by = auth.uid())

Now, the policy allows deletion if either:
1. You created the event, OR
2. You created the circle that contains the event

This is useful for:
- Circle admins managing "suggested" events from members
- Cleaning up unwanted events in circles you own
- Maintaining control over circle content as the creator

The policy is still secure because:
- Only authenticated users can delete
- You must be either the event creator or circle creator
- Regular members cannot delete each other's events
- Non-members cannot access events at all (SELECT policy)
*/

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON POLICY "Event and circle creators can delete events" ON events
IS 'Allows event creators and circle creators to delete events';

-- ========================================
-- Migration: Remove Duplicate Policies on Events Table
-- ========================================
-- This migration removes ALL duplicate policies on the events table
-- and ensures only ONE policy exists per operation type (SELECT, INSERT, UPDATE, DELETE).
--
-- PROBLEM: Multiple policies of the same type (e.g., 2 SELECT policies) are combined
-- with OR logic, which can cause conflicts and infinite recursion.
--
-- SOLUTION: Drop all policies and recreate with simplified, non-recursive versions.
--
-- Run this migration AFTER MIGRATION_fix_events_update_recursion.sql
-- ========================================

-- ========================================
-- STEP 1: Drop ALL existing events policies
-- ========================================

-- Drop all possible policy names (from various migrations)
DROP POLICY IF EXISTS "Circle members can read events" ON events;
DROP POLICY IF EXISTS "Users can view events in their matches" ON events;
DROP POLICY IF EXISTS "Users can read events" ON events;

DROP POLICY IF EXISTS "Circle members can create events" ON events;
DROP POLICY IF EXISTS "Users can create events for their matches" ON events;
DROP POLICY IF EXISTS "Users can create events" ON events;

DROP POLICY IF EXISTS "Creators can update events" ON events;
DROP POLICY IF EXISTS "Users can update their events" ON events;

DROP POLICY IF EXISTS "Creators can delete events" ON events;
DROP POLICY IF EXISTS "Users can delete their events" ON events;

-- ========================================
-- STEP 2: Create SINGLE, non-recursive policies
-- ========================================

-- SELECT: Users can read events in their circles
-- Uses simple IN clause to avoid recursion
CREATE POLICY "Users can read events in their circles"
ON events FOR SELECT
TO authenticated
USING (
  circle_id IN (
    SELECT circle_id FROM circle_members WHERE profile_id = auth.uid()
  )
);

-- INSERT: Users can create events in their circles
CREATE POLICY "Users can create events in their circles"
ON events FOR INSERT
TO authenticated
WITH CHECK (
  circle_id IN (
    SELECT circle_id FROM circle_members WHERE profile_id = auth.uid()
  )
  AND created_by = auth.uid()
);

-- UPDATE: Only event creators can update their events
-- Simple policy to avoid recursion - just checks created_by
CREATE POLICY "Event creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- DELETE: Only event creators can delete their events
CREATE POLICY "Event creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (created_by = auth.uid());

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Should show exactly 4 policies (1 per operation)
SELECT
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'events'
ORDER BY cmd, policyname;

-- Expected output:
-- | events | Event creators can delete their events      | DELETE |
-- | events | Users can create events in their circles    | INSERT |
-- | events | Users can read events in their circles      | SELECT |
-- | events | Event creators can update their events      | UPDATE |

-- Count policies per operation (should all be 1)
SELECT
    cmd as operation,
    COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'events'
GROUP BY cmd
ORDER BY cmd;

-- Expected: DELETE=1, INSERT=1, SELECT=1, UPDATE=1

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration:
--
-- 1. Try to view events in your circles (should work)
-- 2. Try to create a new event (should work)
-- 3. Try to update event details as creator (should work without 500 error)
-- 4. Try to update event as non-creator (should be blocked)
-- 5. Try to cancel/delete event as creator (should work)
-- 6. Try to delete event as non-creator (should be blocked)

-- ========================================
-- WHY THIS FIXES THE ISSUE
-- ========================================

/*
Having duplicate policies causes problems because:

1. Multiple SELECT policies are combined with OR logic
   - "Circle members can read" OR "Users can view events in matches"
   - This can create complex query plans that trigger recursion

2. Multiple UPDATE policies can conflict
   - PostgreSQL might evaluate both policies, causing recursion

3. Simplified policies are faster and more predictable
   - IN (SELECT ...) is simpler than EXISTS with complex joins
   - Just checking created_by = auth.uid() is straightforward

This follows the pattern from MIGRATION_fix_duplicate_policies.sql
which fixed similar issues with message tables.
*/

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE events IS 'RLS enabled with single, simplified policies per operation to avoid recursion';

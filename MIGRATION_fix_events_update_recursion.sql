-- ========================================
-- Migration: Fix Infinite Recursion in Events UPDATE
-- ========================================
-- This fixes the "infinite recursion detected in policy for relation events" error
-- that occurs when trying to update event details.
--
-- PROBLEM: The UPDATE policy may trigger SELECT policies which create recursion
-- SOLUTION: Simplify policies and ensure UPDATE doesn't trigger complex SELECT chains
--
-- Run this migration to fix event update errors.
-- ========================================

-- ========================================
-- STEP 1: Drop existing events policies
-- ========================================

DROP POLICY IF EXISTS "Circle members can read events" ON events;
DROP POLICY IF EXISTS "Circle members can create events" ON events;
DROP POLICY IF EXISTS "Creators can update events" ON events;
DROP POLICY IF EXISTS "Creators can delete events" ON events;

-- ========================================
-- STEP 2: Create simplified, non-recursive policies
-- ========================================

-- SELECT: Users can read events for circles they're in
-- Keep this simple to avoid recursion
CREATE POLICY "Circle members can read events"
ON events FOR SELECT
TO authenticated
USING (
  circle_id IN (
    SELECT circle_id FROM circle_members WHERE profile_id = auth.uid()
  )
);

-- INSERT: Users can create events in their circles
CREATE POLICY "Circle members can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (
  circle_id IN (
    SELECT circle_id FROM circle_members WHERE profile_id = auth.uid()
  )
  AND created_by = auth.uid()
);

-- UPDATE: Only event creators can update (simplified to avoid recursion)
-- This policy doesn't use EXISTS or complex subqueries that could trigger recursion
CREATE POLICY "Creators can update events"
ON events FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- DELETE: Only event creators can delete
CREATE POLICY "Creators can delete events"
ON events FOR DELETE
TO authenticated
USING (created_by = auth.uid());

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check that policies were created successfully
SELECT
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'events'
ORDER BY cmd, policyname;

-- Expected: 4 policies (SELECT, INSERT, UPDATE, DELETE)

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration, test the following:
--
-- 1. Create an event (should work)
-- 2. Update the event details (should work without 500 error)
-- 3. Cancel an event (should work)
-- 4. Delete an event (should work)
--
-- All operations should complete without "infinite recursion" errors.

-- ========================================
-- WHY THIS FIXES THE ISSUE
-- ========================================

/*
The UPDATE policy is now simplified to only check created_by = auth.uid()
without any complex EXISTS clauses or joins that could trigger recursion.

The key change is using IN (SELECT ...) instead of EXISTS (SELECT ...),
which PostgreSQL handles differently and is less likely to cause recursion.

This matches the pattern used in other successful migrations like
MIGRATION_fix_recursion_complete.sql for profiles and circle_members.
*/

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE events IS 'RLS enabled: Non-recursive policies for read/update/delete operations';

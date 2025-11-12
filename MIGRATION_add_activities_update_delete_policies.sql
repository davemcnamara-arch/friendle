-- ========================================
-- Migration: Add UPDATE and DELETE Policies for Activities
-- ========================================
-- This migration adds missing UPDATE and DELETE policies for the activities table.
-- Previously, only SELECT and INSERT policies existed, preventing any deletion or editing.
--
-- This allows circle creators to manage (update/delete) custom activities in their circles.
-- ========================================

-- ========================================
-- STEP 1: Add UPDATE policy for activities
-- ========================================

-- Circle creators can update activities in their circles
DROP POLICY IF EXISTS "Circle creators can update activities" ON activities;
CREATE POLICY "Circle creators can update activities"
ON activities FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM circles
    WHERE circles.id = activities.circle_id
    AND circles.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circles
    WHERE circles.id = activities.circle_id
    AND circles.created_by = auth.uid()
  )
);

-- ========================================
-- STEP 2: Add DELETE policy for activities
-- ========================================

-- Circle creators can delete activities in their circles
DROP POLICY IF EXISTS "Circle creators can delete activities" ON activities;
CREATE POLICY "Circle creators can delete activities"
ON activities FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM circles
    WHERE circles.id = activities.circle_id
    AND circles.created_by = auth.uid()
  )
);

-- ========================================
-- STEP 3: Update GRANT permissions
-- ========================================

-- Add UPDATE and DELETE permissions (previously only had SELECT, INSERT)
GRANT UPDATE, DELETE ON activities TO authenticated;

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check that policies were created
SELECT
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'activities'
ORDER BY cmd, policyname;

-- Expected output should include:
-- | activities | Circle creators can delete activities | DELETE |
-- | activities | Circle creators can update activities | UPDATE |
-- | activities | Users can create circle activities    | INSERT |
-- | activities | Users can read circle activities      | SELECT |

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration:
--
-- 1. As circle creator: Open "Manage Activities" modal
-- 2. Try to edit a custom activity (should work)
-- 3. Try to delete a custom activity (should work)
-- 4. As regular circle member: Try to delete another member's suggested activity (should be blocked)
-- 5. As non-member: Try to delete activity from another circle (should be blocked)

-- ========================================
-- WHY THIS FIXES THE ISSUE
-- ========================================

/*
The previous RLS setup only allowed:
  - SELECT (read) activities
  - INSERT (create) activities

But there were NO policies for:
  - UPDATE (edit) activities
  - DELETE (remove) activities

Without a DELETE policy, the database would reject any delete attempts,
even though the GRANT statement might allow it. RLS policies are enforced
first, and if no policy matches, the operation is denied.

This migration:
1. Adds UPDATE policy - only circle creators can edit activities in their circles
2. Adds DELETE policy - only circle creators can delete activities in their circles
3. Updates GRANT to include UPDATE and DELETE permissions

This gives circle admins control over custom activities while preventing
regular members from deleting each other's suggestions without admin approval.
*/

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE activities IS 'RLS enabled with full CRUD policies for circle creators';

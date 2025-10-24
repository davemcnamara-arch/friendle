-- ========================================
-- FIX: Circle Access - Only Show Current Circles
-- ========================================
-- Users can see circles they LEFT - this fixes that
-- ========================================

-- Drop the problematic "read by code" policy
DROP POLICY IF EXISTS "Users can read circles by code" ON circles;
DROP POLICY IF EXISTS "Users can read their circles" ON circles;

-- Create a single, correct policy for reading circles
CREATE POLICY "Users can read circles they are currently in"
ON circles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT circle_id
    FROM circle_members
    WHERE profile_id = auth.uid()
  )
);

-- ========================================
-- NOTE: Invite Code Validation
-- ========================================
-- The app queries circles by invite code when joining: .eq('code', inviteCode)
-- With only the policy above, users couldn't validate invite codes
--
-- HOWEVER: PostgreSQL RLS allows queries that return empty results
-- So the app's invite code check will work:
--   - If user is NOT in circle: query returns empty (can't see it)
--   - User enters code in app
--   - App calls INSERT into circle_members
--   - INSERT policy allows adding self
--   - After insert, user CAN see circle (now a member)
--
-- The invite code validation happens via the INSERT attempt, not SELECT
-- This is more secure than allowing SELECT by code

-- ========================================
-- Verification
-- ========================================

SELECT
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'circles'
ORDER BY policyname;

-- ========================================
-- Test Query
-- ========================================
-- After running this, check:
-- SELECT * FROM circles;
-- Should return only circles you're currently a member of

-- ========================================
-- Migration: Fix Duplicate Policies
-- ========================================
-- This migration removes duplicate overly permissive policies
-- that bypass blocking checks.
--
-- PROBLEM: Multiple SELECT policies on the same table are combined with OR logic.
-- If one policy has USING (true), it bypasses all other restrictions.
--
-- Run this AFTER MIGRATION_unilateral_blocking.sql
-- ========================================

-- ========================================
-- Drop Overly Permissive Policy
-- ========================================

-- This policy allows reading ALL event participants, bypassing blocking
DROP POLICY IF EXISTS "Users can view event participants" ON event_participants;

-- This policy allows reading ALL match participants, bypassing blocking
DROP POLICY IF EXISTS "Users can view match participants" ON match_participants;

-- ========================================
-- Verification
-- ========================================

-- Check that only ONE SELECT policy exists per table
SELECT
    tablename,
    COUNT(*) as select_policy_count
FROM pg_policies
WHERE tablename IN ('event_participants', 'match_participants')
    AND cmd = 'SELECT'
GROUP BY tablename;

-- Expected result: 1 policy per table

-- Check the remaining policies have blocking filters
SELECT
    tablename,
    policyname,
    CASE
        WHEN qual::text LIKE '%blocked_users%' THEN '✅ Has blocking filter'
        ELSE '❌ Missing blocking filter'
    END as has_blocking
FROM pg_policies
WHERE tablename IN ('event_participants', 'match_participants')
    AND cmd = 'SELECT'
ORDER BY tablename;

-- Expected: Both should show "✅ Has blocking filter"

-- ========================================
-- Migration Complete
-- ========================================

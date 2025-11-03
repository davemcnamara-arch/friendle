-- ========================================
-- Migration: Fix event_messages Duplicate Policy
-- ========================================
-- The event_messages table still has 2 SELECT policies.
-- This migration identifies and removes the duplicate.
--
-- Run this AFTER MIGRATION_fix_duplicate_policies.sql
-- ========================================

-- First, let's see what policies exist
SELECT
    policyname,
    CASE
        WHEN qual::text LIKE '%blocked_users%' THEN '✅ Has blocking filter'
        ELSE '❌ Missing blocking filter'
    END as has_blocking
FROM pg_policies
WHERE tablename = 'event_messages'
    AND cmd = 'SELECT'
ORDER BY policyname;

-- Drop ALL possible duplicate policy names for event_messages
DROP POLICY IF EXISTS "Users can view messages in their events" ON event_messages;
DROP POLICY IF EXISTS "Users can view event messages" ON event_messages;
DROP POLICY IF EXISTS "Users can read event messages" ON event_messages;
DROP POLICY IF EXISTS "Allow users to read event messages" ON event_messages;
DROP POLICY IF EXISTS "Event messages are viewable by participants" ON event_messages;

-- Verify we now have exactly 1 SELECT policy with blocking filter
SELECT
    policyname,
    CASE
        WHEN qual::text LIKE '%blocked_users%' THEN '✅ Has blocking filter'
        ELSE '❌ Missing blocking filter'
    END as has_blocking
FROM pg_policies
WHERE tablename = 'event_messages'
    AND cmd = 'SELECT';

-- Expected: 1 row with "✅ Has blocking filter"

-- Final verification: count SELECT policies per table
SELECT
    tablename,
    COUNT(*) as select_policy_count
FROM pg_policies
WHERE tablename IN ('match_messages', 'event_messages', 'circle_messages',
                    'match_participants', 'event_participants')
    AND cmd = 'SELECT'
GROUP BY tablename
ORDER BY tablename;

-- Expected: All tables should have select_policy_count = 1

-- ========================================
-- Migration Complete
-- ========================================

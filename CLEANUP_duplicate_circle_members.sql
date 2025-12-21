-- ============================================================================
-- CLEANUP SCRIPT: Remove Duplicate Circle Members
-- ============================================================================
--
-- Purpose: Fix existing duplicate circle memberships caused by users who:
--          1. Deleted their account (which only cleared localStorage)
--          2. Created a new account with the same email
--          3. Rejoined their circles (creating duplicate memberships)
--
-- Usage:
--   1. First, run the migration: MIGRATION_fix_duplicate_circle_members.sql
--   2. Then run this cleanup script to fix existing duplicates
--
-- Safety:
--   - This script is idempotent (safe to run multiple times)
--   - First query shows what will be removed (preview)
--   - Second query performs the actual cleanup
-- ============================================================================

-- ============================================================================
-- STEP 1: PREVIEW - Find all duplicate memberships
-- ============================================================================

SELECT
    'PREVIEW: These duplicates will be cleaned up:' as info;

SELECT
    circle_id,
    circle_name,
    email,
    profile_id_1,
    profile_id_2,
    name_1,
    name_2
FROM find_duplicate_circle_members()
ORDER BY circle_name, email;

-- ============================================================================
-- STEP 2: CLEANUP - Remove duplicates (keeps newer profile)
-- ============================================================================

-- Uncomment the following lines to actually perform the cleanup:
-- SELECT
--     'Cleanup Results:' as info;
--
-- SELECT
--     circle_id,
--     removed_profile_ids,
--     kept_profile_id,
--     'Removed ' || array_length(removed_profile_ids, 1) || ' duplicate(s)' as summary
-- FROM cleanup_duplicate_circle_members();

-- ============================================================================
-- STEP 3: VERIFICATION - Confirm no duplicates remain
-- ============================================================================

-- Run this after cleanup to verify success:
-- SELECT
--     'Verification: Remaining duplicates (should be empty):' as info;
--
-- SELECT * FROM find_duplicate_circle_members();

-- ============================================================================
-- ALTERNATIVE: Manual Cleanup (if you need more control)
-- ============================================================================

-- If you want to manually review and delete specific duplicates:
--
-- 1. Find duplicates:
-- SELECT
--     cm1.circle_id,
--     c.name as circle_name,
--     u1.email::text,
--     cm1.profile_id as old_profile_id,
--     cm2.profile_id as new_profile_id,
--     p1.name as old_name,
--     p2.name as new_name,
--     u1.created_at as old_created_at,
--     u2.created_at as new_created_at
-- FROM circle_members cm1
-- JOIN circle_members cm2
--     ON cm1.circle_id = cm2.circle_id
--     AND cm1.profile_id < cm2.profile_id
-- JOIN profiles p1 ON cm1.profile_id = p1.id
-- JOIN profiles p2 ON cm2.profile_id = p2.id
-- JOIN auth.users u1 ON cm1.profile_id = u1.id
-- JOIN auth.users u2 ON cm2.profile_id = u2.id
-- JOIN circles c ON cm1.circle_id = c.id
-- WHERE u1.email = u2.email
-- ORDER BY c.name, u1.email;
--
-- 2. Delete specific old membership (replace UUIDs):
-- DELETE FROM circle_members
-- WHERE circle_id = 'YOUR-CIRCLE-UUID'
--   AND profile_id = 'OLD-PROFILE-UUID';

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- After cleanup:
-- - Users will only appear once in each circle
-- - The newer profile (most recent created_at) is kept
-- - Old, orphaned profiles may still exist in the profiles table
--   (they can be cleaned up separately if needed)
--
-- Prevention:
-- - The migration adds proper CASCADE DELETE constraints
-- - The updated resetApp() function now properly deletes accounts
-- - Future account deletions will not create duplicates

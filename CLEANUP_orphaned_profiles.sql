-- ============================================================================
-- CLEANUP SCRIPT: Remove Orphaned Profiles and Circle Memberships
-- ============================================================================
--
-- Purpose: Find and remove profiles/memberships where the auth.users record
--          no longer exists. This happens when:
--          1. User deleted their account through Supabase Auth
--          2. But the profile and circle_members records weren't deleted
--          3. Old username still shows in circle member lists
--
-- Usage:
--   1. First, run the preview queries to see what will be removed
--   2. Then uncomment and run the cleanup queries
--
-- ============================================================================

-- ============================================================================
-- STEP 1: PREVIEW - Find orphaned profiles (no auth.users record)
-- ============================================================================

SELECT
    'ORPHANED PROFILES (no auth.users):' as info;

SELECT
    p.id as profile_id,
    p.name as profile_name,
    p.created_at as profile_created_at,
    'No auth.users record' as status
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE u.id IS NULL
ORDER BY p.created_at DESC;

-- ============================================================================
-- STEP 2: PREVIEW - Find orphaned circle memberships
-- ============================================================================

SELECT
    'ORPHANED CIRCLE MEMBERSHIPS:' as info;

SELECT
    cm.circle_id,
    c.name as circle_name,
    cm.profile_id,
    p.name as profile_name,
    'No auth.users record' as status
FROM circle_members cm
JOIN circles c ON cm.circle_id = c.id
JOIN profiles p ON cm.profile_id = p.id
LEFT JOIN auth.users u ON cm.profile_id = u.id
WHERE u.id IS NULL
ORDER BY c.name, p.name;

-- ============================================================================
-- STEP 3: CLEANUP - Remove orphaned circle memberships
-- ============================================================================

-- Uncomment to delete orphaned circle memberships:
-- DELETE FROM circle_members
-- WHERE profile_id IN (
--     SELECT p.id
--     FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- ============================================================================
-- STEP 4: CLEANUP - Remove orphaned profiles
-- ============================================================================

-- Uncomment to delete orphaned profiles (after removing memberships):
-- DELETE FROM profiles
-- WHERE id IN (
--     SELECT p.id
--     FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- ============================================================================
-- STEP 5: VERIFICATION
-- ============================================================================

-- Run this after cleanup to verify all orphaned records are removed:
-- SELECT
--     'VERIFICATION - Remaining orphaned profiles:' as info;
--
-- SELECT COUNT(*) as orphaned_count
-- FROM profiles p
-- LEFT JOIN auth.users u ON p.id = u.id
-- WHERE u.id IS NULL;

-- Expected: 0

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Why this happens:
-- - When users delete their account, Supabase Auth deletes the auth.users record
-- - But profiles, circle_members, and other app data are NOT automatically deleted
-- - This leaves "ghost" profiles that show up in the UI but can't log in
--
-- How the fix prevents this:
-- - The updated resetApp() function now calls delete_user_account()
-- - This properly deletes all app data before the user signs out
-- - The CASCADE DELETE constraints ensure related data is cleaned up
--
-- After cleanup:
-- - Old usernames will no longer appear in circle member lists
-- - Only active users (with valid auth.users records) will be visible

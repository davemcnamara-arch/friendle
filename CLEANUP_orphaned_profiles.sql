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
-- STEP 3: CLEANUP - Remove all data for orphaned profiles
-- ============================================================================

-- IMPORTANT: Data must be deleted in the correct order due to foreign key constraints
-- Uncomment ALL of these queries together to perform the cleanup:

-- Step 3.1: Delete reactions
-- DELETE FROM match_message_reactions
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM event_message_reactions
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM circle_message_reactions
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.2: Delete messages
-- DELETE FROM match_messages
-- WHERE sender_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM event_messages
-- WHERE sender_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM circle_messages
-- WHERE sender_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.3: Delete event/match participants
-- DELETE FROM event_participants
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM match_participants
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.4: Delete inactivity warnings and muted chats
-- DELETE FROM inactivity_warnings
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM muted_chats
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.5: Delete message reads (if these tables exist)
-- DELETE FROM message_reads_match
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM message_reads_event
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- DELETE FROM message_reads_circle
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.6: Delete preferences
-- DELETE FROM preferences
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.7: Delete circle memberships
-- DELETE FROM circle_members
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.8: Delete hidden activities
-- DELETE FROM hidden_activities
-- WHERE profile_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.9: Delete blocked users
-- DELETE FROM blocked_users
-- WHERE blocker_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- ) OR blocked_id IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.10: Delete circles owned by orphaned profiles
-- DELETE FROM circles
-- WHERE created_by IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.11: Delete activities created by orphaned profiles
-- DELETE FROM activities
-- WHERE created_by IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.12: Delete matches created by orphaned profiles
-- DELETE FROM matches
-- WHERE created_by IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- Step 3.13: Delete events created by orphaned profiles
-- DELETE FROM events
-- WHERE created_by IN (
--     SELECT p.id FROM profiles p
--     LEFT JOIN auth.users u ON p.id = u.id
--     WHERE u.id IS NULL
-- );

-- ============================================================================
-- STEP 4: CLEANUP - Remove orphaned profiles
-- ============================================================================

-- Step 4: Finally, delete the orphaned profiles themselves
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

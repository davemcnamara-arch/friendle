-- ============================================================================
-- FRIENDLE DATABASE RESET SCRIPT FOR BETA TESTING
-- ============================================================================
-- Project: friendle_dev (kxsewkjbhxtfqbytftbu)
-- Purpose: Wipe all user data while preserving table structures, RLS policies,
--          functions, and edge function configurations
--
-- ⚠️  WARNING: This will DELETE ALL USER DATA permanently!
-- ⚠️  Only run this script when you are ready to start fresh with beta testers.
--
-- What this script does:
--   ✓ Deletes all rows from all user data tables
--   ✓ Preserves table structures and schemas
--   ✓ Preserves RLS (Row Level Security) policies
--   ✓ Preserves database functions and triggers
--   ✓ Resets sequences/auto-increments where applicable
--   ✓ Clears storage bucket (profile avatars)
--
-- What this script does NOT affect:
--   ✓ Auth users (Supabase authentication) - handled separately
--   ✓ Edge Functions
--   ✓ Database schema/structure
--   ✓ Storage bucket configuration
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: DELETE REACTIONS (Child tables, no dependencies)
-- ============================================================================

DELETE FROM match_message_reactions;
-- Expected: Removes all emoji reactions on match messages

DELETE FROM event_message_reactions;
-- Expected: Removes all emoji reactions on event messages

DELETE FROM circle_message_reactions;
-- Expected: Removes all emoji reactions on circle messages


-- ============================================================================
-- STEP 2: DELETE MESSAGES
-- ============================================================================

DELETE FROM match_messages;
-- Expected: Removes all chat messages in matches

DELETE FROM event_messages;
-- Expected: Removes all chat messages in events

DELETE FROM circle_messages;
-- Expected: Removes all chat messages in circles


-- ============================================================================
-- STEP 3: DELETE EVENT PARTICIPANTS
-- ============================================================================

DELETE FROM event_participants;
-- Expected: Removes all users joined to events


-- ============================================================================
-- STEP 4: DELETE EVENTS
-- ============================================================================

DELETE FROM events;
-- Expected: Removes all scheduled events


-- ============================================================================
-- STEP 5: DELETE MATCH PARTICIPANTS
-- ============================================================================

DELETE FROM match_participants;
-- Expected: Removes all users joined to matches


-- ============================================================================
-- STEP 6: DELETE MATCHES
-- ============================================================================

DELETE FROM matches;
-- Expected: Removes all activity matches


-- ============================================================================
-- STEP 7: DELETE INACTIVITY WARNINGS
-- ============================================================================

DELETE FROM inactivity_warnings;
-- Expected: Removes all Day 5/7 inactivity tracking records


-- ============================================================================
-- STEP 8: DELETE MUTED CHATS
-- ============================================================================

DELETE FROM muted_chats;
-- Expected: Removes all user chat mute preferences


-- ============================================================================
-- STEP 9: DELETE ACTIVITIES (User-created activities)
-- ============================================================================

DELETE FROM activities WHERE circle_id IS NOT NULL;
-- Expected: Removes all circle-specific activities
-- Note: Keeps global activities (circle_id IS NULL) - these are system defaults


-- ============================================================================
-- STEP 10: DELETE PREFERENCES
-- ============================================================================

DELETE FROM preferences;
-- Expected: Removes all user preferences per circle


-- ============================================================================
-- STEP 11: DELETE CIRCLE MEMBERS
-- ============================================================================

DELETE FROM circle_members;
-- Expected: Removes all circle memberships


-- ============================================================================
-- STEP 12: DELETE HIDDEN ACTIVITIES
-- ============================================================================

DELETE FROM hidden_activities;
-- Expected: Removes all user-hidden activity preferences
-- Note: This table references circles, so must be deleted before circles


-- ============================================================================
-- STEP 13: DELETE CIRCLES
-- ============================================================================

DELETE FROM circles;
-- Expected: Removes all circles/groups


-- ============================================================================
-- STEP 14: DELETE PROFILES
-- ============================================================================

DELETE FROM profiles;
-- Expected: Removes all user profiles
-- Note: This does NOT delete auth.users - you must delete those separately
--       via Supabase Dashboard > Authentication > Users


-- ============================================================================
-- STEP 15: CLEAR STORAGE (Profile Avatars)
-- ============================================================================

DELETE FROM storage.objects WHERE bucket_id = 'avatars';
-- Expected: Removes all uploaded profile pictures from storage


-- ============================================================================
-- STEP 16: RESET SEQUENCES (if any exist)
-- ============================================================================

-- Note: Friendle uses UUIDs for primary keys, so there are no sequences to reset.
-- If you had any SERIAL/BIGSERIAL columns, you would reset them here with:
-- ALTER SEQUENCE sequence_name RESTART WITH 1;


COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these after the script completes to verify all tables are empty:

-- Check all message tables
SELECT 'match_messages' as table_name, COUNT(*) as row_count FROM match_messages
UNION ALL
SELECT 'event_messages', COUNT(*) FROM event_messages
UNION ALL
SELECT 'circle_messages', COUNT(*) FROM circle_messages

UNION ALL
-- Check all reaction tables
SELECT 'match_message_reactions', COUNT(*) FROM match_message_reactions
UNION ALL
SELECT 'event_message_reactions', COUNT(*) FROM event_message_reactions
UNION ALL
SELECT 'circle_message_reactions', COUNT(*) FROM circle_message_reactions

UNION ALL
-- Check core tables
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'circles', COUNT(*) FROM circles
UNION ALL
SELECT 'circle_members', COUNT(*) FROM circle_members
UNION ALL
SELECT 'hidden_activities', COUNT(*) FROM hidden_activities

UNION ALL
-- Check activity tables
SELECT 'activities (user-created)', COUNT(*) FROM activities WHERE circle_id IS NOT NULL
UNION ALL
SELECT 'matches', COUNT(*) FROM matches
UNION ALL
SELECT 'match_participants', COUNT(*) FROM match_participants

UNION ALL
-- Check event tables
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'event_participants', COUNT(*) FROM event_participants

UNION ALL
-- Check management tables
SELECT 'inactivity_warnings', COUNT(*) FROM inactivity_warnings
UNION ALL
SELECT 'muted_chats', COUNT(*) FROM muted_chats
UNION ALL
SELECT 'preferences', COUNT(*) FROM preferences

UNION ALL
-- Check storage
SELECT 'storage.objects (avatars)', COUNT(*) FROM storage.objects WHERE bucket_id = 'avatars'

ORDER BY table_name;

-- Expected Result: All tables should show 0 rows


-- ============================================================================
-- QUICK VERIFICATION (Single Query)
-- ============================================================================

SELECT
  (SELECT COUNT(*) FROM profiles) as profiles_count,
  (SELECT COUNT(*) FROM circles) as circles_count,
  (SELECT COUNT(*) FROM hidden_activities) as hidden_activities_count,
  (SELECT COUNT(*) FROM matches) as matches_count,
  (SELECT COUNT(*) FROM events) as events_count,
  (SELECT COUNT(*) FROM match_messages) as match_messages_count,
  (SELECT COUNT(*) FROM event_messages) as event_messages_count,
  (SELECT COUNT(*) FROM circle_messages) as circle_messages_count,
  (SELECT COUNT(*) FROM storage.objects WHERE bucket_id = 'avatars') as avatar_images_count;

-- Expected Result: All counts should be 0


-- ============================================================================
-- POST-RESET CHECKLIST
-- ============================================================================
--
-- After running this script, you should also:
--
-- 1. ✅ Delete all users from Supabase Authentication:
--    - Go to Supabase Dashboard > Authentication > Users
--    - Select all users and delete them
--    OR use the Supabase API/CLI:
--
--    DELETE FROM auth.users;
--
--    ⚠️ WARNING: This requires service_role key and should be done carefully!
--
-- 2. ✅ Verify Edge Functions are still configured:
--    - event-reminders (hourly cron)
--    - inactivity-cleanup (daily cron)
--    - stay-interested
--    - send-notification
--
-- 3. ✅ Verify RLS Policies are intact:
--    Run: SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
--
-- 4. ✅ Test the app with a fresh sign-up to ensure everything works:
--    - User registration
--    - Circle creation
--    - Profile picture upload
--    - Match creation
--    - Event scheduling
--    - Messaging
--
-- 5. ✅ Verify global activities are preserved:
--    SELECT * FROM activities WHERE circle_id IS NULL;
--    (These are your default activity templates)
--
-- ============================================================================

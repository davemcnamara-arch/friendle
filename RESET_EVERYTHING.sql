-- ============================================================================
-- FRIENDLE COMPLETE RESET - ONE SCRIPT TO WIPE EVERYTHING
-- ============================================================================
-- ⚠️  ULTIMATE WARNING: This deletes EVERYTHING - all data and all auth users!
-- ⚠️  This is a point of no return. Make sure you have backups!
-- ⚠️  Only use this when you're 100% ready to start completely fresh.
--
-- This script combines:
--   - RESET_DATABASE_FOR_BETA.sql (wipes all user data)
--   - RESET_AUTH_USERS.sql (wipes all authentication)
--
-- Run this in Supabase SQL Editor at:
-- https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/sql/new
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: DELETE ALL USER DATA
-- ============================================================================

-- Reactions (child tables)
DELETE FROM match_message_reactions;
DELETE FROM event_message_reactions;
DELETE FROM circle_message_reactions;

-- Messages
DELETE FROM match_messages;
DELETE FROM event_messages;
DELETE FROM circle_messages;

-- Event participation
DELETE FROM event_participants;

-- Events
DELETE FROM events;

-- Match participation
DELETE FROM match_participants;

-- Matches
DELETE FROM matches;

-- System tracking
DELETE FROM inactivity_warnings;
DELETE FROM muted_chats;

-- User-created activities (preserve global ones)
DELETE FROM activities WHERE circle_id IS NOT NULL;

-- Preferences
DELETE FROM preferences;

-- Circle membership
DELETE FROM circle_members;

-- Hidden activities (must delete before circles due to FK)
DELETE FROM hidden_activities;

-- Circles
DELETE FROM circles;

-- Profiles
DELETE FROM profiles;

-- Storage (avatars)
DELETE FROM storage.objects WHERE bucket_id = 'avatars';


-- ============================================================================
-- PART 2: DELETE ALL AUTHENTICATION USERS
-- ============================================================================

DELETE FROM auth.users;
-- This cascades to auth.identities, auth.sessions, auth.refresh_tokens


COMMIT;


-- ============================================================================
-- VERIFICATION QUERIES - Run these after COMMIT
-- ============================================================================

-- Quick overview (all should be 0)
SELECT
  (SELECT COUNT(*) FROM profiles) as profiles,
  (SELECT COUNT(*) FROM circles) as circles,
  (SELECT COUNT(*) FROM hidden_activities) as hidden_activities,
  (SELECT COUNT(*) FROM matches) as matches,
  (SELECT COUNT(*) FROM events) as events,
  (SELECT COUNT(*) FROM match_messages) as match_msgs,
  (SELECT COUNT(*) FROM auth.users) as auth_users;

-- Detailed check (all should be 0)
SELECT 'profiles' as table_name, COUNT(*) as rows FROM profiles
UNION ALL SELECT 'circles', COUNT(*) FROM circles
UNION ALL SELECT 'circle_members', COUNT(*) FROM circle_members
UNION ALL SELECT 'hidden_activities', COUNT(*) FROM hidden_activities
UNION ALL SELECT 'matches', COUNT(*) FROM matches
UNION ALL SELECT 'match_participants', COUNT(*) FROM match_participants
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'event_participants', COUNT(*) FROM event_participants
UNION ALL SELECT 'match_messages', COUNT(*) FROM match_messages
UNION ALL SELECT 'event_messages', COUNT(*) FROM event_messages
UNION ALL SELECT 'circle_messages', COUNT(*) FROM circle_messages
UNION ALL SELECT 'match_message_reactions', COUNT(*) FROM match_message_reactions
UNION ALL SELECT 'event_message_reactions', COUNT(*) FROM event_message_reactions
UNION ALL SELECT 'circle_message_reactions', COUNT(*) FROM circle_message_reactions
UNION ALL SELECT 'inactivity_warnings', COUNT(*) FROM inactivity_warnings
UNION ALL SELECT 'muted_chats', COUNT(*) FROM muted_chats
UNION ALL SELECT 'preferences', COUNT(*) FROM preferences
UNION ALL SELECT 'user_activities', COUNT(*) FROM activities WHERE circle_id IS NOT NULL
UNION ALL SELECT 'avatars', COUNT(*) FROM storage.objects WHERE bucket_id = 'avatars'
UNION ALL SELECT 'auth.users', COUNT(*) FROM auth.users
UNION ALL SELECT 'auth.sessions', COUNT(*) FROM auth.sessions
ORDER BY table_name;

-- Verify global activities are preserved (should show your defaults)
SELECT id, name, created_by FROM activities WHERE circle_id IS NULL ORDER BY name;

-- Verify RLS policies are intact (should show 30+ policies)
SELECT COUNT(*) as total_rls_policies FROM pg_policies WHERE schemaname = 'public';


-- ============================================================================
-- SUCCESS CHECKLIST
-- ============================================================================
--
-- If all verification queries pass, you should see:
--
-- ✅ All user data tables: 0 rows
-- ✅ All auth tables: 0 rows
-- ✅ Global activities: 5-10 rows (your defaults)
-- ✅ RLS policies: 30+ policies intact
--
-- Your database is now completely clean and ready for beta testing!
--
-- Next steps:
-- 1. Test user registration
-- 2. Test circle creation
-- 3. Test match creation
-- 4. Test event scheduling
-- 5. Test messaging
-- 6. Test notifications
--
-- See DATABASE_RESET_GUIDE.md for detailed testing checklist.
--
-- ============================================================================

-- ============================================================================
-- DROP OLD BACKUPS AND CREATE FRESH ONES (Including hidden_activities)
-- ============================================================================
-- Run this to replace your incomplete backup with a complete one
-- ============================================================================

BEGIN;

-- Drop old backup tables (missing hidden_activities)
DROP TABLE IF EXISTS profiles_backup_20251026;
DROP TABLE IF EXISTS circles_backup_20251026;
DROP TABLE IF EXISTS circle_members_backup_20251026;
DROP TABLE IF EXISTS activities_backup_20251026;
DROP TABLE IF EXISTS matches_backup_20251026;
DROP TABLE IF EXISTS match_participants_backup_20251026;
DROP TABLE IF EXISTS events_backup_20251026;
DROP TABLE IF EXISTS event_participants_backup_20251026;
DROP TABLE IF EXISTS match_messages_backup_20251026;
DROP TABLE IF EXISTS event_messages_backup_20251026;
DROP TABLE IF EXISTS circle_messages_backup_20251026;
DROP TABLE IF EXISTS match_message_reactions_backup_20251026;
DROP TABLE IF EXISTS event_message_reactions_backup_20251026;
DROP TABLE IF EXISTS circle_message_reactions_backup_20251026;
DROP TABLE IF EXISTS inactivity_warnings_backup_20251026;
DROP TABLE IF EXISTS muted_chats_backup_20251026;
DROP TABLE IF EXISTS preferences_backup_20251026;
DROP TABLE IF EXISTS auth_users_backup_20251026;
DROP TABLE IF EXISTS auth_identities_backup_20251026;

-- Create fresh backup tables WITH hidden_activities
CREATE TABLE profiles_backup_20251026 AS SELECT * FROM profiles;
CREATE TABLE circles_backup_20251026 AS SELECT * FROM circles;
CREATE TABLE circle_members_backup_20251026 AS SELECT * FROM circle_members;
CREATE TABLE hidden_activities_backup_20251026 AS SELECT * FROM hidden_activities;
CREATE TABLE activities_backup_20251026 AS SELECT * FROM activities;
CREATE TABLE matches_backup_20251026 AS SELECT * FROM matches;
CREATE TABLE match_participants_backup_20251026 AS SELECT * FROM match_participants;
CREATE TABLE events_backup_20251026 AS SELECT * FROM events;
CREATE TABLE event_participants_backup_20251026 AS SELECT * FROM event_participants;
CREATE TABLE match_messages_backup_20251026 AS SELECT * FROM match_messages;
CREATE TABLE event_messages_backup_20251026 AS SELECT * FROM event_messages;
CREATE TABLE circle_messages_backup_20251026 AS SELECT * FROM circle_messages;
CREATE TABLE match_message_reactions_backup_20251026 AS SELECT * FROM match_message_reactions;
CREATE TABLE event_message_reactions_backup_20251026 AS SELECT * FROM event_message_reactions;
CREATE TABLE circle_message_reactions_backup_20251026 AS SELECT * FROM circle_message_reactions;
CREATE TABLE inactivity_warnings_backup_20251026 AS SELECT * FROM inactivity_warnings;
CREATE TABLE muted_chats_backup_20251026 AS SELECT * FROM muted_chats;
CREATE TABLE preferences_backup_20251026 AS SELECT * FROM preferences;
CREATE TABLE auth_users_backup_20251026 AS SELECT * FROM auth.users;
CREATE TABLE auth_identities_backup_20251026 AS SELECT * FROM auth.identities;

COMMIT;

-- Verify backups were created
SELECT
  'profiles' as table_name,
  (SELECT COUNT(*) FROM profiles) as original,
  (SELECT COUNT(*) FROM profiles_backup_20251026) as backup
UNION ALL
SELECT 'circles', COUNT(*), (SELECT COUNT(*) FROM circles_backup_20251026) FROM circles
UNION ALL
SELECT 'hidden_activities', COUNT(*), (SELECT COUNT(*) FROM hidden_activities_backup_20251026) FROM hidden_activities
UNION ALL
SELECT 'matches', COUNT(*), (SELECT COUNT(*) FROM matches_backup_20251026) FROM matches
UNION ALL
SELECT 'events', COUNT(*), (SELECT COUNT(*) FROM events_backup_20251026) FROM events
UNION ALL
SELECT 'auth.users', COUNT(*), (SELECT COUNT(*) FROM auth_users_backup_20251026) FROM auth.users;

-- Expected: original and backup counts should match for all tables

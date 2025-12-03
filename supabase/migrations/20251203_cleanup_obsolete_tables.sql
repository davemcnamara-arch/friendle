-- ============================================================================
-- Cleanup Obsolete Tables
-- ============================================================================
-- This migration removes:
-- 1. All backup tables from October 26, 2025 (21 tables)
-- 2. The generic 'messages' table (unused - we use event_messages, circle_messages)
-- ============================================================================

BEGIN;

-- ============================================================================
-- Part 1: Drop Backup Tables from October 26, 2025
-- ============================================================================
-- These backup tables are ~5 weeks old and no longer needed
-- Note: Some of these backed up tables that no longer exist (e.g., match_messages)
-- ============================================================================

DROP TABLE IF EXISTS public.event_participants_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.match_messages_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.event_messages_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.profiles_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.circles_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.circle_members_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.hidden_activities_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.activities_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.matches_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.match_participants_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.events_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.circle_messages_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.match_message_reactions_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.event_message_reactions_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.circle_message_reactions_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.inactivity_warnings_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.muted_chats_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.preferences_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.auth_users_backup_20251026 CASCADE;
DROP TABLE IF EXISTS public.auth_identities_backup_20251026 CASCADE;

-- ============================================================================
-- Part 2: Drop Unused Generic Messages Table
-- ============================================================================
-- The generic 'messages' table was created in the RLS fix but is not used
-- The app uses specific message tables: event_messages, circle_messages
-- ============================================================================

DROP TABLE IF EXISTS public.messages CASCADE;

COMMIT;

-- ============================================================================
-- Summary
-- ============================================================================
-- Dropped 21 backup tables (freeing up database storage)
-- Dropped 1 unused generic messages table
-- Total: 22 tables removed
-- ============================================================================
